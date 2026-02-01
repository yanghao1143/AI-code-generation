# 更新日志

## [Unreleased]

### 新增
- **cc_switch 模块**: 控制中心切换面板，管理 AI 提供商、MCP 服务器和技能
- **multi_model_dispatch 模块**: 多模型协作调度系统
  - Architect → Coder → Reviewer 链式执行
  - 异步任务管理
  - Agent 状态追踪 UI

### 改进
- **i18n 国际化**: 
  - cc_switch 全部 UI 字符串迁移到 i18n
  - 新增 20+ 翻译 key (en-US/zh-CN)

### 修复
- `get_home_dir()` 优先检查 HOME/USERPROFILE 环境变量
- Mutex 锁污染问题修复 (unwrap_or_else)
- 清理 unused imports 和 deprecated API 调用

### 测试
- cc_switch: 32 个测试全部通过
- multi_model_dispatch: 单元测试通过
- i18n: 12 个测试全部通过

---

## 开发记录

### 2026-02-01
- 三模型协作系统首次成功完成项目
- 约 2 小时完成 cc_switch + multi_model_dispatch 开发
- 建立自动化监控和代码审查流程
