//! Data models for CC-Switch
//!
//! Contains types ported from CC-Switch for:
//! - Providers (API configurations)
//! - MCP Servers (Model Context Protocol)
//! - Skills (Claude Code slash commands)

use indexmap::IndexMap;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::str::FromStr;

// ============================================================================
// Type Aliases
// ============================================================================

/// Unique identifier for a provider
pub type ProviderId = String;

/// Unique identifier for an MCP server
pub type McpServerId = String;

/// Unique identifier for a skill
pub type SkillId = String;

// ============================================================================
// App Types
// ============================================================================

/// Application type (which client to configure)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AppType {
    Claude,
    Codex,
    Gemini,
    OpenCode,
}

impl AppType {
    pub fn as_str(&self) -> &str {
        match self {
            AppType::Claude => "claude",
            AppType::Codex => "codex",
            AppType::Gemini => "gemini",
            AppType::OpenCode => "opencode",
        }
    }

    pub fn display_name(&self) -> &str {
        match self {
            AppType::Claude => "Claude",
            AppType::Codex => "Codex",
            AppType::Gemini => "Gemini",
            AppType::OpenCode => "OpenCode",
        }
    }

    /// Returns all app types
    pub fn all() -> &'static [AppType] {
        &[
            AppType::Claude,
            AppType::Codex,
            AppType::Gemini,
            AppType::OpenCode,
        ]
    }
}

impl FromStr for AppType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let normalized = s.trim().to_lowercase();
        match normalized.as_str() {
            "claude" => Ok(AppType::Claude),
            "codex" => Ok(AppType::Codex),
            "gemini" => Ok(AppType::Gemini),
            "opencode" => Ok(AppType::OpenCode),
            other => Err(format!(
                "Unsupported app id: '{}'. Allowed: claude, codex, gemini, opencode.",
                other
            )),
        }
    }
}

impl std::fmt::Display for AppType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

// ============================================================================
// MCP Server Types
// ============================================================================

/// MCP Server application state (marks which clients the server is applied to)
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct McpApps {
    #[serde(default)]
    pub claude: bool,
    #[serde(default)]
    pub codex: bool,
    #[serde(default)]
    pub gemini: bool,
    #[serde(default)]
    pub opencode: bool,
}

impl McpApps {
    /// Check if a specific app is enabled
    pub fn is_enabled_for(&self, app: &AppType) -> bool {
        match app {
            AppType::Claude => self.claude,
            AppType::Codex => self.codex,
            AppType::Gemini => self.gemini,
            AppType::OpenCode => self.opencode,
        }
    }

    /// Set the enabled state for a specific app
    pub fn set_enabled_for(&mut self, app: &AppType, enabled: bool) {
        match app {
            AppType::Claude => self.claude = enabled,
            AppType::Codex => self.codex = enabled,
            AppType::Gemini => self.gemini = enabled,
            AppType::OpenCode => self.opencode = enabled,
        }
    }

    /// Get all enabled apps
    pub fn enabled_apps(&self) -> Vec<AppType> {
        let mut apps = Vec::new();
        if self.claude {
            apps.push(AppType::Claude);
        }
        if self.codex {
            apps.push(AppType::Codex);
        }
        if self.gemini {
            apps.push(AppType::Gemini);
        }
        if self.opencode {
            apps.push(AppType::OpenCode);
        }
        apps
    }

    /// Check if no apps are enabled
    pub fn is_empty(&self) -> bool {
        !self.claude && !self.codex && !self.gemini && !self.opencode
    }

    /// Enable all apps
    pub fn all_enabled() -> Self {
        Self {
            claude: true,
            codex: true,
            gemini: true,
            opencode: true,
        }
    }
}

/// MCP Server definition
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct McpServer {
    pub id: McpServerId,
    pub name: String,
    /// Server configuration (command, args, env, etc.)
    pub server: Value,
    /// Which apps this server is enabled for
    pub apps: McpApps,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub homepage: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub docs: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
    /// Sort index for drag-drop ordering
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort_index: Option<usize>,
}

impl McpServer {
    /// Create a new MCP server with minimal configuration
    pub fn new(id: impl Into<String>, name: impl Into<String>, server: Value) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            server,
            apps: McpApps::default(),
            description: None,
            homepage: None,
            docs: None,
            tags: Vec::new(),
            sort_index: None,
        }
    }
}

// ============================================================================
// Skill Types
// ============================================================================

/// Skill application state (marks which clients the skill is applied to)
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct SkillApps {
    #[serde(default)]
    pub claude: bool,
    #[serde(default)]
    pub codex: bool,
    #[serde(default)]
    pub gemini: bool,
    #[serde(default)]
    pub opencode: bool,
}

impl SkillApps {
    /// Check if a specific app is enabled
    pub fn is_enabled_for(&self, app: &AppType) -> bool {
        match app {
            AppType::Claude => self.claude,
            AppType::Codex => self.codex,
            AppType::Gemini => self.gemini,
            AppType::OpenCode => self.opencode,
        }
    }

    /// Set the enabled state for a specific app
    pub fn set_enabled_for(&mut self, app: &AppType, enabled: bool) {
        match app {
            AppType::Claude => self.claude = enabled,
            AppType::Codex => self.codex = enabled,
            AppType::Gemini => self.gemini = enabled,
            AppType::OpenCode => self.opencode = enabled,
        }
    }

    /// Get all enabled apps
    pub fn enabled_apps(&self) -> Vec<AppType> {
        let mut apps = Vec::new();
        if self.claude {
            apps.push(AppType::Claude);
        }
        if self.codex {
            apps.push(AppType::Codex);
        }
        if self.gemini {
            apps.push(AppType::Gemini);
        }
        if self.opencode {
            apps.push(AppType::OpenCode);
        }
        apps
    }

    /// Check if no apps are enabled
    pub fn is_empty(&self) -> bool {
        !self.claude && !self.codex && !self.gemini && !self.opencode
    }

    /// Create with only the specified app enabled
    pub fn only(app: &AppType) -> Self {
        let mut apps = Self::default();
        apps.set_enabled_for(app, true);
        apps
    }

    /// Enable all apps
    pub fn all_enabled() -> Self {
        Self {
            claude: true,
            codex: true,
            gemini: true,
            opencode: true,
        }
    }
}

/// Installed Skill definition
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstalledSkill {
    /// Unique identifier (format: "owner/repo:directory" or "local:directory")
    pub id: SkillId,
    /// Display name
    pub name: String,
    /// Description
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Installation directory name (subdirectory in SSOT directory)
    pub directory: String,
    /// Repository owner (GitHub user/organization)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub repo_owner: Option<String>,
    /// Repository name
    #[serde(skip_serializing_if = "Option::is_none")]
    pub repo_name: Option<String>,
    /// Repository branch
    #[serde(skip_serializing_if = "Option::is_none")]
    pub repo_branch: Option<String>,
    /// README URL
    #[serde(skip_serializing_if = "Option::is_none")]
    pub readme_url: Option<String>,
    /// Application enable state
    pub apps: SkillApps,
    /// Installation time (Unix timestamp)
    pub installed_at: i64,
    /// Sort index for drag-drop ordering
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort_index: Option<usize>,
}

impl InstalledSkill {
    /// Create a new local skill
    pub fn new_local(
        id: impl Into<String>,
        name: impl Into<String>,
        directory: impl Into<String>,
    ) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            description: None,
            directory: directory.into(),
            repo_owner: None,
            repo_name: None,
            repo_branch: None,
            readme_url: None,
            apps: SkillApps::default(),
            installed_at: chrono::Utc::now().timestamp(),
            sort_index: None,
        }
    }

    /// Create a new skill from a GitHub repository
    pub fn new_from_repo(
        owner: impl Into<String>,
        repo: impl Into<String>,
        branch: impl Into<String>,
        name: impl Into<String>,
        directory: impl Into<String>,
    ) -> Self {
        let owner = owner.into();
        let repo = repo.into();
        let branch = branch.into();
        let directory = directory.into();
        let id = format!("{}/{}:{}", owner, repo, directory);

        Self {
            id,
            name: name.into(),
            description: None,
            directory,
            repo_owner: Some(owner.clone()),
            repo_name: Some(repo.clone()),
            repo_branch: Some(branch),
            readme_url: Some(format!(
                "https://github.com/{}/{}/blob/main/README.md",
                owner, repo
            )),
            apps: SkillApps::default(),
            installed_at: chrono::Utc::now().timestamp(),
            sort_index: None,
        }
    }

    /// Check if this skill is from a GitHub repository
    pub fn is_from_repo(&self) -> bool {
        self.repo_owner.is_some() && self.repo_name.is_some()
    }
}

// ============================================================================
// Provider Types
// ============================================================================

/// Provider configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Provider {
    pub id: ProviderId,
    pub name: String,
    /// Settings configuration (env vars, config files, etc.)
    pub settings_config: Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub website_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub category: Option<String>,
    /// Notes/comments
    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
    /// Icon name (e.g., "openai", "anthropic")
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    /// Icon color (Hex format, e.g., "#00A67E")
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon_color: Option<String>,
    /// Sort index for drag-drop ordering
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort_index: Option<usize>,
    /// Whether to join failover queue
    #[serde(default)]
    pub in_failover_queue: bool,
}

impl Provider {
    /// Create a new provider with minimal configuration
    pub fn new(id: impl Into<String>, name: impl Into<String>, settings_config: Value) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            settings_config,
            website_url: None,
            category: None,
            notes: None,
            icon: None,
            icon_color: None,
            sort_index: None,
            in_failover_queue: false,
        }
    }

    /// Create a provider with ID and website URL
    pub fn with_website(
        id: impl Into<String>,
        name: impl Into<String>,
        settings_config: Value,
        website_url: impl Into<String>,
    ) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            settings_config,
            website_url: Some(website_url.into()),
            category: None,
            notes: None,
            icon: None,
            icon_color: None,
            sort_index: None,
            in_failover_queue: false,
        }
    }
}

// ============================================================================
// Main Configuration
// ============================================================================

/// Main CC-Switch configuration
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct CcSwitchConfig {
    /// All providers keyed by ID (preserves insertion order)
    #[serde(default)]
    pub providers: IndexMap<ProviderId, Provider>,
    /// Currently active provider ID
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current_provider: Option<ProviderId>,
    /// All MCP servers keyed by ID (preserves insertion order)
    #[serde(default)]
    pub mcp_servers: IndexMap<McpServerId, McpServer>,
    /// All installed skills keyed by ID (preserves insertion order)
    #[serde(default)]
    pub skills: IndexMap<SkillId, InstalledSkill>,
}

impl CcSwitchConfig {
    /// Create a new empty configuration
    pub fn new() -> Self {
        Self::default()
    }

    /// Get the current provider if set
    pub fn current_provider(&self) -> Option<&Provider> {
        self.current_provider
            .as_ref()
            .and_then(|id| self.providers.get(id))
    }

    /// Set the current provider by ID
    pub fn set_current_provider(&mut self, id: Option<ProviderId>) {
        self.current_provider = id;
    }

    /// Add or update a provider
    pub fn upsert_provider(&mut self, provider: Provider) {
        self.providers.insert(provider.id.clone(), provider);
    }

    /// Remove a provider by ID
    pub fn remove_provider(&mut self, id: &str) -> Option<Provider> {
        // Clear current if it matches
        if self.current_provider.as_deref() == Some(id) {
            self.current_provider = None;
        }
        self.providers.shift_remove(id)
    }

    /// Add or update an MCP server
    pub fn upsert_mcp_server(&mut self, server: McpServer) {
        self.mcp_servers.insert(server.id.clone(), server);
    }

    /// Remove an MCP server by ID
    pub fn remove_mcp_server(&mut self, id: &str) -> Option<McpServer> {
        self.mcp_servers.shift_remove(id)
    }

    /// Add or update a skill
    pub fn upsert_skill(&mut self, skill: InstalledSkill) {
        self.skills.insert(skill.id.clone(), skill);
    }

    /// Remove a skill by ID
    pub fn remove_skill(&mut self, id: &str) -> Option<InstalledSkill> {
        self.skills.shift_remove(id)
    }

    /// Get providers sorted by sort_index
    pub fn providers_sorted(&self) -> Vec<&Provider> {
        let mut providers: Vec<_> = self.providers.values().collect();
        providers.sort_by(|a, b| {
            a.sort_index
                .unwrap_or(usize::MAX)
                .cmp(&b.sort_index.unwrap_or(usize::MAX))
        });
        providers
    }

    /// Get MCP servers sorted by sort_index
    pub fn mcp_servers_sorted(&self) -> Vec<&McpServer> {
        let mut servers: Vec<_> = self.mcp_servers.values().collect();
        servers.sort_by(|a, b| {
            a.sort_index
                .unwrap_or(usize::MAX)
                .cmp(&b.sort_index.unwrap_or(usize::MAX))
        });
        servers
    }

    /// Get skills sorted by sort_index
    pub fn skills_sorted(&self) -> Vec<&InstalledSkill> {
        let mut skills: Vec<_> = self.skills.values().collect();
        skills.sort_by(|a, b| {
            a.sort_index
                .unwrap_or(usize::MAX)
                .cmp(&b.sort_index.unwrap_or(usize::MAX))
        });
        skills
    }

    /// Get MCP servers enabled for a specific app
    pub fn mcp_servers_for_app(&self, app: &AppType) -> Vec<&McpServer> {
        self.mcp_servers
            .values()
            .filter(|s| s.apps.is_enabled_for(app))
            .collect()
    }

    /// Get skills enabled for a specific app
    pub fn skills_for_app(&self, app: &AppType) -> Vec<&InstalledSkill> {
        self.skills
            .values()
            .filter(|s| s.apps.is_enabled_for(app))
            .collect()
    }
}

// ============================================================================
// Panel Tab (UI state)
// ============================================================================

/// Panel tab selection
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PanelTab {
    #[default]
    Providers,
    Mcp,
    Skills,
}

impl PanelTab {
    pub fn label(&self) -> &'static str {
        match self {
            PanelTab::Providers => "Providers",
            PanelTab::Mcp => "MCP",
            PanelTab::Skills => "Skills",
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_app_type_from_str() {
        assert_eq!(AppType::from_str("claude").unwrap(), AppType::Claude);
        assert_eq!(AppType::from_str("CODEX").unwrap(), AppType::Codex);
        assert_eq!(AppType::from_str("Gemini").unwrap(), AppType::Gemini);
        assert_eq!(AppType::from_str("opencode").unwrap(), AppType::OpenCode);
        assert!(AppType::from_str("invalid").is_err());
    }

    #[test]
    fn test_mcp_apps() {
        let mut apps = McpApps::default();
        assert!(apps.is_empty());

        apps.set_enabled_for(&AppType::Claude, true);
        assert!(apps.is_enabled_for(&AppType::Claude));
        assert!(!apps.is_enabled_for(&AppType::Codex));
        assert!(!apps.is_empty());

        let enabled = apps.enabled_apps();
        assert_eq!(enabled.len(), 1);
        assert_eq!(enabled[0], AppType::Claude);
    }

    #[test]
    fn test_skill_apps() {
        let apps = SkillApps::only(&AppType::Gemini);
        assert!(apps.is_enabled_for(&AppType::Gemini));
        assert!(!apps.is_enabled_for(&AppType::Claude));

        let all = SkillApps::all_enabled();
        assert!(all.is_enabled_for(&AppType::Claude));
        assert!(all.is_enabled_for(&AppType::Codex));
        assert!(all.is_enabled_for(&AppType::Gemini));
        assert!(all.is_enabled_for(&AppType::OpenCode));
    }

    #[test]
    fn test_config_serialization() {
        let mut config = CcSwitchConfig::new();

        let provider = Provider::new(
            "test-provider",
            "Test Provider",
            serde_json::json!({ "key": "value" }),
        );
        config.upsert_provider(provider);
        config.set_current_provider(Some("test-provider".to_string()));

        let json = serde_json::to_string_pretty(&config).unwrap();
        let deserialized: CcSwitchConfig = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.providers.len(), 1);
        assert_eq!(
            deserialized.current_provider,
            Some("test-provider".to_string())
        );
    }

    #[test]
    fn test_mcp_server_sorting() {
        let mut config = CcSwitchConfig::new();

        config.upsert_mcp_server(McpServer {
            id: "server-a".to_string(),
            name: "Server A".to_string(),
            server: serde_json::json!({}),
            apps: McpApps::default(),
            description: None,
            homepage: None,
            docs: None,
            tags: vec![],
            sort_index: Some(2),
        });

        config.upsert_mcp_server(McpServer {
            id: "server-b".to_string(),
            name: "Server B".to_string(),
            server: serde_json::json!({}),
            apps: McpApps::default(),
            description: None,
            homepage: None,
            docs: None,
            tags: vec![],
            sort_index: Some(1),
        });

        let sorted = config.mcp_servers_sorted();
        assert_eq!(sorted[0].id, "server-b");
        assert_eq!(sorted[1].id, "server-a");
    }

    #[test]
    fn test_installed_skill_from_repo() {
        let skill =
            InstalledSkill::new_from_repo("owner", "repo", "main", "Test Skill", "skill-dir");

        assert_eq!(skill.id, "owner/repo:skill-dir");
        assert!(skill.is_from_repo());
        assert_eq!(skill.repo_owner, Some("owner".to_string()));
        assert_eq!(skill.repo_name, Some("repo".to_string()));
    }

    #[test]
    fn test_panel_tab_default() {
        let tab = PanelTab::default();
        assert_eq!(tab, PanelTab::Providers);
    }

    #[test]
    fn test_panel_tab_labels() {
        assert_eq!(PanelTab::Providers.label(), "Providers");
        assert_eq!(PanelTab::Mcp.label(), "MCP");
        assert_eq!(PanelTab::Skills.label(), "Skills");
    }

    #[test]
    fn test_app_type_all() {
        let all = AppType::all();
        assert_eq!(all.len(), 4);
        assert!(all.contains(&AppType::Claude));
        assert!(all.contains(&AppType::Codex));
        assert!(all.contains(&AppType::Gemini));
        assert!(all.contains(&AppType::OpenCode));
    }

    #[test]
    fn test_app_type_display() {
        assert_eq!(format!("{}", AppType::Claude), "claude");
        assert_eq!(format!("{}", AppType::Codex), "codex");
        assert_eq!(format!("{}", AppType::Gemini), "gemini");
        assert_eq!(format!("{}", AppType::OpenCode), "opencode");
    }

    #[test]
    fn test_provider_new() {
        let provider = Provider::new("test-id", "Test Provider", serde_json::json!({"key": "value"}));
        assert_eq!(provider.id, "test-id");
        assert_eq!(provider.name, "Test Provider");
        assert!(provider.settings_config.get("key").is_some());
    }

    #[test]
    fn test_mcp_server_new() {
        let server = McpServer::new("server-id", "Server Name", serde_json::json!({"type": "stdio"}));
        assert_eq!(server.id, "server-id");
        assert_eq!(server.name, "Server Name");
        assert!(server.apps.is_empty());
    }

    #[test]
    fn test_skill_local() {
        let skill = InstalledSkill::new_local("skill-id", "Skill Name", "skill-dir");
        assert_eq!(skill.id, "skill-id");
        assert_eq!(skill.name, "Skill Name");
        assert!(!skill.is_from_repo());
    }

    #[test]
    fn test_config_upsert_provider() {
        let mut config = CcSwitchConfig::new();
        let provider = Provider::new("p1", "Provider 1", serde_json::json!({}));

        config.upsert_provider(provider.clone());
        assert_eq!(config.providers.len(), 1);

        // Upsert same ID should replace
        let updated = Provider::new("p1", "Updated Provider", serde_json::json!({}));
        config.upsert_provider(updated);
        assert_eq!(config.providers.len(), 1);
        assert_eq!(config.providers.get("p1").unwrap().name, "Updated Provider");
    }

    #[test]
    fn test_config_remove_provider() {
        let mut config = CcSwitchConfig::new();
        config.upsert_provider(Provider::new("p1", "Provider 1", serde_json::json!({})));
        config.upsert_provider(Provider::new("p2", "Provider 2", serde_json::json!({})));

        assert_eq!(config.providers.len(), 2);
        config.remove_provider("p1");
        assert_eq!(config.providers.len(), 1);
        assert!(config.providers.get("p1").is_none());
    }

    #[test]
    fn test_skills_sorting() {
        let mut config = CcSwitchConfig::new();

        let mut s1 = InstalledSkill::new_local("s1", "Skill 1", "d1");
        s1.sort_index = Some(2);
        config.upsert_skill(s1);

        let mut s2 = InstalledSkill::new_local("s2", "Skill 2", "d2");
        s2.sort_index = Some(0);
        config.upsert_skill(s2);

        let mut s3 = InstalledSkill::new_local("s3", "Skill 3", "d3");
        s3.sort_index = Some(1);
        config.upsert_skill(s3);

        let sorted = config.skills_sorted();
        assert_eq!(sorted[0].id, "s2");
        assert_eq!(sorted[1].id, "s3");
        assert_eq!(sorted[2].id, "s1");
    }
}
