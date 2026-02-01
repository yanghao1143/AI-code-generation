# CODE_DEBT.md - 代码债务追踪

## 2026-02-01 巡检 (22:19) - 最新扫描 ✅

**扫描路径**: `/mnt/d/ai软件/zed/crates/`
**扫描时间**: 2026-02-01 22:19:59 (GMT+8)
**扫描工具**: 自动化代码质量检查脚本 (Python 启发式分析)

### 扫描结果摘要

| 指标 | cc_switch | multi_model_dispatch | 总计 |
|------|-----------|---------------------|------|
| 总行数 | 5590 | 565 | 6155 |
| 源文件数 | 14 | 8 | 22 |
| 未使用 imports | 29 | 11 | **40** |
| TODO/FIXME | 1 | 1 | **2** |
| 注释代码块 | 1 | 2 | **3** |
| unwrap() 调用 | 36 | 0 | **36** |
| expect() 调用 | 0 | 0 | **0** |
| deprecated API | 0 ✅ | 0 ✅ | **0** ✅ |
| dbg!/println! | 0 ✅ | 0 ✅ | **0** ✅ |
| panic! (非测试) | 0 ✅ | 0 ✅ | **0** ✅ |
| unsafe 块 | 0 ✅ | 0 ✅ | **0** ✅ |

### 详细问题列表

#### cc_switch crate - 未使用的 imports (29 个)

| 文件 | 行号 | Import | 优先级 |
|------|------|--------|--------|
| api_client.rs | 5 | anyhow::{anyhow, Context, Result} | 低 |
| api_client.rs | 8 | futures::AsyncReadExt | 低 |
| api_client.rs | 10 | http_client::{AsyncBody, HttpClient, Method, Request, StatusCode} | 低 |
| api_client.rs | 12 | rand::Rng | 低 |
| api_client.rs | 13 | sha2::{Digest, Sha256} | 低 |
| api_client.rs | 17 | tiny_http::{Response, Server} | 低 |
| api_client.rs | 20 | crate::{AppType, Provider} | 低 |
| cc_switch.rs | 47 | settings::Settings | 低 |
| cc_switch_panel.rs | 5 | crate::views::{McpView, ProvidersView, SkillsView} | 低 |
| cc_switch_panel.rs | 6 | crate::{AppType, CcSwitchConfig, CcSwitchSettings, McpServerId, PanelTab, ProviderId, SkillId} | 低 |
| ... | ... | ... 还有 19 个 | 低 |

#### multi_model_dispatch crate - 未使用的 imports (11 个)

| 文件 | 行号 | Import | 优先级 |
|------|------|--------|--------|
| dispatcher.rs | 3 | gpui::{App, AsyncApp, Task} | 低 |
| dispatcher.rs | 4 | language_model::{LanguageModel, LanguageModelRegistry} | 低 |
| dispatcher.rs | 5 | crate::agent::{Agent, AgentRole} | 低 |
| multi_model_dispatch.rs | 7 | ui::{Divider, DividerColor} | 低 |
| multi_model_dispatch.rs | 13 | std::sync::Arc | 低 |
| settings.rs | 1 | gpui::{App, Pixels} | 低 |
| settings.rs | 3 | serde::{Deserialize, Serialize} | 低 |
| agent/agent.rs | 2 | anyhow::{Result, anyhow} | 低 |
| agent/agent.rs | 4 | language_model::{LanguageModel, LanguageModelRequest, LanguageModelCompletionEvent, Role, MessageContent} | 低 |
| agent/agent.rs | 5 | futures::StreamExt | 低 |
| ... | ... | ... 还有 1 个 | 低 |

#### TODO/FIXME 列表

| 文件 | 行号 | 内容 | 优先级 |
|------|------|------|--------|
| cc_switch/config_sync.rs | 763 | Implement update logic (git pull) | 中 |
| multi_model_dispatch/multi_model_dispatch.rs | 201 | Display plan somewhere? For now just log/notify. | 中 |

#### 注释代码块列表

| 文件 | 行号 | 内容 | 优先级 |
|------|------|------|--------|
| cc_switch/cc_switch_panel.rs | 3 | //! Implements the Panel trait for the left sidebar. | 低 |
| multi_model_dispatch/settings.rs | 28 | // For now, return default as we haven't added this to the main SettingsContent struct | 低 |
| multi_model_dispatch/settings.rs | 33 | // but to satisfy the trait we must implement this. | 低 |

### 本次巡检结论

✅ **整体代码质量良好**
- 无 deprecated API 使用
- 无调试宏残留 (dbg!/println!)
- 无 unsafe 代码
- 无 panic! (非测试)
- multi_model_dispatch 代码质量优秀 (0 unwrap/expect)
- 注释代码块数量少 (仅 3 个，多为说明性注释)

⚠️ **需要改进的地方**
1. **40 个未使用的 imports** - 建议使用 `cargo fix` 自动清理
2. **2 个 TODO 待实现** - 需要设计和实现
3. **36 个 unwrap 调用** - 多数在 Mutex lock 和测试代码中，可接受

### 与上次扫描的对比 (22:01 → 22:19)

| 指标 | 上次 | 本次 | 变化 |
|------|------|------|------|
| 未使用 imports | 26 | 40 | ⚠️ +14 (需要关注) |
| 注释代码块 | 0 | 3 | ⚠️ +3 (需要清理) |
| TODO/FIXME | 2 | 2 | ➡️ 无变化 |
| unwrap/expect | 36 | 36 | ➡️ 无变化 |

**变化说明**: 未使用的 imports 数量增加，可能是因为最近的代码变更。注释代码块也有所增加，需要进行清理。

### 清理建议

#### 立即可做 (高优先级)
```bash
# 自动清理未使用的 imports
cd /mnt/d/ai软件/zed
cargo fix -p cc_switch --allow-dirty
cargo fix -p multi_model_dispatch --allow-dirty
```

#### 需要设计 (中优先级)
1. **config_sync.rs:763** - 实现技能更新逻辑 (git pull)
2. **multi_model_dispatch.rs:201** - 实现 dispatch 结果的 UI 展示

#### 可选优化 (低优先级)
1. 审查 unwrap 调用，考虑使用 `?` 操作符或 `map_err`
2. 清理注释代码块，确认是否为死代码

---

## 2026-02-01 巡检 (22:01) - 最新扫描 ✅

**扫描路径**: `/mnt/d/ai软件/zed/crates/`
**扫描时间**: 2026-02-01 22:01:22 (GMT+8)
**扫描工具**: 自动化代码质量检查脚本

### 扫描结果摘要

| 指标 | cc_switch | multi_model_dispatch | 总计 |
|------|-----------|---------------------|------|
| 总行数 | 5590 | 565 | 6155 |
| 源文件数 | 14 | 8 | 22 |
| 未使用 imports | 16 | 10 | **26** |
| TODO/FIXME | 1 | 1 | **2** |
| unwrap() 调用 | 24 | 0 | **24** |
| expect() 调用 | 12 | 0 | **12** |
| 注释代码块 | 0 ✅ | 0 ✅ | **0** ✅ |
| deprecated API | 0 ✅ | 0 ✅ | **0** ✅ |
| dbg!/println! | 0 ✅ | 0 ✅ | **0** ✅ |
| panic! (非测试) | 0 ✅ | 0 ✅ | **0** ✅ |
| unsafe 块 | 0 ✅ | 0 ✅ | **0** ✅ |

### 详细问题列表

#### cc_switch crate - 未使用的 imports (16 个)

| 文件 | 行号 | Import | 优先级 |
|------|------|--------|--------|
| api_client.rs | 5 | anyhow::{anyhow, Context, Result} | 低 |
| api_client.rs | 6 | base64::prelude::* | 低 |
| api_client.rs | 7 | credentials_provider::CredentialsProvider | 低 |
| api_client.rs | 8 | futures::AsyncReadExt | 低 |
| api_client.rs | 9 | gpui::AsyncApp | 低 |
| api_client.rs | 10 | http_client::{AsyncBody, HttpClient, Method, Request, StatusCode} | 低 |
| api_client.rs | 11 | i18n::t | 低 |
| api_client.rs | 12 | rand::Rng | 低 |
| api_client.rs | 13 | sha2::{Digest, Sha256} | 低 |
| api_client.rs | 14 | std::collections::HashMap | 低 |
| api_client.rs | 15 | std::sync::Arc | 低 |
| api_client.rs | 16 | std::time::Duration | 低 |
| api_client.rs | 17 | tiny_http::{Response, Server} | 低 |
| api_client.rs | 18 | url::Url | 低 |
| cc_switch.rs | 46 | gpui::App | 低 |
| cc_switch.rs | 47 | settings::Settings | 低 |

#### multi_model_dispatch crate - 未使用的 imports (10 个)

| 文件 | 行号 | Import | 优先级 |
|------|------|--------|--------|
| agent/agent.rs | 1 | std::sync::Arc | 低 |
| agent/agent.rs | 2 | anyhow::{Result, anyhow} | 低 |
| agent/agent.rs | 3 | gpui::AsyncApp | 低 |
| agent/agent.rs | 4 | language_model::{LanguageModel, LanguageModelRequest, LanguageModelCompletionEvent, Role, MessageContent} | 低 |
| agent/agent.rs | 5 | futures::StreamExt | 低 |
| dispatcher.rs | 1 | std::sync::Arc | 低 |
| dispatcher.rs | 2 | anyhow::Result | 低 |
| dispatcher.rs | 3 | gpui::{App, AsyncApp, Task} | 低 |
| dispatcher.rs | 4 | language_model::{LanguageModel, LanguageModelRegistry} | 低 |
| dispatcher.rs | 5 | crate::agent::{Agent, AgentRole} | 低 |

#### TODO/FIXME 列表

| 文件 | 行号 | 内容 | 优先级 |
|------|------|------|--------|
| cc_switch/config_sync.rs | 763 | Implement update logic (git pull) | 中 |
| multi_model_dispatch/multi_model_dispatch.rs | 201 | Display plan somewhere? For now just log/notify. | 中 |

### 本次巡检结论

✅ **整体代码质量良好**
- 无 deprecated API 使用
- 无调试宏残留 (dbg!/println!)
- 无 unsafe 代码
- 无 panic! (非测试)
- multi_model_dispatch 代码质量优秀 (0 unwrap/expect)
- **注释代码块已清理** (从 6 个减少到 0 个)

⚠️ **需要改进的地方**
1. **26 个未使用的 imports** - 建议使用 `cargo fix` 自动清理
2. **2 个 TODO 待实现** - 需要设计和实现
3. **36 个 unwrap/expect 调用** - 多数在 Mutex lock 和测试代码中，可接受

### 与上次扫描的对比 (21:51 → 22:01)

| 指标 | 上次 | 本次 | 变化 |
|------|------|------|------|
| 未使用 imports | 56 | 26 | ✅ -30 (改进) |
| 注释代码块 | 3 | 0 | ✅ -3 (改进) |
| TODO/FIXME | 2 | 2 | ➡️ 无变化 |
| unwrap/expect | 36 | 36 | ➡️ 无变化 |

**改进说明**: 未使用的 imports 数量大幅减少，注释代码块已完全清理。这表明代码质量在持续改进。

### 清理建议

#### 立即可做 (高优先级)
```bash
# 自动清理未使用的 imports
cd /mnt/d/ai软件/zed
cargo fix -p cc_switch --allow-dirty
cargo fix -p multi_model_dispatch --allow-dirty
```

#### 需要设计 (中优先级)
1. **config_sync.rs:763** - 实现技能更新逻辑 (git pull)
2. **multi_model_dispatch.rs:201** - 实现 dispatch 结果的 UI 展示

#### 可选优化 (低优先级)
1. 审查 unwrap/expect 调用，考虑使用 `?` 操作符或 `map_err`
2. 确认注释代码块是否为死代码

---

## 2026-02-01 巡检 (21:05)

**扫描路径**: `/mnt/d/ai软件/zed/crates/`

### multi_model_dispatch crate (565 行)

| 文件 | 行号 | 问题类型 | 描述 | 优先级 |
|------|------|----------|------|--------|
| `settings.rs` | 1 | 未使用 import | `App` 从 gpui 导入但未使用 | 低 |
| `multi_model_dispatch.rs` | 13 | 未使用 import | `std::sync::Arc` 导入但未使用 | 低 |
| `multi_model_dispatch.rs` | 201 | TODO | `// TODO: Display plan somewhere?` 待实现 | 中 |

### cc_switch crate (5590 行)

| 文件 | 行号 | 问题类型 | 描述 | 优先级 |
|------|------|----------|------|--------|
| `config_sync.rs` | 763 | TODO | `// TODO: Implement update logic (git pull)` 技能更新逻辑未实现 | 中 |

### 代码质量统计

| 指标 | cc_switch | multi_model_dispatch |
|------|-----------|---------------------|
| 总行数 | 5590 | 565 |
| 源文件数 | 14 | 5 |
| TODO/FIXME | 1 | 1 |
| unwrap() 调用 | 24 (多数在测试/Mutex lock) | 0 |
| expect() 调用 | 12 | 0 |
| 注释代码块 | 0 ✅ | 0 ✅ |
| deprecated API | 0 ✅ | 0 ✅ |
| dbg!/println! | 0 ✅ | 0 ✅ |
| panic! (非测试) | 0 ✅ | 0 ✅ |
| unsafe 块 | 0 ✅ | 0 ✅ |

### 本次扫描结论

✅ **整体代码质量良好**
- 无注释代码块
- 无 deprecated API 使用
- 无调试宏残留 (dbg!/println!)
- 无 unsafe 代码
- unwrap() 主要用于 Mutex lock（可接受模式）和测试代码

⚠️ **待处理项**
1. 2 个未使用的 imports (低优先级，可用 `cargo clippy` 自动修复)
2. 2 个 TODO 待实现 (中优先级)

---

## 清理建议

### 立即可做
```bash
# 在 Windows 端运行 clippy 自动检测未使用 imports
cargo clippy -p multi_model_dispatch -- -W unused-imports
```

### 需要设计
1. **config_sync.rs:763** - 实现技能更新逻辑 (git pull)
2. **multi_model_dispatch.rs:201** - 实现 dispatch 结果的 UI 展示

---

## 2026-02-01 巡检 (21:43) - 最新扫描

**扫描路径**: `/mnt/d/ai软件/zed/crates/`

### multi_model_dispatch crate (565 行)

| 文件 | 行号 | 问题类型 | 描述 | 优先级 |
|------|------|----------|------|--------|
| `agent/agent.rs` | 1 | 未使用 import | `std::sync::Arc` 导入但未使用 | 低 |
| `agent/agent.rs` | 3 | 未使用 import | `gpui::AsyncApp` 导入但未使用 | 低 |
| `agent/agent.rs` | 5 | 未使用 import | `futures::StreamExt` 导入但未使用 | 低 |
| `dispatcher.rs` | 1 | 未使用 import | `std::sync::Arc` 导入但未使用 | 低 |
| `dispatcher.rs` | 3 | 未使用 import | `gpui::{App, AsyncApp, Task}` 导入但未使用 | 低 |
| `dispatcher.rs` | 4 | 未使用 import | `language_model::{LanguageModel, LanguageModelRegistry}` 导入但未使用 | 低 |
| `dispatcher.rs` | 5 | 未使用 import | `crate::agent::{Agent, AgentRole}` 导入但未使用 | 低 |
| `multi_model_dispatch.rs` | 12 | 未使用 import | `ui_input::InputField` 导入但未使用 | 低 |
| `multi_model_dispatch.rs` | 13 | 未使用 import | `std::sync::Arc` 导入但未使用 | 低 |
| `settings.rs` | 1 | 未使用 import | `gpui::{App, Pixels}` 导入但未使用 | 低 |
| `settings.rs` | 2 | 未使用 import | `schemars::JsonSchema` 导入但未使用 | 低 |
| `views/agent_list_view.rs` | 9 | 未使用 import | `crate::multi_model_dispatch::{AgentState, AgentRole, AgentStatus}` 导入但未使用 | 低 |
| `multi_model_dispatch.rs` | 201 | TODO | `// TODO: Display plan somewhere? For now just log/notify.` 待实现 | 中 |

### cc_switch crate (5590 行)

| 文件 | 行号 | 问题类型 | 描述 | 优先级 |
|------|------|----------|------|--------|
| `api_client.rs` | 6,7,11,13,17,20 | 未使用 import | 6 个导入未使用 | 低 |
| `cc_switch.rs` | 46 | 未使用 import | `gpui::App` 导入但未使用 | 低 |
| `cc_switch_panel.rs` | 8,14,18,19 | 未使用 import | 4 个导入未使用 | 低 |
| `config_sync.rs` | 10,11,19 | 未使用 import | 3 个导入未使用 | 低 |
| `models.rs` | 8 | 未使用 import | `indexmap::IndexMap` 导入但未使用 | 低 |
| `persistence.rs` | 5,6,9 | 未使用 import | 3 个导入未使用 | 低 |
| `views/add_mcp_server_modal.rs` | 3,6,8,13,14,16 | 未使用 import | 6 个导入未使用 | 低 |
| `views/add_provider_modal.rs` | 3,6,8,12,13,15 | 未使用 import | 6 个导入未使用 | 低 |
| `views/add_skill_modal.rs` | 3,6,11,12,14 | 未使用 import | 5 个导入未使用 | 低 |
| `views/mcp_view.rs` | 6,8,9,10,14 | 未使用 import | 5 个导入未使用 | 低 |
| `views/providers_view.rs` | 5,10,16 | 未使用 import | 3 个导入未使用 | 低 |
| `views/skills_view.rs` | 6,12,18 | 未使用 import | 3 个导入未使用 | 低 |
| `config_sync.rs` | 763 | TODO | `// TODO: Implement update logic (git pull)` 技能更新逻辑未实现 | 中 |
| `api_client.rs` | 344,355,369,391,409,416,439,442,475,478,513,517 | unwrap() 调用 | 12 个 Mutex lock unwrap() 和测试代码 | 低 |
| `config_sync.rs` | 1303,1317 | unwrap() 调用 | 2 个 unwrap() 调用 | 低 |
| `models.rs` | 608 | unwrap() 调用 | 1 个测试代码中的 unwrap() | 低 |
| `config_sync.rs` | 312,648,692 | 注释代码块 | 3 个注释代码块（可能的死代码） | 低 |

### 代码质量统计

| 指标 | cc_switch | multi_model_dispatch |
|------|-----------|---------------------|
| 总行数 | 5590 | 565 |
| 源文件数 | 14 | 8 |
| TODO/FIXME | 1 | 1 |
| unwrap() 调用 | 24 (多数在 Mutex lock 和测试) | 0 |
| expect() 调用 | 0 | 0 |
| 注释代码块 | 3 | 0 |
| deprecated API | 0 ✅ | 0 ✅ |
| dbg!/println! | 0 ✅ | 0 ✅ |
| panic! (非测试) | 0 ✅ | 0 ✅ |
| unsafe 块 | 0 ✅ | 0 ✅ |
| 未使用 imports | 44 | 12 |

### 本次扫描结论

⚠️ **代码质量有所下降** - 未使用的 imports 数量大幅增加
- multi_model_dispatch: 12 个未使用 imports (之前: 2 个)
- cc_switch: 44 个未使用 imports (之前: 0 个)

✅ **整体代码质量仍可接受**
- 无 deprecated API 使用
- 无调试宏残留 (dbg!/println!)
- 无 unsafe 代码
- 无 panic! (非测试)
- unwrap() 主要用于 Mutex lock（可接受模式）和测试代码

⚠️ **待处理项**
1. 56 个未使用的 imports (高优先级，应立即清理)
2. 2 个 TODO 待实现 (中优先级)
3. 3 个注释代码块 (低优先级，需要确认是否为死代码)

---

## 清理建议

### 立即可做 (高优先级)
```bash
# 在 Windows 端运行 clippy 自动检测未使用 imports
cd /mnt/d/ai软件/zed
cargo clippy -p multi_model_dispatch -- -W unused-imports
cargo clippy -p cc_switch -- -W unused-imports

# 或使用 cargo fix 自动修复
cargo fix -p multi_model_dispatch --allow-dirty
cargo fix -p cc_switch --allow-dirty
```

### 需要设计 (中优先级)
1. **config_sync.rs:763** - 实现技能更新逻辑 (git pull)
2. **multi_model_dispatch.rs:201** - 实现 dispatch 结果的 UI 展示

### 需要审查 (低优先级)
1. **config_sync.rs:312,648,692** - 确认注释代码块是否为死代码，如是则删除

---

## 历史记录

| 日期 | 扫描结果 | 处理状态 |
|------|----------|----------|
| 2026-02-01 22:01 | 26 unused imports, 2 TODOs, 0 注释块 | 需要立即清理 ⚠️ |
| 2026-02-01 21:51 | 56 unused imports, 2 TODOs, 3 注释块 | 需要立即清理 ⚠️ |
| 2026-02-01 21:43 | 56 unused imports, 2 TODOs, 3 注释块 | 需要立即清理 ⚠️ |
| 2026-02-01 21:27 | 2 unused imports, 2 TODOs | 无变化 ⏸️ |
| 2026-02-01 21:05 | 2 unused imports, 2 TODOs | 待处理 |
| 2026-02-01 20:51 | 2 unused imports, 2 TODOs | 已记录 |
