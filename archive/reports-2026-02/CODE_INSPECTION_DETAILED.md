# 代码质量详细巡检报告
**扫描时间**: 2026-02-01 22:20:30 (GMT+8)
**扫描路径**: /mnt/d/ai软件/zed/crates

## cc_switch crate

### 基本统计
- 总行数: 5590
- 源文件数: 14

### 未使用的 imports (29 个)
- src/api_client.rs:5 - `anyhow::{anyhow, Context, Result}`
- src/api_client.rs:8 - `futures::AsyncReadExt`
- src/api_client.rs:10 - `http_client::{AsyncBody, HttpClient, Method, Request, StatusCode}`
- src/api_client.rs:12 - `rand::Rng`
- src/api_client.rs:13 - `sha2::{Digest, Sha256}`
- src/api_client.rs:17 - `tiny_http::{Response, Server}`
- src/api_client.rs:20 - `crate::{AppType, Provider}`
- src/cc_switch.rs:47 - `settings::Settings`
- src/cc_switch_panel.rs:5 - `crate::views::{McpView, ProvidersView, SkillsView}`
- src/cc_switch_panel.rs:6 - `crate::{AppType, CcSwitchConfig, CcSwitchSettings, McpServerId, PanelTab, ProviderId, SkillId}`
- ... 还有 19 个

### TODO/FIXME (1 个)
- src/config_sync.rs:763 - // TODO: Implement update logic (git pull)

### 注释代码块 (1 个)
- src/cc_switch_panel.rs:3 - //! Implements the Panel trait for the left sidebar....

### unwrap/expect 调用 (36 个)
- 检测到 36 个 unwrap/expect 调用

### 调试宏 (0 个)
✅ 无调试宏

### unsafe 块 (0 个)
✅ 无 unsafe 块

## multi_model_dispatch crate

### 基本统计
- 总行数: 565
- 源文件数: 8

### 未使用的 imports (11 个)
- src/dispatcher.rs:3 - `gpui::{App, AsyncApp, Task}`
- src/dispatcher.rs:4 - `language_model::{LanguageModel, LanguageModelRegistry}`
- src/dispatcher.rs:5 - `crate::agent::{Agent, AgentRole}`
- src/multi_model_dispatch.rs:7 - `ui::{Divider, DividerColor}`
- src/multi_model_dispatch.rs:13 - `std::sync::Arc`
- src/settings.rs:1 - `gpui::{App, Pixels}`
- src/settings.rs:3 - `serde::{Deserialize, Serialize}`
- src/agent/agent.rs:2 - `anyhow::{Result, anyhow}`
- src/agent/agent.rs:4 - `language_model::{LanguageModel, LanguageModelRequest, LanguageModelCompletionEvent, Role, MessageContent}`
- src/agent/agent.rs:5 - `futures::StreamExt`
- ... 还有 1 个

### TODO/FIXME (1 个)
- src/multi_model_dispatch.rs:201 - // TODO: Display plan somewhere? For now just log/notify.

### 注释代码块 (2 个)
- src/settings.rs:28 - // For now, return default as we haven't added this to the m...
- src/settings.rs:33 - // but to satisfy the trait we must implement this....

### unwrap/expect 调用 (0 个)
✅ 无 unwrap/expect 调用

### 调试宏 (0 个)
✅ 无调试宏

### unsafe 块 (0 个)
✅ 无 unsafe 块

