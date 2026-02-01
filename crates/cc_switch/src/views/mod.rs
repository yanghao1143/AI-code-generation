//! View modules for CC-Switch panel
//!
//! Contains sub-views for providers, MCP servers, and skills management.

pub mod add_mcp_server_modal;
pub mod add_provider_modal;
pub mod add_skill_modal;
pub mod mcp_view;
pub mod providers_view;
pub mod skills_view;

pub use add_mcp_server_modal::*;
pub use add_provider_modal::*;
pub use add_skill_modal::*;
pub use mcp_view::*;
pub use providers_view::*;
pub use skills_view::*;
