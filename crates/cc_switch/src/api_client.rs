//! HTTP/OAuth API client for CC-Switch
//!
//! Handles communication with AI providers and OAuth flows.

use anyhow::{anyhow, Context, Result};
use base64::prelude::*;
use credentials_provider::CredentialsProvider;
use futures::AsyncReadExt;
use gpui::AsyncApp;
use http_client::{AsyncBody, HttpClient, Method, Request, StatusCode};
use i18n::t;
use rand::Rng;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tiny_http::{Response, Server};
use url::Url;

use crate::{AppType, Provider};

const OAUTH_CALLBACK_PORT: u16 = 19527;
const DEFAULT_OAUTH_TOKEN_KEY: &str = "cc_switch_oauth_token";
const OAUTH_TIMEOUT_SECONDS: u64 = 300;

/// OAuth configuration for a provider.
#[derive(Debug, Clone)]
pub struct OAuthConfig {
    pub authorize_url: String,
    pub token_url: String,
    pub client_id: String,
    pub scope: Option<String>,
    pub credentials_key: Option<String>,
    pub redirect_port: Option<u16>,
}

impl OAuthConfig {
    pub fn credentials_key(&self) -> &str {
        self.credentials_key
            .as_deref()
            .unwrap_or(DEFAULT_OAUTH_TOKEN_KEY)
    }

    fn redirect_port(&self) -> u16 {
        self.redirect_port.unwrap_or(OAUTH_CALLBACK_PORT)
    }

    fn redirect_uri(&self) -> String {
        format!("http://127.0.0.1:{}/callback", self.redirect_port())
    }
}

trait OAuthCodeProvider: Send + Sync {
    fn request_code(&self, authorize_url: Url, expected_state: &str, redirect_port: u16) -> Result<String>;
}

struct BrowserOAuthCodeProvider;

impl OAuthCodeProvider for BrowserOAuthCodeProvider {
    fn request_code(&self, authorize_url: Url, expected_state: &str, redirect_port: u16) -> Result<String> {
        let server = Server::http(format!("127.0.0.1:{}", redirect_port))
            .map_err(|e| anyhow!("Failed to start callback server: {}", e))?;

        open::that(authorize_url.as_str()).context("Failed to open browser")?;

        for _ in 0..OAUTH_TIMEOUT_SECONDS {
            if let Some(request) = server.recv_timeout(Duration::from_secs(1))? {
                let path = request.url();
                if !path.starts_with("/callback") {
                    let _ = request.respond(Response::from_string(t("cc-oauth-not-found")).with_status_code(404));
                    continue;
                }

                let callback_url = Url::parse(&format!("http://localhost{}", path))
                    .context("Failed to parse callback URL")?;
                let params: HashMap<_, _> = callback_url.query_pairs().collect();

                if let Some(error) = params.get("error") {
                    let _ = request.respond(Response::from_string(t("cc-oauth-auth-failed")));
                    return Err(anyhow!("OAuth error: {}", error));
                }

                let Some(code) = params.get("code") else {
                    let _ = request.respond(Response::from_string(t("cc-oauth-missing-code")));
                    return Err(anyhow!("OAuth callback missing code"));
                };
                let Some(state) = params.get("state") else {
                    let _ = request.respond(Response::from_string(t("cc-oauth-missing-state")));
                    return Err(anyhow!("OAuth callback missing state"));
                };

                if state != expected_state {
                    let _ = request.respond(Response::from_string(t("cc-oauth-state-mismatch")));
                    return Err(anyhow!("OAuth state mismatch"));
                }

                let _ = request.respond(Response::from_string(t("cc-oauth-complete")));
                return Ok(code.to_string());
            }
        }

        Err(anyhow!("OAuth callback timed out"))
    }
}

/// API client for provider interactions.
pub struct ApiClient {
    http_client: Arc<dyn HttpClient>,
    credentials: Arc<dyn CredentialsProvider>,
    code_provider: Arc<dyn OAuthCodeProvider>,
}

impl ApiClient {
    pub fn new(
        http_client: Arc<dyn HttpClient>,
        credentials: Arc<dyn CredentialsProvider>,
    ) -> Self {
        Self::with_code_provider(http_client, credentials, Arc::new(BrowserOAuthCodeProvider))
    }

    pub fn with_code_provider(
        http_client: Arc<dyn HttpClient>,
        credentials: Arc<dyn CredentialsProvider>,
        code_provider: Arc<dyn OAuthCodeProvider>,
    ) -> Self {
        Self {
            http_client,
            credentials,
            code_provider,
        }
    }

    /// Generate a random string for PKCE verifier and state.
    fn generate_random_string(length: usize) -> String {
        let mut rng = rand::thread_rng();
        (0..length)
            .map(|_| {
                let idx = rng.gen_range(0..62);
                let chars = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
                chars[idx] as char
            })
            .collect()
    }

    /// Generate PKCE code challenge from verifier.
    fn generate_code_challenge(verifier: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(verifier.as_bytes());
        let result = hasher.finalize();
        BASE64_URL_SAFE_NO_PAD.encode(result)
    }

    /// Build the authorization URL for OAuth.
    fn build_authorize_url(
        config: &OAuthConfig,
        code_challenge: &str,
        state: &str,
    ) -> Result<Url> {
        let redirect_uri = config.redirect_uri();
        let mut url = Url::parse(&config.authorize_url).context("Invalid authorize URL")?;
        {
            let mut pairs = url.query_pairs_mut();
            pairs
                .append_pair("response_type", "code")
                .append_pair("client_id", &config.client_id)
                .append_pair("redirect_uri", &redirect_uri)
                .append_pair("code_challenge", code_challenge)
                .append_pair("code_challenge_method", "S256")
                .append_pair("state", state);
            if let Some(scope) = &config.scope {
                pairs.append_pair("scope", scope);
            }
        }
        Ok(url)
    }

    /// Validate API key for a provider.
    pub async fn validate_api_key(&self, _app_type: AppType, _api_key: &str) -> Result<bool> {
        Ok(true)
    }

    /// List available models for a provider.
    pub async fn list_models(&self, _provider: &Provider) -> Result<Vec<String>> {
        Ok(Vec::new())
    }

    /// Start OAuth flow for a provider and store the resulting token.
    pub async fn login(&self, config: &OAuthConfig, cx: &AsyncApp) -> Result<String> {
        let verifier = Self::generate_random_string(64);
        let code_challenge = Self::generate_code_challenge(&verifier);
        let state = Self::generate_random_string(32);

        let authorize_url = Self::build_authorize_url(config, &code_challenge, &state)?;
        let code = self
            .code_provider
            .request_code(authorize_url, &state, config.redirect_port())?;
        let token = self.exchange_oauth_code(config, &code, &verifier).await?;

        self.store_token_for_key(config.credentials_key(), &token, cx)
            .await?;
        Ok(token)
    }

    /// Exchange an authorization code for a token.
    pub async fn complete_oauth_flow(
        &self,
        config: &OAuthConfig,
        code: &str,
        verifier: &str,
    ) -> Result<String> {
        self.exchange_oauth_code(config, code, verifier).await
    }

    /// Store credentials securely.
    pub async fn store_token(&self, token: &str, cx: &AsyncApp) -> Result<()> {
        self.store_token_for_key(DEFAULT_OAUTH_TOKEN_KEY, token, cx)
            .await
    }

    pub async fn store_token_for_key(
        &self,
        key: &str,
        token: &str,
        cx: &AsyncApp,
    ) -> Result<()> {
        self.credentials
            .write_credentials(key, "Bearer", token.as_bytes(), cx)
            .await
    }

    /// Retrieve credentials securely.
    pub async fn get_stored_token(&self, cx: &AsyncApp) -> Result<Option<String>> {
        self.get_stored_token_for_key(DEFAULT_OAUTH_TOKEN_KEY, cx)
            .await
    }

    pub async fn get_stored_token_for_key(&self, key: &str, cx: &AsyncApp) -> Result<Option<String>> {
        let stored = self.credentials.read_credentials(key, cx).await?;
        let Some((_, token)) = stored else {
            return Ok(None);
        };
        let token = std::str::from_utf8(&token)
            .context("Stored token is not valid UTF-8")?
            .to_string();
        Ok(Some(token))
    }

    /// Remove stored credentials.
    pub async fn delete_token(&self, cx: &AsyncApp) -> Result<()> {
        self.delete_token_for_key(DEFAULT_OAUTH_TOKEN_KEY, cx)
            .await
    }

    pub async fn delete_token_for_key(&self, key: &str, cx: &AsyncApp) -> Result<()> {
        self.credentials.delete_credentials(key, cx).await
    }

    async fn exchange_oauth_code(
        &self,
        config: &OAuthConfig,
        code: &str,
        verifier: &str,
    ) -> Result<String> {
        let payload = serde_json::json!({
            "grant_type": "authorization_code",
            "client_id": config.client_id,
            "code": code,
            "redirect_uri": config.redirect_uri(),
            "code_verifier": verifier,
        });

        let request = Request::builder()
            .method(Method::POST)
            .uri(&config.token_url)
            .header("Content-Type", "application/json")
            .body(AsyncBody::from(payload.to_string()))?;

        let mut response = self.http_client.send(request).await?;
        let status = response.status();
        let mut body = String::new();
        response.body_mut().read_to_string(&mut body).await?;

        if !status.is_success() {
            let error_message = parse_oauth_error(&body)
                .unwrap_or_else(|| format!("status {}", status));
            return Err(anyhow!("OAuth token exchange failed: {}", error_message));
        }

        parse_token_response(&body)
    }
}

fn parse_token_response(body: &str) -> Result<String> {
    let value: serde_json::Value =
        serde_json::from_str(body).context("Failed to parse OAuth token response")?;

    if let Some(token) = value.get("access_token").and_then(|v| v.as_str()) {
        return Ok(token.to_string());
    }
    if let Some(token) = value
        .get("data")
        .and_then(|v| v.get("access_token"))
        .and_then(|v| v.as_str())
    {
        return Ok(token.to_string());
    }
    if let Some(token) = value.get("token").and_then(|v| v.as_str()) {
        return Ok(token.to_string());
    }

    Err(anyhow!("OAuth token response missing access_token"))
}

fn parse_oauth_error(body: &str) -> Option<String> {
    let value: serde_json::Value = serde_json::from_str(body).ok()?;
    value
        .get("error_description")
        .and_then(|v| v.as_str())
        .map(str::to_string)
        .or_else(|| value.get("error").and_then(|v| v.as_str()).map(str::to_string))
        .or_else(|| value.get("message").and_then(|v| v.as_str()).map(str::to_string))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::future::Future;
    use std::pin::Pin;
    use std::sync::Mutex;

    use gpui::TestAppContext;

    #[derive(Default)]
    struct TestCredentialsProvider {
        store: Mutex<HashMap<String, (String, Vec<u8>)>>,
    }

    impl CredentialsProvider for TestCredentialsProvider {
        fn read_credentials<'a>(
            &'a self,
            url: &'a str,
            _cx: &'a AsyncApp,
        ) -> Pin<Box<dyn Future<Output = Result<Option<(String, Vec<u8>)>>> + 'a>> {
            Box::pin(async move { Ok(self.store.lock().unwrap().get(url).cloned()) })
        }

        fn write_credentials<'a>(
            &'a self,
            url: &'a str,
            username: &'a str,
            password: &'a [u8],
            _cx: &'a AsyncApp,
        ) -> Pin<Box<dyn Future<Output = Result<()>> + 'a>> {
            Box::pin(async move {
                self.store.lock().unwrap().insert(
                    url.to_string(),
                    (username.to_string(), password.to_vec()),
                );
                Ok(())
            })
        }

        fn delete_credentials<'a>(
            &'a self,
            url: &'a str,
            _cx: &'a AsyncApp,
        ) -> Pin<Box<dyn Future<Output = Result<()>> + 'a>> {
            Box::pin(async move {
                self.store.lock().unwrap().remove(url);
                Ok(())
            })
        }
    }

    struct TestHttpClient {
        status: StatusCode,
        response_body: String,
        last_uri: Mutex<Option<String>>,
    }

    impl TestHttpClient {
        fn new(status: StatusCode, response_body: impl Into<String>) -> Self {
            Self {
                status,
                response_body: response_body.into(),
                last_uri: Mutex::new(None),
            }
        }

        fn last_uri(&self) -> Option<String> {
            self.last_uri.lock().unwrap().clone()
        }
    }

    impl HttpClient for TestHttpClient {
        fn user_agent(&self) -> Option<&http_client::http::HeaderValue> {
            None
        }

        fn proxy(&self) -> Option<&Url> {
            None
        }

        fn send(
            &self,
            req: Request<AsyncBody>,
        ) -> futures::future::BoxFuture<'static, Result<http_client::Response<AsyncBody>>> {
            let uri = req.uri().to_string();
            *self.last_uri.lock().unwrap() = Some(uri);
            let status = self.status;
            let body = self.response_body.clone();
            Box::pin(async move {
                Ok(http_client::Response::builder()
                    .status(status)
                    .body(AsyncBody::from(body))
                    .unwrap())
            })
        }
    }

    struct TestOAuthCodeProvider {
        code: String,
    }

    impl OAuthCodeProvider for TestOAuthCodeProvider {
        fn request_code(
            &self,
            authorize_url: Url,
            expected_state: &str,
            _redirect_port: u16,
        ) -> Result<String> {
            assert!(authorize_url.as_str().contains(expected_state));
            Ok(self.code.clone())
        }
    }

    #[test]
    fn test_parse_token_response() {
        let token = parse_token_response(r#"{"access_token":"token-1"}"#).unwrap();
        assert_eq!(token, "token-1");

        let token = parse_token_response(r#"{"data":{"access_token":"token-2"}}"#).unwrap();
        assert_eq!(token, "token-2");

        let error = parse_token_response(r#"{"missing":"token"}"#).unwrap_err();
        assert!(error.to_string().contains("missing access_token"));
    }

    #[gpui::test]
    async fn test_login_stores_token(cx: &mut TestAppContext) {
        let http_client = Arc::new(TestHttpClient::new(
            StatusCode::OK,
            r#"{"access_token":"stored-token"}"#,
        ));
        let credentials = Arc::new(TestCredentialsProvider::default());
        let code_provider = Arc::new(TestOAuthCodeProvider {
            code: "auth-code".to_string(),
        });
        let client = ApiClient::with_code_provider(
            http_client.clone(),
            credentials.clone(),
            code_provider,
        );

        let config = OAuthConfig {
            authorize_url: "https://example.com/authorize".to_string(),
            token_url: "https://example.com/token".to_string(),
            client_id: "client-id".to_string(),
            scope: Some("scope".to_string()),
            credentials_key: None,
            redirect_port: Some(9999),
        };

        let async_cx = cx.to_async();
        let token = client.login(&config, &async_cx).await.unwrap();
        assert_eq!(token, "stored-token");

        let stored = client.get_stored_token(&async_cx).await.unwrap();
        assert_eq!(stored, Some("stored-token".to_string()));
        assert_eq!(
            http_client.last_uri(),
            Some("https://example.com/token".to_string())
        );
    }

    #[gpui::test]
    async fn test_complete_oauth_flow(cx: &mut TestAppContext) {
        let http_client = Arc::new(TestHttpClient::new(
            StatusCode::OK,
            r#"{"access_token":"token-xyz"}"#,
        ));
        let credentials = Arc::new(TestCredentialsProvider::default());
        let client = ApiClient::with_code_provider(
            http_client,
            credentials,
            Arc::new(TestOAuthCodeProvider {
                code: "unused".to_string(),
            }),
        );

        let config = OAuthConfig {
            authorize_url: "https://example.com/authorize".to_string(),
            token_url: "https://example.com/token".to_string(),
            client_id: "client-id".to_string(),
            scope: None,
            credentials_key: None,
            redirect_port: None,
        };

        let token = client
            .complete_oauth_flow(&config, "code-123", "verifier-123")
            .await
            .unwrap();
        assert_eq!(token, "token-xyz");

        let async_cx = cx.to_async();
        let stored = client.get_stored_token(&async_cx).await.unwrap();
        assert!(stored.is_none());
    }
}
