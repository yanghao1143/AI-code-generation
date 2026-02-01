# Zed 项目架构文档

> 自动生成，由 AI Agent 维护

## 项目概览

Zed 是一个高性能的代码编辑器，使用 Rust 构建。

## 核心模块

### cc_switch (Control Center Switch)
**路径**: `crates/cc_switch`

控制中心切换模块，管理 AI 提供商、MCP 服务器和技能。

#### 主要组件
| 文件 | 用途 |
|------|------|
| `cc_switch.rs` | 主入口，注册 actions |
| `cc_switch_panel.rs` | 面板 UI 组件 |
| `config_sync.rs` | 配置同步逻辑 |
| `models.rs` | 数据模型定义 |
| `api_client.rs` | API 客户端 |
| `persistence.rs` | 持久化存储 |

#### Views 子模块
| 文件 | 用途 |
|------|------|
| `providers_view.rs` | AI 提供商列表视图 |
| `mcp_view.rs` | MCP 服务器管理视图 |
| `skills_view.rs` | 技能管理视图 |
| `add_provider_modal.rs` | 添加提供商弹窗 |
| `add_mcp_server_modal.rs` | 添加 MCP 服务器弹窗 |
| `add_skill_modal.rs` | 添加技能弹窗 |

#### API
```rust
// 获取 home 目录
pub fn get_home_dir() -> Option<PathBuf>

// 配置同步
pub struct ConfigSync { ... }
impl ConfigSync {
    pub fn new() -> Self
    pub fn sync(&self) -> Result<()>
}
```

---

### multi_model_dispatch (多模型调度)
**路径**: `crates/multi_model_dispatch`

多模型协作调度系统，实现 Architect → Coder → Reviewer 链式执行。

#### 主要组件
| 文件 | 用途 |
|------|------|
| `lib.rs` | 模块入口 |
| `dispatcher.rs` | 核心调度器 |
| `settings.rs` | 配置管理 |
| `multi_model_dispatch.rs` | UI 面板 |

#### Agent 子模块
| 文件 | 用途 |
|------|------|
| `agent/agent.rs` | Agent 角色定义和执行 |
| `agent/mod.rs` | 模块导出 |

#### Views 子模块
| 文件 | 用途 |
|------|------|
| `views/agent_list_view.rs` | Agent 列表视图 |
| `views/mod.rs` | 视图模块导出 |

#### API
```rust
// Agent 角色
pub enum AgentRole {
    Architect,  // 架构师：分析任务，制定计划
    Coder,      // 编码者：实现代码
    Reviewer,   // 审查者：代码审查
}

// 调度器
pub struct Dispatcher { ... }
impl Dispatcher {
    pub fn new() -> Self
    pub fn dispatch(&self, task: String, cx: &mut Context) -> Task<Result<String>>
}
```

---

### i18n (国际化)
**路径**: `crates/i18n`

国际化支持模块。

#### 翻译文件
- `locales/en-US/main.ftl` - 英文翻译
- `locales/zh-CN/main.ftl` - 中文翻译

#### 新增翻译 Key
| Key | 英文 | 中文 |
|-----|------|------|
| `cc-search-mcp-servers` | Search MCP servers... | 搜索 MCP 服务器... |
| `cc-search-skills` | Search skills... | 搜索技能... |
| `cc-provider-name-placeholder` | Provider name | 提供商名称 |
| `cc-api-key` | API Key | API 密钥 |
| `cc-api-url` | API URL | API 地址 |
| `cc-edit-mcp-server` | Edit MCP Server | 编辑 MCP 服务器 |
| `cc-environment-variables` | Environment Variables | 环境变量 |

---

## 依赖关系

```
zed (主程序)
├── cc_switch
│   ├── gpui (UI 框架)
│   ├── i18n (国际化)
│   ├── ui (UI 组件库)
│   └── settings (配置)
├── multi_model_dispatch
│   ├── gpui
│   ├── language_model (语言模型接口)
│   └── ui
└── i18n
    └── fluent (Fluent 翻译引擎)
```

---

## 最近更新

### 2026-02-01
- ✅ cc_switch 模块 i18n 迁移完成
- ✅ multi_model_dispatch 调度器实现
- ✅ 32 个 cc_switch 测试全部通过
- ✅ 12 个 i18n 测试全部通过

---

## 测试状态

| 模块 | 测试数 | 状态 |
|------|--------|------|
| cc_switch | 32 | ✅ 全部通过 |
| multi_model_dispatch | 2 | ✅ 全部通过 |
| i18n | 12 | ✅ 全部通过 |

---

*最后更新: 2026-02-01 20:51*
*维护者: AI Agent (Claude/Gemini/Codex)*
