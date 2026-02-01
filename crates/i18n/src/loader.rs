//! FTL file loader and FluentBundle management.

use fluent_bundle::bundle::FluentBundle;
use fluent_bundle::{FluentArgs, FluentResource, FluentValue};
use intl_memoizer::concurrent::IntlLangMemoizer;
use std::collections::HashMap;
use std::sync::{OnceLock, RwLock};
use unic_langid::LanguageIdentifier;

/// Thread-safe bundle storage using concurrent FluentBundle
type ConcurrentBundle = FluentBundle<FluentResource, IntlLangMemoizer>;

/// Global bundle cache - lazily initialized
static BUNDLE_CACHE: OnceLock<RwLock<HashMap<String, ConcurrentBundle>>> = OnceLock::new();

fn get_cache() -> &'static RwLock<HashMap<String, ConcurrentBundle>> {
    BUNDLE_CACHE.get_or_init(|| RwLock::new(HashMap::new()))
}

/// Load a FluentBundle for the given locale with embedded translations.
pub fn load_bundle(locale: &str) -> Result<(), LoaderError> {
    let langid: LanguageIdentifier = locale.parse().map_err(|_| LoaderError::InvalidLocale)?;

    // Check if already loaded
    {
        let cache = get_cache().read().unwrap();
        if cache.contains_key(locale) {
            return Ok(());
        }
    }

    // Load translations based on locale
    let ftl_content = get_ftl_content(locale)?;

    let resource = match FluentResource::try_new(ftl_content) {
        Ok(r) => r,
        Err((r, errors)) => {
            #[cfg(test)]
            {
                eprintln!("FTL parse errors for {}: {} errors", locale, errors.len());
                for (i, err) in errors.iter().take(10).enumerate() {
                    eprintln!("  Error {}: {:?}", i + 1, err);
                }
            }
            // Continue with partial resource if we have some valid entries
            r
        }
    };

    let mut bundle = FluentBundle::new_concurrent(vec![langid]);
    if let Err(errors) = bundle.add_resource(resource) {
        #[cfg(test)]
        {
            eprintln!("Bundle add_resource errors for {}: {} errors", locale, errors.len());
            for (i, err) in errors.iter().take(10).enumerate() {
                eprintln!("  Error {}: {:?}", i + 1, err);
            }
        }
        return Err(LoaderError::ParseError);
    }

    // Store in cache
    let mut cache = get_cache().write().unwrap();
    cache.insert(locale.to_string(), bundle);

    Ok(())
}

/// Get embedded FTL content for a locale
fn get_ftl_content(locale: &str) -> Result<String, LoaderError> {
    match locale {
        "en-US" => Ok(include_str!("../locales/en-US/main.ftl").to_string()),
        "zh-CN" => Ok(include_str!("../locales/zh-CN/main.ftl").to_string()),
        _ => Err(LoaderError::FileNotFound),
    }
}

/// Resolve a message from the bundle for the specified locale.
pub fn resolve_message(locale: &str, key: &str) -> Option<String> {
    // Try to load the bundle if not already loaded
    if load_bundle(locale).is_err() {
        return None;
    }

    let cache = get_cache().read().unwrap();
    let bundle = cache.get(locale)?;

    let msg = bundle.get_message(key)?;
    let pattern = msg.value()?;

    let mut errors = vec![];
    let result = bundle.format_pattern(pattern, None, &mut errors);

    Some(result.to_string())
}

/// Resolve a message with arguments for interpolation.
pub fn resolve_message_with_args(locale: &str, key: &str, args: &HashMap<&str, &str>) -> Option<String> {
    // Try to load the bundle if not already loaded
    if load_bundle(locale).is_err() {
        return None;
    }

    let cache = get_cache().read().unwrap();
    let bundle = cache.get(locale)?;

    let msg = bundle.get_message(key)?;
    let pattern = msg.value()?;

    // Convert args to FluentArgs
    let mut fluent_args = FluentArgs::new();
    for (k, v) in args {
        fluent_args.set(*k, FluentValue::from(*v));
    }

    let mut errors = vec![];
    let result = bundle.format_pattern(pattern, Some(&fluent_args), &mut errors);

    Some(result.to_string())
}

/// Errors that can occur during FTL loading.
#[derive(Debug, Clone, PartialEq)]
pub enum LoaderError {
    InvalidLocale,
    FileNotFound,
    ParseError,
}

impl std::fmt::Display for LoaderError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LoaderError::InvalidLocale => write!(f, "Invalid locale format"),
            LoaderError::FileNotFound => write!(f, "FTL file not found"),
            LoaderError::ParseError => write!(f, "Failed to parse FTL file"),
        }
    }
}

impl std::error::Error for LoaderError {}

#[cfg(test)]
mod tests {
    use super::*;

    /// Test that loading a valid locale succeeds.
    #[test]
    fn test_load_ftl_file_parses_correctly() {
        let result = load_bundle("en-US");
        if let Err(ref e) = result {
            eprintln!("Error loading en-US bundle: {:?}", e);
        }
        assert!(result.is_ok());
    }

    /// Test that loading an invalid locale returns error.
    #[test]
    fn test_load_missing_locale_returns_error() {
        // "!!!invalid!!!" is not a valid BCP 47 locale tag
        let result = load_bundle("!!!invalid!!!");
        assert!(result.is_err());
    }

    /// Test that bundle resolves messages correctly.
    #[test]
    fn test_bundle_resolves_message() {
        load_bundle("en-US").unwrap();
        let result = resolve_message("en-US", "hello");
        assert_eq!(result, Some("Hello".to_string()));
    }
}
