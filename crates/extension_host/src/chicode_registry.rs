//! Chi Code Extension Registry Configuration
//!
//! This module provides the extension registry URLs for Chi Code.
//! Extensions are hosted on GitHub and downloaded from GitHub Releases.
//!
//! Environment variables for testing:
//! - CHICODE_EXTENSIONS_INDEX_URL: Override the index URL
//! - CHICODE_EXTENSIONS_DOWNLOAD_BASE: Override the download base URL

use std::env;

/// Base URL for the Chi Code extension registry
pub const CHICODE_EXTENSIONS_REPO: &str = "https://github.com/yanghao1143/chicode-extensions";

/// Default URL for the extension index JSON file
const DEFAULT_INDEX_URL: &str =
    "https://github.com/yanghao1143/chicode-extensions/releases/download/extensions-latest/index.json";

/// Default base URL for downloading extension packages
const DEFAULT_DOWNLOAD_BASE: &str =
    "https://github.com/yanghao1143/chicode-extensions/releases/download/extensions-latest";

/// Get the extension index URL (supports env override for testing)
pub fn extensions_index_url() -> String {
    env::var("CHICODE_EXTENSIONS_INDEX_URL").unwrap_or_else(|_| DEFAULT_INDEX_URL.to_string())
}

/// Get the download base URL (supports env override for testing)
pub fn extensions_download_base() -> String {
    env::var("CHICODE_EXTENSIONS_DOWNLOAD_BASE").unwrap_or_else(|_| DEFAULT_DOWNLOAD_BASE.to_string())
}

/// Constructs the download URL for a specific extension
pub fn extension_download_url(extension_id: &str) -> String {
    format!("{}/{}.tar.gz", extensions_download_base(), extension_id)
}

/// Constructs the download URL for a specific extension version
/// Note: Currently we only support latest version from GitHub releases
pub fn extension_version_download_url(extension_id: &str, _version: &str) -> String {
    // TODO: Support versioned releases (e.g., extensions-v1.0.0)
    extension_download_url(extension_id)
}
