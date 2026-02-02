# 任务体系架构 v2.0

## 核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw 指挥中心                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Claude    │    │   Gemini    │    │   Codex     │     │
│  │  (分析/i18n) │    │  (架构/验证) │    │  (实现/修复) │     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │                                │
│                    ┌───────▼───────┐                        │
│                    │  tmux 会话池   │                        │
│                    │ /tmp/openclaw- │                        │
│                    │  agents.sock   │                        │
│                    └───────┬───────┘                        │
│                            │                                │
├────────────────────────────┼────────────────────────────────┤
│                            │                                │
│  ┌─────────────────────────▼─────────────────────────────┐  │
│  │                    Redis 状态层                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐            │  │
│  │  │ 任务队列  │  │ 上下文缓存 │  │ 学习库   │            │  │
│  │  │ task:*   │  │ ctx:*    │  │ learning:*│            │  │
│  │  └──────────┘  └──────────┘  └──────────┘            │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                       脚本工具层                             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────┐ │
│  │dispatch-   │ │task-       │ │agent-      │ │pre-      │ │
│  │task.sh     │ │tracker.sh  │ │health.sh   │ │verify.sh │ │
│  │(标准派发)   │ │(JSON状态)   │ │(健康检查)   │ │(双重验证) │ │
│  └────────────┘ └────────────┘ └────────────┘ └──────────┘ │
│                                                             │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐              │
│  │context-    │ │redis-      │ │smart-      │              │
│  │compressor  │ │context-mgr │ │router.sh   │              │
│  │(上下文压缩) │ │(缓存管理)   │ │(智能路由)   │              │
│  └────────────┘ └────────────┘ └────────────┘              │
└─────────────────────────────────────────────────────────────┘
```

## 工作流程

### 1. 任务派发流程
```
用户需求 → dispatch-task.sh → 标准化 Prompt → tmux 发送 → Agent 执行
                ↓
         task-tracker.sh (记录状态)
                ↓
         Redis (持久化)
```

### 2. 健康监控流程
```
Cron (5分钟) → agent-health.sh check → 状态判定
                                          ↓
                              ┌───────────┴───────────┐
                              ↓                       ↓
                          健康 → 继续              异常 → 自动恢复
                                                      ↓
                                              agent-health.sh recover
```

### 3. 预执行验证流程 (可选)
```
复杂任务 → pre-verify.sh → Gemini (战略分析)
                        → Codex (技术分析)
                              ↓
                        双重确认后执行
```

## 标准 Prompt 模板

```
PURPOSE: [一句话目标]
TASK: [具体任务]
CONTEXT: [相关文件/决策]
EXPECTED: [预期产出]
RULES: [约束/验收标准]
```

## 命令速查

```bash
# 派发任务
./scripts/dispatch-task.sh <agent> "<purpose>" "<task>" "[context]" "[expected]" "[rules]"

# 任务管理
./scripts/task-tracker.sh create <agent> "<purpose>" "<task>"
./scripts/task-tracker.sh start <task_id>
./scripts/task-tracker.sh complete <task_id>
./scripts/task-tracker.sh list
./scripts/task-tracker.sh stats

# 健康检查
./scripts/agent-health.sh check    # 检查状态
./scripts/agent-health.sh recover  # 自动恢复
./scripts/agent-health.sh monitor  # 持续监控

# 预执行验证
./scripts/pre-verify.sh "<task_description>" [files...]

# 上下文管理
./scripts/context-compressor.sh compress main aggressive
./scripts/redis-context-manager.sh save-checkpoint <id> <data>
```

## Cron 任务

| 任务 | 间隔 | 功能 |
|------|------|------|
| agent-health-check | 5分钟 | 健康检查 + 自动恢复 |
| context-overflow-monitor | 5分钟 | 上下文使用率监控 |
| layer2-exception | 5分钟 | L2 异常处理 |

## 改进来源

基于 [Claude Code Workflow (CCW)](https://github.com/yifanxz/claude-code-workflow) 学习:
- ✅ 标准化 Prompt 模板 (PURPOSE/TASK/CONTEXT/EXPECTED/RULES)
- ✅ JSON-First 任务状态管理
- ✅ 预执行验证 (双 agent 审核)
- ✅ 工具选择矩阵 (分析/架构/实现)
- ✅ 上下文优化策略
