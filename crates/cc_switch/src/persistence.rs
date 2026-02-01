//! Persistence layer for CC-Switch
//!
//! Uses Zed's KVP store for storing configurations.

use anyhow::Result;
use db::kvp::KEY_VALUE_STORE;

use crate::{InstalledSkill, McpServer, Provider};

const PROVIDERS_KEY: &str = "cc_switch::providers";
const MCP_SERVERS_KEY: &str = "cc_switch::mcp_servers";
const SKILLS_KEY: &str = "cc_switch::skills";
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
