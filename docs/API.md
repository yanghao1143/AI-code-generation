# API 文档

## cc_switch 模块

### ConfigSync

配置同步管理器。

```rust
use cc_switch::ConfigSync;

let sync = ConfigSync::new();
sync.sync()?;
```

### Models

#### Provider (AI 提供商)

```rust
pub struct Provider {
    pub id: String,
    pub name: String,
    pub api_key: Option<String>,
    pub api_url: Option<String>,
    pub enabled: bool,
}
```

#### McpServer (MCP 服务器)

```rust
pub struct McpServer {
    pub id: String,
    pub name: String,
    pub command: String,
    pub args: Vec<String>,
    pub env: HashMap<String, String>,
    pub enabled: bool,
}
```

#### Skill (技能)

```rust
pub struct Skill {
    pub id: String,
    pub name: String,
    pub repository_url: Option<String>,
    pub local_path: Option<PathBuf>,
    pub enabled: bool,
}
```

---

## multi_model_dispatch 模块

### Dispatcher

多模型调度器，协调多个 AI Agent 完成任务。

```rust
use multi_model_dispatch::{Dispatcher, AgentRole};

let dispatcher = Dispatcher::new();

// 调度任务
let result = dispatcher.dispatch("实现一个排序算法".to_string(), cx).await?;
```

### AgentRole

Agent 角色枚举。

```rust
pub enum AgentRole {
    /// 架构师：分析任务，制定计划
    Architect,
    
    /// 编码者：根据计划实现代码
    Coder,
    
    /// 审查者：审查代码质量
    Reviewer,
}
```

### 执行流程

```
1. Architect 分析任务 → 生成执行计划
2. Coder 根据计划 → 实现代码
3. Reviewer 审查代码 → 提出改进建议
4. 返回最终结果
```

---

## i18n 模块

### t() 宏

获取翻译文本。

```rust
use i18n::t;

// 简单翻译
let text = t("hello");

// 带参数的翻译
let text = t("greeting", name = "World");
```

### 添加新翻译

1. 在 `locales/en-US/main.ftl` 添加英文:
```ftl
my-new-key = My new text
```

2. 在 `locales/zh-CN/main.ftl` 添加中文:
```ftl
my-new-key = 我的新文本
```

3. 在代码中使用:
```rust
Label::new(t("my-new-key"))
```

---

*最后更新: 2026-02-01*
