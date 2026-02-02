# AI Code Generation - 三模型协作系统

基于 OpenClaw 的多模型协作框架，实现 Claude/Gemini/Codex 三个 AI Agent 协同开发。

## 🎯 项目目标

构建一个自动化的多 Agent 开发系统，让三个 AI 模型协同工作，提高代码开发效率。

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw (指挥官/编排者)                   │
│  - 任务规划与分解                                             │
│  - 代码审核与合并                                             │
│  - 质量把关与验收                                             │
│  - 全局协调与决策                                             │
├─────────────────────────────────────────────────────────────┤
│         Claude CLI              │         Gemini CLI         │
│    (后端/逻辑/算法权威)          │    (前端/UI/设计权威)        │
├─────────────────────────────────────────────────────────────┤
│                         Codex CLI                            │
│                    (修复/测试/清理权威)                        │
└─────────────────────────────────────────────────────────────┘
```

## 📊 开发进度

### 当前版本: v0.2.0 (2026-02-02)

#### ✅ 已完成功能

**核心系统**
- [x] 三模型协作架构设计
- [x] tmux 多会话管理
- [x] Redis 上下文缓存系统
- [x] Agent 健康检查与自动恢复
- [x] 自动派活系统
- [x] 死锁检测与恢复机制

**自动化能力**
- [x] 权限确认自动处理
- [x] 空闲 Agent 自动派活
- [x] 状态检测与误判修复
- [x] 上下文溢出监控

**代码质量**
- [x] 代码质量巡检脚本
- [x] 未使用 imports 清理
- [x] 死代码检测

#### 🚧 进行中

- [ ] i18n 国际化迁移 (workspace, project_panel, terminal_view, title_bar)
- [ ] TaskInputView 代码清理

#### 📋 待开发

- [ ] 智能任务分配算法
- [ ] Agent 效率自动优化
- [ ] 上下文自动压缩

---

## 📝 更新日志

### 2026-02-02

#### v0.2.0 - 自动化系统升级

**新增**
- `scripts/auto-dispatch.sh` - 自动派活系统
- `scripts/auto-manage.sh` - 统一管理脚本 (健康检查+恢复+派活)
- `has_pending_input` 检测 - 发现未发送的输入

**修复**
- 修复 `is_waiting_confirm` 误判空闲状态为等待确认
- 修复 `get_idle_agents` 空闲检测不准确
- 修复 bash 函数定义顺序问题

**改进**
- Claude CLI 默认使用 `--dangerously-skip-permissions` 模式
- 更精确的 Agent 状态检测
- Cron 任务升级为 auto-manage

### 2026-02-01

#### v0.1.0 - 初始版本

**新增**
- 三模型协作系统架构
- Agent 健康检查脚本
- Redis 上下文管理
- 死锁检测与恢复
- 代码质量巡检

**完成任务**
- Agent 效率分析报告
- 优化建议文档
- 多次死锁恢复

---

## 🛠️ 使用方法

### 启动 Agent

```bash
# 启动所有 agent
./scripts/start-agents.sh

# 检查健康状态
./scripts/agent-health.sh check

# 自动管理 (健康检查+恢复+派活)
./scripts/auto-manage.sh
```

### Redis 缓存

```bash
# 查看任务状态
redis-cli SMEMBERS openclaw:ctx:tasks:active

# 查看 agent 效率
redis-cli HGETALL openclaw:agent:efficiency
```

---

## 📁 项目结构

```
.
├── scripts/                 # 自动化脚本
│   ├── agent-health.sh      # 健康检查与恢复
│   ├── auto-dispatch.sh     # 自动派活
│   ├── auto-manage.sh       # 统一管理
│   └── ...
├── templates/               # Prompt 模板
├── memory/                  # 每日日志
├── MEMORY.md               # 长期记忆
├── ARCHITECTURE.md         # 系统架构
└── README.md               # 本文件
```

---

## 📈 统计

- **总提交数**: 30+
- **活跃 Agent**: 3 (Claude, Gemini, Codex)
- **自动恢复次数**: 4+
- **代码质量巡检**: 5+

---

## 🔗 相关链接

- [系统架构文档](./ARCHITECTURE.md)
- [Agent 优化建议](./AGENT_OPTIMIZATION.md)
- [更新日志](./CHANGELOG.md)

---

*最后更新: 2026-02-02 08:45*
