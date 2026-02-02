# 标准任务 Prompt 模板

## 格式 (必须遵循)

```
PURPOSE: [一句话说清目标]
TASK: [具体要做什么]
CONTEXT: [相关文件/代码/之前的决策]
EXPECTED: [预期产出物]
RULES: [约束条件/验收标准]
```

## 示例

### 开发任务
```
PURPOSE: 实现用户认证模块
TASK: 创建 JWT-based 认证系统，包含 login/logout/refresh
CONTEXT: 
  - 现有用户模型: src/models/user.rs
  - API 路由: src/routes/mod.rs
  - 参考: 项目已有的 session 处理方式
EXPECTED: 
  - auth.rs 模块
  - 单元测试
  - cargo test 通过
RULES:
  - 使用项目现有的 error handling 模式
  - 不引入新依赖
  - 遵循现有代码风格
```

### 分析任务
```
PURPOSE: 理解 cc_switch 模块架构
TASK: 分析模块结构、依赖关系、核心逻辑
CONTEXT:
  - 入口: crates/cc_switch/src/lib.rs
  - 相关: multi_model_dispatch 模块
EXPECTED:
  - 架构图 (文字描述)
  - 关键组件列表
  - 潜在问题点
RULES:
  - 只读分析，不修改代码
  - 重点关注 public API
```

### 修复任务
```
PURPOSE: 修复测试失败
TASK: 解决 cc_switch 32 个测试失败
CONTEXT:
  - 错误日志: TEST_REGRESSION_FAILURE.md
  - 测试文件: crates/cc_switch/src/tests/
  - 已知问题: lock poisoning, HOME_DIR 环境变量
EXPECTED:
  - 所有测试通过
  - 无新增 warnings
RULES:
  - 最小改动原则
  - 修复后运行完整测试套件
  - 记录修复方案
```

## Agent 分工模板

### Claude (分析/i18n)
```
PURPOSE: [分析/国际化目标]
TASK: [具体分析或迁移任务]
CONTEXT: [文件范围]
EXPECTED: [分析报告/迁移完成]
RULES: 只读分析 | 使用 t() 宏 | 更新 .ftl 文件
```

### Gemini (架构/验证)
```
PURPOSE: [架构设计/验证目标]
TASK: [设计或验证任务]
CONTEXT: [相关模块/文档]
EXPECTED: [设计文档/验证报告]
RULES: cargo check 通过 | cargo test 通过 | 文档更新
```

### Codex (实现/修复)
```
PURPOSE: [实现/修复目标]
TASK: [具体开发任务]
CONTEXT: [代码位置/错误信息]
EXPECTED: [功能实现/错误修复]
RULES: 测试通过 | 无编译错误 | 最小改动
```
