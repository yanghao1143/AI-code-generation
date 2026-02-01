//! CC-Switch panel for Zed IDE
//!
//! Provides a left sidebar panel for managing:
//! - AI Providers (API keys, configurations)
//! - MCP Servers (Model Context Protocol)
//! - Skills (Claude Code slash commands)

mod cc_switch_panel;
mod cc_switch_settings;
pub mod config_sync;
mod models;
mod persistence;
mod views;

pub use cc_switch_panel::CcSwitchPanel;
pub use cc_switch_settings::CcSwitchSettings;
pub use config_sync::{
    // Path helpers
    claude_code_config_dir,
    claude_mcp_path,
    claude_skills_dir,
    codex_config_dir,
    codex_config_path,
    // Skill helpers
    copy_skill_to_app,
    gemini_config_dir,
    gemini_settings_path,
    get_app_skills_dir,
    // Load functions
    load_mcp_servers_from_claude,
    load_mcp_servers_from_codex,
    load_mcp_servers_from_gemini,
    remove_skill_from_app,
    // Sync functions
    sync_all_mcp_servers,
    sync_all_skills,
    sync_mcp_to_claude,
    sync_mcp_to_codex,
    sync_mcp_to_gemini,
    sync_provider_to_app,
    sync_skills_to_claude,
};
pub use models::*;

use gpui::App;
use settings::Settings;

/// Initialize the CC-Switch crate
pub fn init(cx: &mut App) {
    CcSwitchSettings::register(cx);
    cc_switch_panel::init(cx);
}
