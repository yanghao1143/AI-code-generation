//! Configuration sync for CC-Switch
//!
//! Synchronizes configurations with external applications:
//! - Claude: ~/.claude.json (mcpServers object)
//! - Codex: ~/.codex/config.toml (mcp_servers section)
//! - Gemini: ~/.gemini/settings.json (mcpServers object)
//! - Skills: ~/.claude/commands/ directory for Claude

use anyhow::{Context, Result};
use ::fs::Fs;
use indexmap::IndexMap;
use serde_json::{Map, Value, json};
use std::collections::HashMap;
use std::fs;
use std::io::Write as IoWrite;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::{AppType, InstalledSkill, McpServer, McpServerId, Provider, SkillId};

// ============================================================================
// Path Helpers
// ============================================================================

#[cfg(test)]
static TEST_HOME_DIR: std::sync::LazyLock<std::sync::Mutex<Option<PathBuf>>> =
    std::sync::LazyLock::new(|| std::sync::Mutex::new(None));

/// Get user home directory
fn get_home_dir() -> Option<PathBuf> {
    #[cfg(test)]
    {
        let guard = TEST_HOME_DIR.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(home) = guard.clone() {
            return Some(home);
        }
    }

    // Check environment variables first (for testing)
    if let Ok(home) = std::env::var("HOME") {
        return Some(PathBuf::from(home));
    }
    #[cfg(windows)]
    if let Ok(userprofile) = std::env::var("USERPROFILE") {
        return Some(PathBuf::from(userprofile));
    }
    dirs::home_dir()
}

/// Path to Claude Code configuration directory (~/.claude)
pub fn claude_code_config_dir() -> Option<PathBuf> {
    get_home_dir().map(|home| home.join(".claude"))
}

/// Path to Claude MCP configuration file (~/.claude.json)
pub fn claude_mcp_path() -> Option<PathBuf> {
    get_home_dir().map(|home| home.join(".claude.json"))
}

/// Path to Codex configuration directory (~/.codex)
pub fn codex_config_dir() -> Option<PathBuf> {
    get_home_dir().map(|home| home.join(".codex"))
}

/// Path to Codex config file (~/.codex/config.toml)
pub fn codex_config_path() -> Option<PathBuf> {
    codex_config_dir().map(|dir| dir.join("config.toml"))
}

/// Path to Gemini configuration directory (~/.gemini)
pub fn gemini_config_dir() -> Option<PathBuf> {
    get_home_dir().map(|home| home.join(".gemini"))
}

/// Path to Gemini settings file (~/.gemini/settings.json)
pub fn gemini_settings_path() -> Option<PathBuf> {
    gemini_config_dir().map(|dir| dir.join("settings.json"))
}

/// Path to OpenCode configuration directory (~/.config/opencode)
pub fn opencode_config_dir() -> Option<PathBuf> {
    #[cfg(windows)]
    {
        get_home_dir().map(|home| home.join(".config").join("opencode"))
    }
    #[cfg(not(windows))]
    {
        get_home_dir().map(|home| home.join(".config").join("opencode"))
    }
}

/// Path to OpenCode MCP configuration file
pub fn opencode_mcp_path() -> Option<PathBuf> {
    opencode_config_dir().map(|dir| dir.join("mcp_servers.json"))
}

/// Path to OpenCode settings file (~/.config/opencode/config.json or settings.json)
pub fn opencode_settings_path() -> Option<PathBuf> {
    opencode_config_dir().map(|dir| {
        let config_path = dir.join("config.json");
        let settings_path = dir.join("settings.json");
        if config_path.exists() {
            config_path
        } else if settings_path.exists() {
            settings_path
        } else {
            config_path
        }
    })
}

/// Path to Claude skills directory (~/.claude/commands)
pub fn claude_skills_dir() -> Option<PathBuf> {
    claude_code_config_dir().map(|dir| dir.join("commands"))
}

/// Get skills directory for a specific app
pub fn get_app_skills_dir(app: &AppType) -> Option<PathBuf> {
    let home = get_home_dir()?;
    Some(match app {
        AppType::Claude => home.join(".claude").join("commands"),
        AppType::Codex => home.join(".codex").join("commands"),
        AppType::Gemini => home.join(".gemini").join("commands"),
        AppType::OpenCode => home.join(".config").join("opencode").join("commands"),
    })
}

// ============================================================================
// App Detection
// ============================================================================

/// Check if Claude is installed/initialized
fn should_sync_claude() -> bool {
    let config_dir = claude_code_config_dir();
    let mcp_path = claude_mcp_path();
    config_dir.map(|d| d.exists()).unwrap_or(false) || mcp_path.map(|p| p.exists()).unwrap_or(false)
}

/// Check if Codex is installed/initialized
fn should_sync_codex() -> bool {
    codex_config_dir().map(|d| d.exists()).unwrap_or(false)
}

/// Check if Gemini is installed/initialized
fn should_sync_gemini() -> bool {
    gemini_config_dir().map(|d| d.exists()).unwrap_or(false)
}

/// Check if OpenCode is installed/initialized
fn should_sync_opencode() -> bool {
    let config_dir = opencode_config_dir();
    let settings_path = opencode_settings_path();
    config_dir.map(|d| d.exists()).unwrap_or(false)
        || settings_path.map(|p| p.exists()).unwrap_or(false)
}

// ============================================================================
// Atomic Write Helpers
// ============================================================================

/// Atomic write: write to temp file then rename
fn atomic_write(path: &Path, data: &[u8]) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).context("Failed to create parent directory")?;
    }

    let parent = path.parent().context("Invalid path")?;
    let file_name = path
        .file_name()
        .context("Invalid file name")?
        .to_string_lossy()
        .to_string();

    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();

    let tmp_path = parent.join(format!("{}.tmp.{}", file_name, ts));

    {
        let mut f = fs::File::create(&tmp_path).context("Failed to create temp file")?;
        f.write_all(data).context("Failed to write data")?;
        f.flush().context("Failed to flush")?;
    }

    // On Windows, we need to remove the target first
    #[cfg(windows)]
    {
        if path.exists() {
            let _ = fs::remove_file(path);
        }
    }

    fs::rename(&tmp_path, path).context("Failed to rename temp file")?;
    Ok(())
}

/// Read JSON from file, return empty object if not exists
fn read_json_file(path: &Path) -> Result<Value> {
    if !path.exists() {
        return Ok(json!({}));
    }
    let content = fs::read_to_string(path).context("Failed to read file")?;
    let value: Value = serde_json::from_str(&content).context("Failed to parse JSON")?;
    Ok(value)
}

/// Write JSON to file atomically
fn write_json_file(path: &Path, value: &Value) -> Result<()> {
    let json = serde_json::to_string_pretty(value).context("Failed to serialize JSON")?;
    atomic_write(path, json.as_bytes())
}

// ============================================================================
// MCP Server Spec Extraction
// ============================================================================

/// Extract server spec from McpServer (remove UI fields, keep only MCP protocol fields)
fn extract_server_spec(server: &McpServer) -> Value {
    let mut spec = server.server.clone();

    // Remove UI-only fields that shouldn't be in the actual MCP config
    if let Some(obj) = spec.as_object_mut() {
        obj.remove("enabled");
        obj.remove("source");
        obj.remove("id");
        obj.remove("name");
        obj.remove("description");
        obj.remove("tags");
        obj.remove("homepage");
        obj.remove("docs");
        obj.remove("sortIndex");
    }

    spec
}

/// Commands that need cmd /c wrapper on Windows
#[cfg(windows)]
const WINDOWS_WRAP_COMMANDS: &[&str] = &["npx", "npm", "yarn", "pnpm", "node", "bun", "deno"];

/// Wrap command for Windows (npx, npm, etc. need cmd /c)
#[cfg(windows)]
fn wrap_command_for_windows(obj: &mut Map<String, Value>) {
    // Only process stdio type
    let server_type = obj.get("type").and_then(|v| v.as_str()).unwrap_or("stdio");
    if server_type != "stdio" {
        return;
    }

    let Some(cmd) = obj.get("command").and_then(|v| v.as_str()) else {
        return;
    };

    // Already cmd, don't wrap again
    if cmd.eq_ignore_ascii_case("cmd") || cmd.eq_ignore_ascii_case("cmd.exe") {
        return;
    }

    // Extract command name (remove .cmd suffix and path)
    let cmd_name = Path::new(cmd)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or(cmd);

    let needs_wrap = WINDOWS_WRAP_COMMANDS
        .iter()
        .any(|&c| cmd_name.eq_ignore_ascii_case(c));

    if !needs_wrap {
        return;
    }

    // Build new args: ["/c", "original_command", ...original_args]
    let original_args = obj
        .get("args")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let mut new_args = vec![Value::String("/c".into()), Value::String(cmd.into())];
    new_args.extend(original_args);

    obj.insert("command".into(), Value::String("cmd".into()));
    obj.insert("args".into(), Value::Array(new_args));
}

#[cfg(not(windows))]
fn wrap_command_for_windows(_obj: &mut Map<String, Value>) {
    // No-op on non-Windows
}

// ============================================================================
// Claude MCP Sync
// ============================================================================

/// Sync MCP servers to Claude configuration (~/.claude.json)
pub async fn sync_mcp_to_claude(servers: &IndexMap<McpServerId, McpServer>) -> Result<()> {
    if !should_sync_claude() {
        log::debug!("Claude not installed, skipping MCP sync");
        return Ok(());
    }

    let Some(path) = claude_mcp_path() else {
        return Ok(());
    };

    // Read existing config
    let mut root = read_json_file(&path)?;

    // Build mcpServers object from servers with claude=true
    let mut mcp_servers: Map<String, Value> = Map::new();
    for (id, server) in servers.iter() {
        if server.apps.claude {
            let mut spec = extract_server_spec(server);
            if let Some(obj) = spec.as_object_mut() {
                wrap_command_for_windows(obj);
            }
            mcp_servers.insert(id.clone(), spec);
        }
    }

    // Update config
    if let Some(obj) = root.as_object_mut() {
        obj.insert("mcpServers".into(), Value::Object(mcp_servers));
    }

    // Write atomically
    write_json_file(&path, &root)?;

    log::info!("Synced MCP servers to Claude");
    Ok(())
}

/// Read MCP servers from Claude configuration
pub async fn load_mcp_servers_from_claude() -> Result<HashMap<String, Value>> {
    let Some(path) = claude_mcp_path() else {
        return Ok(HashMap::new());
    };

    if !path.exists() {
        return Ok(HashMap::new());
    }

    let root = read_json_file(&path)?;
    let servers = root
        .get("mcpServers")
        .and_then(|v| v.as_object())
        .map(|obj| obj.iter().map(|(k, v)| (k.clone(), v.clone())).collect())
        .unwrap_or_default();

    Ok(servers)
}

// ============================================================================
// Codex MCP Sync (TOML format)
// ============================================================================

/// Convert JSON server spec to TOML table
fn json_server_to_toml_table(spec: &Value) -> Result<toml_edit::Table> {
    use toml_edit::{Array, Item, Table};

    let mut t = Table::new();
    let typ = spec.get("type").and_then(|v| v.as_str()).unwrap_or("stdio");
    t["type"] = toml_edit::value(typ);

    match typ {
        "stdio" => {
            let cmd = spec.get("command").and_then(|v| v.as_str()).unwrap_or("");
            t["command"] = toml_edit::value(cmd);

            if let Some(args) = spec.get("args").and_then(|v| v.as_array()) {
                let mut arr_v = Array::default();
                for a in args.iter().filter_map(|x| x.as_str()) {
                    arr_v.push(a);
                }
                if !arr_v.is_empty() {
                    t["args"] = Item::Value(toml_edit::Value::Array(arr_v));
                }
            }

            if let Some(cwd) = spec.get("cwd").and_then(|v| v.as_str()) {
                if !cwd.trim().is_empty() {
                    t["cwd"] = toml_edit::value(cwd);
                }
            }

            if let Some(env) = spec.get("env").and_then(|v| v.as_object()) {
                let mut env_tbl = Table::new();
                for (k, v) in env.iter() {
                    if let Some(s) = v.as_str() {
                        env_tbl[&k[..]] = toml_edit::value(s);
                    }
                }
                if !env_tbl.is_empty() {
                    t["env"] = Item::Table(env_tbl);
                }
            }
        }
        "http" | "sse" => {
            let url = spec.get("url").and_then(|v| v.as_str()).unwrap_or("");
            t["url"] = toml_edit::value(url);

            if let Some(headers) = spec.get("headers").and_then(|v| v.as_object()) {
                let mut h_tbl = Table::new();
                for (k, v) in headers.iter() {
                    if let Some(s) = v.as_str() {
                        h_tbl[&k[..]] = toml_edit::value(s);
                    }
                }
                if !h_tbl.is_empty() {
                    t["http_headers"] = Item::Table(h_tbl);
                }
            }
        }
        _ => {}
    }

    Ok(t)
}

/// Sync MCP servers to Codex configuration (~/.codex/config.toml)
pub async fn sync_mcp_to_codex(servers: &IndexMap<McpServerId, McpServer>) -> Result<()> {
    if !should_sync_codex() {
        log::debug!("Codex not installed, skipping MCP sync");
        return Ok(());
    }

    let Some(path) = codex_config_path() else {
        return Ok(());
    };

    use toml_edit::{Item, Table};

    // Read existing config
    let base_text = if path.exists() {
        fs::read_to_string(&path).unwrap_or_default()
    } else {
        String::new()
    };

    // Parse with toml_edit
    let mut doc = if base_text.trim().is_empty() {
        toml_edit::DocumentMut::default()
    } else {
        base_text
            .parse::<toml_edit::DocumentMut>()
            .context("Failed to parse config.toml")?
    };

    // Build servers table
    let enabled: Vec<_> = servers.iter().filter(|(_, s)| s.apps.codex).collect();

    if enabled.is_empty() {
        // No enabled servers: remove mcp_servers table
        doc.as_table_mut().remove("mcp_servers");
    } else {
        let mut servers_tbl = Table::new();
        let mut ids: Vec<String> = enabled.iter().map(|(id, _)| (*id).clone()).collect();
        ids.sort();

        for id in ids {
            if let Some((_, server)) = enabled.iter().find(|(i, _)| *i == &id) {
                let spec = extract_server_spec(server);
                match json_server_to_toml_table(&spec) {
                    Ok(table) => {
                        servers_tbl[&id[..]] = Item::Table(table);
                    }
                    Err(err) => {
                        log::warn!("Skipping invalid MCP server '{}': {}", id, err);
                    }
                }
            }
        }
        doc["mcp_servers"] = Item::Table(servers_tbl);
    }

    // Write back
    let new_text = doc.to_string();
    atomic_write(&path, new_text.as_bytes())?;

    log::info!("Synced MCP servers to Codex");
    Ok(())
}

/// Read MCP servers from Codex configuration
pub async fn load_mcp_servers_from_codex() -> Result<HashMap<String, Value>> {
    let Some(path) = codex_config_path() else {
        return Ok(HashMap::new());
    };

    if !path.exists() {
        return Ok(HashMap::new());
    }

    let text = fs::read_to_string(&path)?;
    if text.trim().is_empty() {
        return Ok(HashMap::new());
    }

    let root: toml::Table = toml::from_str(&text).context("Failed to parse config.toml")?;

    let mut servers = HashMap::new();

    // Process mcp_servers section
    if let Some(servers_val) = root.get("mcp_servers").and_then(|v| v.as_table()) {
        for (id, entry_val) in servers_val.iter() {
            if let Some(entry_tbl) = entry_val.as_table() {
                let spec = toml_entry_to_json_spec(entry_tbl);
                servers.insert(id.clone(), spec);
            }
        }
    }

    Ok(servers)
}

/// Convert TOML entry to JSON server spec
fn toml_entry_to_json_spec(entry: &toml::Table) -> Value {
    let typ = entry
        .get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("stdio");

    let mut spec = serde_json::Map::new();
    spec.insert("type".into(), json!(typ));

    match typ {
        "stdio" => {
            if let Some(cmd) = entry.get("command").and_then(|v| v.as_str()) {
                spec.insert("command".into(), json!(cmd));
            }
            if let Some(args) = entry.get("args").and_then(|v| v.as_array()) {
                let arr: Vec<_> = args
                    .iter()
                    .filter_map(|x| x.as_str())
                    .map(|s| json!(s))
                    .collect();
                if !arr.is_empty() {
                    spec.insert("args".into(), Value::Array(arr));
                }
            }
            if let Some(cwd) = entry.get("cwd").and_then(|v| v.as_str()) {
                if !cwd.trim().is_empty() {
                    spec.insert("cwd".into(), json!(cwd));
                }
            }
            if let Some(env_tbl) = entry.get("env").and_then(|v| v.as_table()) {
                let mut env_json = serde_json::Map::new();
                for (k, v) in env_tbl.iter() {
                    if let Some(sv) = v.as_str() {
                        env_json.insert(k.clone(), json!(sv));
                    }
                }
                if !env_json.is_empty() {
                    spec.insert("env".into(), Value::Object(env_json));
                }
            }
        }
        "http" | "sse" => {
            if let Some(url) = entry.get("url").and_then(|v| v.as_str()) {
                spec.insert("url".into(), json!(url));
            }
            // Check http_headers or headers
            let headers_tbl = entry
                .get("http_headers")
                .and_then(|v| v.as_table())
                .or_else(|| entry.get("headers").and_then(|v| v.as_table()));

            if let Some(headers_tbl) = headers_tbl {
                let mut headers_json = serde_json::Map::new();
                for (k, v) in headers_tbl.iter() {
                    if let Some(sv) = v.as_str() {
                        headers_json.insert(k.clone(), json!(sv));
                    }
                }
                if !headers_json.is_empty() {
                    spec.insert("headers".into(), Value::Object(headers_json));
                }
            }
        }
        _ => {}
    }

    Value::Object(spec)
}

/// Read MCP servers from Gemini configuration
pub async fn load_mcp_servers_from_gemini() -> Result<HashMap<String, Value>> {
    let Some(path) = gemini_settings_path() else {
        return Ok(HashMap::new());
    };

    if !path.exists() {
        return Ok(HashMap::new());
    }

    let root = read_json_file(&path)?;
    let servers = root
        .get("mcpServers")
        .and_then(|v| v.as_object())
        .map(|obj| {
            obj.iter()
                .map(|(k, v)| {
                    // Convert Gemini-specific format back to standard
                    let mut spec = v.clone();
                    if let Some(spec_obj) = spec.as_object_mut() {
                        // Gemini uses httpUrl for HTTP servers
                        if let Some(http_url) = spec_obj.remove("httpUrl") {
                            spec_obj.insert("url".to_string(), http_url);
                            spec_obj.insert("type".to_string(), json!("http"));
                        } else if spec_obj.contains_key("url") {
                            // SSE type uses "url" directly
                            spec_obj.insert("type".to_string(), json!("sse"));
                        } else if spec_obj.contains_key("command") {
                            // stdio type
                            spec_obj.insert("type".to_string(), json!("stdio"));
                        }
                    }
                    (k.clone(), spec)
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(servers)
}

// ============================================================================
// Gemini MCP Sync
// ============================================================================

/// Sync MCP servers to Gemini configuration (~/.gemini/settings.json)
pub async fn sync_mcp_to_gemini(servers: &IndexMap<McpServerId, McpServer>) -> Result<()> {
    if !should_sync_gemini() {
        log::debug!("Gemini not installed, skipping MCP sync");
        return Ok(());
    }

    let Some(path) = gemini_settings_path() else {
        return Ok(());
    };

    // Read existing config
    let mut root = read_json_file(&path)?;

    // Build mcpServers object from servers with gemini=true
    let mut mcp_servers: Map<String, Value> = Map::new();
    for (id, server) in servers.iter() {
        if server.apps.gemini {
            let mut spec = extract_server_spec(server);

            // Gemini-specific format conversion
            if let Some(obj) = spec.as_object_mut() {
                // Gemini uses httpUrl for HTTP, url for SSE
                let transport_type = obj.get("type").and_then(|v| v.as_str());
                if transport_type == Some("http") {
                    if let Some(url_value) = obj.remove("url") {
                        obj.insert("httpUrl".to_string(), url_value);
                    }
                }
                // Remove type field (Gemini infers from field names)
                obj.remove("type");
            }

            mcp_servers.insert(id.clone(), spec);
        }
    }

    // Update config
    if let Some(obj) = root.as_object_mut() {
        obj.insert("mcpServers".into(), Value::Object(mcp_servers));
    }

    // Write atomically
    write_json_file(&path, &root)?;

    log::info!("Synced MCP servers to Gemini");
    Ok(())
}

/// Sync MCP servers to OpenCode configuration
pub async fn sync_mcp_to_opencode(servers: &IndexMap<McpServerId, McpServer>) -> Result<()> {
    let Some(path) = opencode_mcp_path() else {
        return Ok(());
    };

    // Read existing config
    let mut root = read_json_file(&path)?;

    // Build mcpServers object from servers with opencode=true
    let mut mcp_servers: Map<String, Value> = Map::new();
    for (id, server) in servers.iter() {
        if server.apps.opencode {
            let mut spec = extract_server_spec(server);
            if let Some(obj) = spec.as_object_mut() {
                wrap_command_for_windows(obj);
            }
            mcp_servers.insert(id.clone(), spec);
        }
    }

    // Update config
    if let Some(obj) = root.as_object_mut() {
        obj.insert("mcpServers".into(), Value::Object(mcp_servers));
    }

    // Write atomically
    write_json_file(&path, &root)?;

    log::info!("Synced MCP servers to OpenCode");
    Ok(())
}

// ============================================================================
// Skills Sync
// ============================================================================

/// Skills storage directory (~/.cc-switch/skills/ or similar)
fn get_skills_ssot_dir() -> Option<PathBuf> {
    // For Zed, we'll use a local storage path
    // This can be configured via settings
    get_home_dir().map(|home| home.join(".cc-switch").join("skills"))
}

fn skill_directory_name(directory: &str) -> Option<String> {
    let directory = directory.trim();
    if directory.is_empty() {
        return None;
    }

    let path = Path::new(directory);
    if path.is_absolute() {
        path.file_name()
            .and_then(|name| name.to_str())
            .map(|name| name.to_string())
    } else {
        Some(directory.to_string())
    }
}

fn skill_source_path(directory: &str, ssot_dir: &Path) -> PathBuf {
    let path = Path::new(directory);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        ssot_dir.join(directory)
    }
}

/// Install skill files (git clone or copy)
pub async fn install_skill_files(skill: &InstalledSkill, fs: Arc<dyn Fs>) -> Result<()> {
    let Some(ssot_dir) = get_skills_ssot_dir() else {
        return Ok(());
    };

    let target_dir = ssot_dir.join(&skill.directory);

    // If target exists, we might want to update or error.
    // For now, if it exists, we assume it's installed.
    if target_dir.exists() {
        // TODO: Implement update logic (git pull)
        log::info!("Skill directory already exists: {:?}", target_dir);
        return Ok(());
    }

    fs.create_dir(&ssot_dir).await.ok();

    if skill.is_from_repo() {
        let owner = skill.repo_owner.as_deref().unwrap_or("unknown");
        let repo = skill.repo_name.as_deref().unwrap_or("unknown");
        let url = format!("https://github.com/{}/{}.git", owner, repo);

        log::info!("Cloning skill from {} to {:?}", url, target_dir);

        fs.git_clone(&url, &target_dir).await.context("Failed to execute git clone")?;
    } else {
        // Local skill: check if path exists
        if Path::new(&skill.directory).is_absolute() {
             if !Path::new(&skill.directory).exists() {
                 anyhow::bail!("Local skill path does not exist: {}", skill.directory);
             }
        }
    }

    Ok(())
}

/// Sync skills to Claude commands directory
pub async fn sync_skills_to_claude(skills: &IndexMap<SkillId, InstalledSkill>) -> Result<()> {
    let Some(skills_dir) = claude_skills_dir() else {
        return Ok(());
    };

    let Some(ssot_dir) = get_skills_ssot_dir() else {
        return Ok(());
    };

    // Create skills directory if needed
    fs::create_dir_all(&skills_dir).context("Failed to create Claude skills directory")?;

    // Get list of currently synced skills (managed by us)
    let managed_skills: Vec<_> = skills.iter().filter(|(_, s)| s.apps.claude).collect();

    // Copy each enabled skill
    for (_, skill) in managed_skills {
        let Some(dest_name) = skill_directory_name(&skill.directory) else {
            continue;
        };
        let source = skill_source_path(&skill.directory, &ssot_dir);
        let dest = skills_dir.join(&dest_name);

        if source.exists() {
            if source == dest {
                continue;
            }
            // Remove existing if present
            if dest.exists() {
                fs::remove_dir_all(&dest).with_context(|| {
                    format!("Failed to remove existing skill directory {:?}", dest)
                })?;
            }
            copy_dir_recursive(&source, &dest)?;
            log::debug!("Synced skill {} to Claude", skill.name);
        }
    }

    log::info!("Synced skills to Claude");
    Ok(())
}

/// Remove a skill from an app's commands directory
pub fn remove_skill_from_app(directory: &str, app: &AppType) -> Result<()> {
    let Some(app_dir) = get_app_skills_dir(app) else {
        return Ok(());
    };

    let Some(directory_name) = skill_directory_name(directory) else {
        return Ok(());
    };
    let skill_path = app_dir.join(directory_name);
    if skill_path.exists() {
        fs::remove_dir_all(&skill_path).context("Failed to remove skill directory")?;
        log::debug!("Removed skill {} from {:?}", directory, app);
    }

    Ok(())
}

/// Copy a skill to an app's commands directory
pub fn copy_skill_to_app(directory: &str, app: &AppType) -> Result<()> {
    let Some(ssot_dir) = get_skills_ssot_dir() else {
        return Ok(());
    };

    let Some(app_dir) = get_app_skills_dir(app) else {
        return Ok(());
    };

    let source = ssot_dir.join(directory);
    if !source.exists() {
        return Err(anyhow::anyhow!("Skill not found in SSOT: {}", directory));
    }

    fs::create_dir_all(&app_dir).context("Failed to create app skills directory")?;

    let dest = app_dir.join(directory);
    if dest.exists() {
        fs::remove_dir_all(&dest).ok();
    }

    copy_dir_recursive(&source, &dest)?;
    log::debug!("Copied skill {} to {:?}", directory, app);

    Ok(())
}

/// Recursive directory copy
fn copy_dir_recursive(src: &Path, dest: &Path) -> Result<()> {
    fs::create_dir_all(dest).context("Failed to create destination directory")?;

    for entry in fs::read_dir(src).context("Failed to read source directory")? {
        let entry = entry?;
        let path = entry.path();
        let dest_path = dest.join(entry.file_name());

        if path.is_dir() {
            copy_dir_recursive(&path, &dest_path)?;
        } else {
            fs::copy(&path, &dest_path).context("Failed to copy file")?;
        }
    }

    Ok(())
}

// ============================================================================
// Provider Sync
// ============================================================================

#[derive(Clone, Debug, Default)]
struct ProviderSettings {
    api_key: Option<String>,
    api_url: Option<String>,
}

impl ProviderSettings {
    fn from_provider(provider: &Provider) -> Self {
        Self {
            api_key: read_provider_setting(&provider.settings_config, "api_key"),
            api_url: read_provider_setting(&provider.settings_config, "api_url"),
        }
    }
}

fn read_provider_setting(settings: &Value, key: &str) -> Option<String> {
    settings
        .get(key)
        .and_then(|value| value.as_str())
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

fn upsert_json_string(obj: &mut Map<String, Value>, key: &str, value: Option<&str>) {
    match value {
        Some(value) => {
            obj.insert(key.to_string(), Value::String(value.to_string()));
        }
        None => {
            obj.remove(key);
        }
    }
}

fn upsert_json_prefer_existing(obj: &mut Map<String, Value>, keys: &[&str], value: Option<&str>) {
    let mut updated = false;
    for key in keys {
        if obj.contains_key(*key) {
            upsert_json_string(obj, key, value);
            updated = true;
        }
    }

    if !updated {
        if let Some(value) = value {
            obj.insert(keys[0].to_string(), Value::String(value.to_string()));
        }
    }
}

fn apply_provider_settings_json(
    root: &mut Value,
    provider: &Provider,
    settings: &ProviderSettings,
) -> Result<()> {
    let obj = root
        .as_object_mut()
        .context("Expected JSON object for provider settings")?;

    let mut cc_switch_provider = obj
        .remove("ccSwitchProvider")
        .unwrap_or_else(|| json!({}));
    if let Some(cc_obj) = cc_switch_provider.as_object_mut() {
        cc_obj.insert("id".to_string(), Value::String(provider.id.clone()));
        cc_obj.insert("name".to_string(), Value::String(provider.name.clone()));
        upsert_json_string(cc_obj, "apiKey", settings.api_key.as_deref());
        upsert_json_string(cc_obj, "apiUrl", settings.api_url.as_deref());
    }
    obj.insert("ccSwitchProvider".to_string(), cc_switch_provider);

    upsert_json_prefer_existing(obj, &["apiKey", "api_key"], settings.api_key.as_deref());
    upsert_json_prefer_existing(
        obj,
        &["apiUrl", "api_url", "apiBaseUrl", "baseUrl"],
        settings.api_url.as_deref(),
    );

    Ok(())
}

fn upsert_toml_string(table: &mut toml_edit::Table, key: &str, value: Option<&str>) {
    match value {
        Some(value) => {
            table[key] = toml_edit::value(value);
        }
        None => {
            table.remove(key);
        }
    }
}

fn apply_provider_settings_toml(
    doc: &mut toml_edit::DocumentMut,
    provider: &Provider,
    settings: &ProviderSettings,
) {
    let root = doc.as_table_mut();
    upsert_toml_string(root, "api_key", settings.api_key.as_deref());
    upsert_toml_string(root, "api_url", settings.api_url.as_deref());

    if let Some(openai_table) = root.get_mut("openai").and_then(|item| item.as_table_mut()) {
        upsert_toml_string(openai_table, "api_key", settings.api_key.as_deref());
        upsert_toml_string(openai_table, "api_url", settings.api_url.as_deref());
    }

    let mut cc_switch = toml_edit::Table::new();
    cc_switch["id"] = toml_edit::value(provider.id.clone());
    cc_switch["name"] = toml_edit::value(provider.name.clone());
    if let Some(api_key) = settings.api_key.as_deref() {
        cc_switch["api_key"] = toml_edit::value(api_key);
    }
    if let Some(api_url) = settings.api_url.as_deref() {
        cc_switch["api_url"] = toml_edit::value(api_url);
    }
    root["cc_switch"] = toml_edit::Item::Table(cc_switch);
}

/// Sync provider configuration to an app
pub async fn sync_provider_to_app(provider: &Provider, app: &AppType) -> Result<()> {
    let settings = ProviderSettings::from_provider(provider);

    match app {
        AppType::Claude => {
            if !should_sync_claude() {
                return Ok(());
            }
            let Some(path) = claude_mcp_path() else {
                return Ok(());
            };
            let mut root = read_json_file(&path)?;
            apply_provider_settings_json(&mut root, provider, &settings)?;
            write_json_file(&path, &root)?;
        }
        AppType::Codex => {
            if !should_sync_codex() {
                return Ok(());
            }
            let Some(path) = codex_config_path() else {
                return Ok(());
            };

            let base_text = if path.exists() {
                fs::read_to_string(&path).unwrap_or_default()
            } else {
                String::new()
            };

            let mut doc = if base_text.trim().is_empty() {
                toml_edit::DocumentMut::default()
            } else {
                base_text
                    .parse::<toml_edit::DocumentMut>()
                    .context("Failed to parse config.toml")?
            };

            apply_provider_settings_toml(&mut doc, provider, &settings);
            atomic_write(&path, doc.to_string().as_bytes())?;
        }
        AppType::Gemini => {
            if !should_sync_gemini() {
                return Ok(());
            }
            let Some(path) = gemini_settings_path() else {
                return Ok(());
            };
            let mut root = read_json_file(&path)?;
            apply_provider_settings_json(&mut root, provider, &settings)?;
            write_json_file(&path, &root)?;
        }
        AppType::OpenCode => {
            if !should_sync_opencode() {
                return Ok(());
            }
            let Some(path) = opencode_settings_path() else {
                return Ok(());
            };
            let mut root = read_json_file(&path)?;
            apply_provider_settings_json(&mut root, provider, &settings)?;
            write_json_file(&path, &root)?;
        }
    }
    Ok(())
}

// ============================================================================
// Unified Sync Functions
// ============================================================================

/// Sync all MCP servers to all enabled apps
pub async fn sync_all_mcp_servers(servers: &IndexMap<McpServerId, McpServer>) -> Result<()> {
    // Sync to each app in parallel-ish (they're independent)
    let claude_result = sync_mcp_to_claude(servers).await;
    let codex_result = sync_mcp_to_codex(servers).await;
    let gemini_result = sync_mcp_to_gemini(servers).await;
    let opencode_result = sync_mcp_to_opencode(servers).await;

    // Log any errors but don't fail the whole operation
    if let Err(e) = claude_result {
        log::error!("Failed to sync MCP to Claude: {}", e);
    }
    if let Err(e) = codex_result {
        log::error!("Failed to sync MCP to Codex: {}", e);
    }
    if let Err(e) = gemini_result {
        log::error!("Failed to sync MCP to Gemini: {}", e);
    }
    if let Err(e) = opencode_result {
        log::error!("Failed to sync MCP to OpenCode: {}", e);
    }

    Ok(())
}

/// Sync all skills to all enabled apps
pub async fn sync_all_skills(skills: &IndexMap<SkillId, InstalledSkill>) -> Result<()> {
    // For now, only Claude supports skills
    let claude_result = sync_skills_to_claude(skills).await;

    if let Err(e) = claude_result {
        log::error!("Failed to sync skills to Claude: {}", e);
    }

    Ok(())
}

// ============================================================================
// Legacy API Compatibility
// ============================================================================

/// Sync providers to Claude Code configuration (legacy)
pub async fn sync_providers_to_claude(providers: &[Provider]) -> Result<()> {
    if let Some(provider) = providers.first() {
        sync_provider_to_app(provider, &AppType::Claude).await?;
    }
    Ok(())
}

/// Sync MCP servers to Claude Code configuration (legacy)
pub async fn sync_mcp_servers_to_claude(servers: &[McpServer]) -> Result<()> {
    let map: IndexMap<McpServerId, McpServer> =
        servers.iter().map(|s| (s.id.clone(), s.clone())).collect();
    sync_mcp_to_claude(&map).await
}

/// Sync skills to Claude Code configuration (legacy)
pub async fn sync_skills_to_claude_legacy(skills: &[InstalledSkill]) -> Result<()> {
    let map: IndexMap<SkillId, InstalledSkill> =
        skills.iter().map(|s| (s.id.clone(), s.clone())).collect();
    sync_skills_to_claude(&map).await
}

/// Load providers from Claude Code configuration (legacy)
pub async fn load_providers_from_claude() -> Result<Vec<Provider>> {
    // Provider loading from Claude is not typically needed
    Ok(Vec::new())
}

/// Load skills from Claude Code configuration (legacy)
pub async fn load_skills_from_claude() -> Result<Vec<InstalledSkill>> {
    let Some(skills_dir) = claude_skills_dir() else {
        return Ok(Vec::new());
    };

    if !skills_dir.exists() {
        return Ok(Vec::new());
    }

    let mut skills = Vec::new();
    for entry in fs::read_dir(&skills_dir).context("Failed to read Claude skills directory")? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        let Some(name) = entry.file_name().to_str().map(|name| name.to_string()) else {
            continue;
        };

        let mut skill = InstalledSkill::new_local(
            format!("local:{}", name),
            name.clone(),
            path.to_string_lossy().to_string(),
        );
        skill.apps.set_enabled_for(&AppType::Claude, true);
        skills.push(skill);
    }

    Ok(skills)
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::sync::{LazyLock, Mutex};
    use tempfile::TempDir;

    static HOME_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));

    struct HomeGuard {
        previous: Option<PathBuf>,
    }

    impl Drop for HomeGuard {
        fn drop(&mut self) {
            let mut guard = super::TEST_HOME_DIR
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            *guard = self.previous.take();
        }
    }

    fn set_temp_home() -> (TempDir, HomeGuard) {
        let temp_dir = tempfile::tempdir().expect("tempdir");
        let home_path = temp_dir.path().to_path_buf();
        let mut guard = super::TEST_HOME_DIR
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        let home_guard = HomeGuard {
            previous: guard.clone(),
        };
        *guard = Some(home_path);
        (temp_dir, home_guard)
    }

    #[test]
    fn test_extract_server_spec() {
        let server = McpServer::new(
            "test-server",
            "Test Server",
            json!({
                "type": "stdio",
                "command": "npx",
                "args": ["-y", "@test/mcp-server"],
                "enabled": true,
                "source": "imported"
            }),
        );

        let spec = extract_server_spec(&server);

        assert!(spec.get("type").is_some());
        assert!(spec.get("command").is_some());
        assert!(spec.get("args").is_some());
        assert!(spec.get("enabled").is_none());
        assert!(spec.get("source").is_none());
    }

    #[test]
    fn test_toml_entry_to_json_spec_stdio() {
        let mut entry = toml::Table::new();
        entry.insert("type".to_string(), toml::Value::String("stdio".to_string()));
        entry.insert(
            "command".to_string(),
            toml::Value::String("npx".to_string()),
        );
        entry.insert(
            "args".to_string(),
            toml::Value::Array(vec![
                toml::Value::String("-y".to_string()),
                toml::Value::String("@test/server".to_string()),
            ]),
        );

        let spec = toml_entry_to_json_spec(&entry);

        assert_eq!(spec.get("type").and_then(|v| v.as_str()), Some("stdio"));
        assert_eq!(spec.get("command").and_then(|v| v.as_str()), Some("npx"));
        assert!(spec.get("args").and_then(|v| v.as_array()).is_some());
    }

    #[test]
    fn test_toml_entry_to_json_spec_http() {
        let mut entry = toml::Table::new();
        entry.insert("type".to_string(), toml::Value::String("http".to_string()));
        entry.insert(
            "url".to_string(),
            toml::Value::String("https://example.com/mcp".to_string()),
        );

        let spec = toml_entry_to_json_spec(&entry);

        assert_eq!(spec.get("type").and_then(|v| v.as_str()), Some("http"));
        assert_eq!(
            spec.get("url").and_then(|v| v.as_str()),
            Some("https://example.com/mcp")
        );
    }

    #[cfg(windows)]
    #[test]
    fn test_wrap_command_for_windows_npx() {
        let mut obj = json!({"command": "npx", "args": ["-y", "@test/mcp"]})
            .as_object()
            .unwrap()
            .clone();

        wrap_command_for_windows(&mut obj);

        assert_eq!(obj["command"], "cmd");
        assert_eq!(obj["args"], json!(["/c", "npx", "-y", "@test/mcp"]));
    }

    #[cfg(windows)]
    #[test]
    fn test_wrap_command_for_windows_already_cmd() {
        let mut obj = json!({"command": "cmd", "args": ["/c", "npx", "-y", "foo"]})
            .as_object()
            .unwrap()
            .clone();

        wrap_command_for_windows(&mut obj);

        // Should not double-wrap
        assert_eq!(obj["command"], "cmd");
        assert_eq!(obj["args"], json!(["/c", "npx", "-y", "foo"]));
    }

    #[test]
    fn test_sync_skills_to_claude_with_absolute_source() {
        let _lock = HOME_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let (temp_dir, _guard) = set_temp_home();

        let source_dir = temp_dir.path().join("local-skill");
        fs::create_dir_all(&source_dir).expect("create source dir");
        fs::write(source_dir.join("skill.json"), "{}").expect("write skill file");

        let mut skill = InstalledSkill::new_local(
            "local:local-skill",
            "Local Skill",
            source_dir.to_string_lossy().to_string(),
        );
        skill.apps.set_enabled_for(&AppType::Claude, true);

        let mut skills = IndexMap::new();
        skills.insert(skill.id.clone(), skill);

        futures::executor::block_on(sync_skills_to_claude(&skills)).expect("sync skills");

        let dest_dir = claude_skills_dir().expect("claude skills dir").join("local-skill");
        assert!(dest_dir.exists());
        assert!(source_dir.exists());
    }

    #[test]
    fn test_remove_skill_from_app_with_absolute_directory() {
        let _lock = HOME_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let (temp_dir, _guard) = set_temp_home();

        let source_dir = temp_dir.path().join("external-skill");
        fs::create_dir_all(&source_dir).expect("create source dir");

        let dest_dir = claude_skills_dir()
            .expect("claude skills dir")
            .join("external-skill");
        fs::create_dir_all(&dest_dir).expect("create dest dir");

        let source_dir_str = source_dir.to_string_lossy().to_string();
        remove_skill_from_app(&source_dir_str, &AppType::Claude).expect("remove skill");

        assert!(!dest_dir.exists());
        assert!(source_dir.exists());
    }

    #[test]
    fn test_load_skills_from_claude_reads_directories() {
        let _lock = HOME_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        let (_temp_dir, _guard) = set_temp_home();

        let skills_dir = claude_skills_dir().expect("claude skills dir");
        let skill_path = skills_dir.join("sample-skill");
        fs::create_dir_all(&skill_path).expect("create skill dir");

        let skills = futures::executor::block_on(load_skills_from_claude())
            .expect("load skills");
        assert_eq!(skills.len(), 1);
        assert!(skills[0].apps.claude);
        assert!(Path::new(&skills[0].directory).is_absolute());
    }
}
