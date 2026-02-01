//! Internationalization (i18n) support for Zed using fluent-rs.
//!
//! This crate provides translation functions for localizing the Zed editor UI.

use std::collections::HashMap;
use std::sync::OnceLock;
use unic_langid::LanguageIdentifier;

mod loader;
mod locale;

// Re-exports
pub use loader::*;
pub use locale::*;

/// Global locale state
static CURRENT_LOCALE: OnceLock<std::sync::RwLock<LanguageIdentifier>> = OnceLock::new();

fn get_locale_lock() -> &'static std::sync::RwLock<LanguageIdentifier> {
    CURRENT_LOCALE.get_or_init(|| {
        std::sync::RwLock::new("zh-CN".parse().unwrap())
    })
}

/// Translate a message key to the current locale.
///
/// Returns the translated string, or the key itself if translation is not found.
pub fn t(key: &str) -> String {
    let locale = current_locale();

    // Try to resolve from the current locale
    if let Some(translated) = loader::resolve_message(&locale, key) {
        return translated;
    }

    // Fallback to en-US if not the current locale
    if locale != "en-US" {
        if let Some(translated) = loader::resolve_message("en-US", key) {
            return translated;
        }
    }

    // Final fallback: return the key
    key.to_string()
}

/// Translate a message key with interpolation arguments.
///
/// # Arguments
/// * `key` - The translation key
/// * `args` - A map of argument names to values for interpolation
pub fn t_args(key: &str, args: &HashMap<&str, &str>) -> String {
    let locale = current_locale();

    // Try to resolve from the current locale
    if let Some(translated) = loader::resolve_message_with_args(&locale, key, args) {
        return translated;
    }

    // Fallback to en-US if not the current locale
    if locale != "en-US" {
        if let Some(translated) = loader::resolve_message_with_args("en-US", key, args) {
            return translated;
        }
    }

    // Final fallback: return the key
    key.to_string()
}

/// Set the active locale for translations.
pub fn set_locale(locale: &str) -> Result<(), LocaleError> {
    let langid: LanguageIdentifier = locale.parse().map_err(|_| LocaleError::InvalidLocale)?;

    // Pre-load the bundle for this locale
    let _ = loader::load_bundle(locale);

    *get_locale_lock().write().unwrap() = langid;
    Ok(())
}

/// Get the current active locale.
pub fn current_locale() -> String {
    get_locale_lock().read().unwrap().to_string()
}

/// Errors that can occur during locale operations.
#[derive(Debug, Clone, PartialEq)]
pub enum LocaleError {
    InvalidLocale,
    LocaleNotSupported,
}

impl std::fmt::Display for LocaleError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LocaleError::InvalidLocale => write!(f, "Invalid locale format"),
            LocaleError::LocaleNotSupported => write!(f, "Locale not supported"),
        }
    }
}

impl std::error::Error for LocaleError {}

#[cfg(test)]
mod tests {
    use super::*;

    /// Test that t() returns the translated string for a known key.
    #[test]
    fn test_t_function_returns_translated_string() {
        // Setup: Set locale to zh-CN which should have "hello" = "你好"
        set_locale("zh-CN").unwrap();

        // Act: Get translation for "hello" key
        let result = t("hello");

        // Assert: Should return "你好"
        assert_eq!(result, "你好");
    }

    /// Test that t() returns the key when translation is missing.
    #[test]
    fn test_t_function_returns_key_when_missing() {
        set_locale("zh-CN").unwrap();

        // Request a non-existent key
        let result = t("nonexistent-key-12345");

        // Should return the key itself as fallback
        assert_eq!(result, "nonexistent-key-12345");
    }

    /// Test that t_args() interpolates values into the translation.
    #[test]
    fn test_t_args_interpolates_values() {
        set_locale("zh-CN").unwrap();

        // Translation: "greeting" = "你好，{name}！"
        let mut args = HashMap::new();
        args.insert("name", "World");

        let result = t_args("greeting", &args);

        // Fluent adds Unicode isolation characters (U+2068/U+2069) around placeholders
        // for bidirectional text support. We check the content is correct.
        assert!(result.contains("你好"));
        assert!(result.contains("World"));
        assert!(result.contains("！"));
    }

    /// Test that set_locale changes the active language.
    #[test]
    fn test_set_locale_changes_language() {
        // Set to English
        set_locale("en-US").unwrap();

        // Get translation - should return English
        let result = t("hello");

        assert_eq!(result, "Hello");
    }

    /// Test that current_locale returns the active locale.
    #[test]
    fn test_current_locale_returns_active_locale() {
        set_locale("zh-CN").unwrap();
        assert_eq!(current_locale(), "zh-CN");

        set_locale("en-US").unwrap();
        assert_eq!(current_locale(), "en-US");
    }
}
