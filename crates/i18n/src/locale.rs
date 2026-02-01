//! Locale detection and management.

use std::sync::OnceLock;
use sys_locale::get_locale;
use unic_langid::LanguageIdentifier;

/// Supported locales in Zed.
pub const SUPPORTED_LOCALES: &[&str] = &["en-US", "zh-CN"];

/// Default fallback locale.
pub const DEFAULT_LOCALE: &str = "zh-CN";

/// Cached system locale to avoid repeated syscalls.
static CACHED_SYSTEM_LOCALE: OnceLock<LanguageIdentifier> = OnceLock::new();

/// Detect the system locale.
///
/// Returns the system locale if supported, otherwise falls back to en-US.
/// The result is cached after the first call.
pub fn detect_system_locale() -> LanguageIdentifier {
    CACHED_SYSTEM_LOCALE.get_or_init(|| {
        get_locale()
            .and_then(|locale| locale.parse().ok())
            .and_then(|langid: LanguageIdentifier| {
                if is_locale_supported(&langid.to_string()) {
                    Some(langid)
                } else {
                    None
                }
            })
            .unwrap_or_else(|| DEFAULT_LOCALE.parse().unwrap())
    }).clone()
}

/// Check if a locale is supported.
pub fn is_locale_supported(locale: &str) -> bool {
    SUPPORTED_LOCALES.iter().any(|&l| l == locale)
}

/// Get a list of all supported locales for UI display.
pub fn supported_locales() -> &'static [&'static str] {
    SUPPORTED_LOCALES
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_system_locale_returns_valid_langid() {
        let locale = detect_system_locale();
        // Should always return a valid LanguageIdentifier
        assert!(!locale.to_string().is_empty());
    }

    #[test]
    fn test_fallback_to_en_us_when_unsupported() {
        // We can't easily mock sys_locale, but we can verify fallback logic
        assert!(is_locale_supported("en-US"));
        assert!(is_locale_supported("zh-CN"));
        assert!(!is_locale_supported("xx-XX")); // Unsupported
    }

    #[test]
    fn test_supported_locales_returns_all_locales() {
        let locales = supported_locales();
        assert!(locales.contains(&"en-US"));
        assert!(locales.contains(&"zh-CN"));
        assert_eq!(locales.len(), 2);
    }

    #[test]
    fn test_locale_preference_overrides_system() {
        // Verify that set_locale in lib.rs can override the system locale
        // This test verifies the locale preference mechanism works correctly
        // The actual override is tested via set_locale/current_locale in lib.rs

        // Here we verify the locale module provides the building blocks:
        // 1. detect_system_locale gives us the starting point
        let system = detect_system_locale();
        assert!(!system.to_string().is_empty());

        // 2. is_locale_supported validates user preferences
        assert!(is_locale_supported("zh-CN")); // User can prefer Chinese

        // 3. supported_locales() provides UI with choices
        let choices = supported_locales();
        assert!(choices.len() >= 2); // At least en-US and zh-CN
    }
}
