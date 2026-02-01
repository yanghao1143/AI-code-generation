//! Persistence layer for CC-Switch
//!
//! Uses Zed's KVP store for storing panel state and configurations.

use anyhow::Result;
use db::kvp::KEY_VALUE_STORE;
use serde::{Deserialize, Serialize};

use crate::{InstalledSkill, McpServer, Provider};

const PROVIDERS_KEY: &str = "cc_switch::providers";
const MCP_SERVERS_KEY: &str = "cc_switch::mcp_servers";
const SKILLS_KEY: &str = "cc_switch::skills";
const PANEL_STATE_KEY: &str = "cc_switch::panel_state";

/// Persisted panel state
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PanelState {
    pub active_tab_index: usize,
    pub expanded_sections: Vec<String>,
}

/// Load providers from persistence
pub async fn load_providers() -> Result<Vec<Provider>> {
    let data = KEY_VALUE_STORE.read_kvp(PROVIDERS_KEY)?;
    match data {
        Some(json) => Ok(serde_json::from_str(&json)?),
        None => Ok(Vec::new()),
    }
}

/// Save providers to persistence
pub async fn save_providers(providers: &[Provider]) -> Result<()> {
    let json = serde_json::to_string(providers)?;
    KEY_VALUE_STORE.write_kvp(PROVIDERS_KEY.to_string(), json).await?;
    Ok(())
}

/// Load MCP servers from persistence
pub async fn load_mcp_servers() -> Result<Vec<McpServer>> {
    let data = KEY_VALUE_STORE.read_kvp(MCP_SERVERS_KEY)?;
    match data {
        Some(json) => Ok(serde_json::from_str(&json)?),
        None => Ok(Vec::new()),
    }
}

/// Save MCP servers to persistence
pub async fn save_mcp_servers(servers: &[McpServer]) -> Result<()> {
    let json = serde_json::to_string(servers)?;
    KEY_VALUE_STORE.write_kvp(MCP_SERVERS_KEY.to_string(), json).await?;
    Ok(())
}

/// Load skills from persistence
pub async fn load_skills() -> Result<Vec<InstalledSkill>> {
    let data = KEY_VALUE_STORE.read_kvp(SKILLS_KEY)?;
    match data {
        Some(json) => Ok(serde_json::from_str(&json)?),
        None => Ok(Vec::new()),
    }
}

/// Save skills to persistence
pub async fn save_skills(skills: &[InstalledSkill]) -> Result<()> {
    let json = serde_json::to_string(skills)?;
    KEY_VALUE_STORE.write_kvp(SKILLS_KEY.to_string(), json).await?;
    Ok(())
}

/// Load panel state from persistence
pub async fn load_panel_state() -> Result<PanelState> {
    let data = KEY_VALUE_STORE.read_kvp(PANEL_STATE_KEY)?;
    match data {
        Some(json) => Ok(serde_json::from_str(&json)?),
        None => Ok(PanelState::default()),
    }
}

/// Save panel state to persistence
pub async fn save_panel_state(state: &PanelState) -> Result<()> {
    let json = serde_json::to_string(state)?;
    KEY_VALUE_STORE.write_kvp(PANEL_STATE_KEY.to_string(), json).await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_panel_state_default() {
        let state = PanelState::default();
        assert_eq!(state.active_tab_index, 0);
        assert!(state.expanded_sections.is_empty());
    }

    #[test]
    fn test_panel_state_serialization() {
        let state = PanelState {
            active_tab_index: 2,
            expanded_sections: vec!["providers".to_string(), "mcp".to_string()],
        };

        let json = serde_json::to_string(&state).unwrap();
        let deserialized: PanelState = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.active_tab_index, 2);
        assert_eq!(deserialized.expanded_sections.len(), 2);
        assert_eq!(deserialized.expanded_sections[0], "providers");
        assert_eq!(deserialized.expanded_sections[1], "mcp");
    }
}
