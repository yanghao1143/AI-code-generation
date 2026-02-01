# Redis API 文档

> 三模型协作系统的 Redis 数据结构和 API 规范

## 目录

- [Agent 状态管理](#agent-状态管理)
- [任务管理](#任务管理)
- [事件队列](#事件队列)
- [工作流管理](#工作流管理)
- [流水线追踪](#流水线追踪)
- [学习系统](#学习系统)
- [统计数据](#统计数据)
- [死锁检测](#死锁检测)

---

## Agent 状态管理

### Agent 状态

**Key**: `openclaw:agent:{name}:state`

**类型**: String

**值**: `IDLE` | `WORKING` | `WAITING_CONFIRM` | `COMPLETED` | `REVIEWING` | `TESTING` | `COMMITTING` | `FAILED` | `ERROR`

**示例**:
```bash
# 设置 agent 状态
redis-cli SET openclaw:agent:claude:state WORKING

# 获取 agent 状态
redis-cli GET openclaw:agent:claude:state
```

### Agent 任务信息

**Key**: `openclaw:agent:{name}:task`

**类型**: String

**值**: 当前任务描述

**示例**:
```bash
# 设置任务描述
redis-cli SET openclaw:agent:claude:task "修复 cc_switch 编译错误"

# 获取任务描述
redis-cli GET openclaw:agent:claude:task
```

### Agent 任务 ID

**Key**: `openclaw:agent:{name}:task_id`

**类型**: String

**值**: 任务唯一标识符

**示例**:
```bash
redis-cli SET openclaw:agent:claude:task_id "task-001"
redis-cli GET openclaw:agent:claude:task_id
```

### Agent 开始时间

**Key**: `openclaw:agent:{name}:started_at`

**类型**: String (ISO 8601 timestamp)

**值**: 任务开始时间

**示例**:
```bash
redis-cli SET openclaw:agent:claude:started_at "2026-02-01T18:17:00Z"
redis-cli GET openclaw:agent:claude:started_at
```

### Agent 最后活动时间

**Key**: `openclaw:agent:{name}:last_active`

**类型**: String (ISO 8601 timestamp)

**值**: 最后活动时间

**示例**:
```bash
redis-cli SET openclaw:agent:claude:last_active "2026-02-01T22:08:00Z"
redis-cli GET openclaw:agent:claude:last_active
```

### Agent Context 使用率

**Key**: `openclaw:agent:{name}:context_pct`

**类型**: String (number)

**值**: Context 使用百分比 (0-100)

**示例**:
```bash
redis-cli SET openclaw:agent:claude:context_pct "70"
redis-cli GET openclaw:agent:claude:context_pct
```

---

## 任务管理

### 任务待办池

**Key**: `openclaw:tasks:backlog`

**类型**: List

**值**: 待办任务列表 (JSON 字符串)

**示例**:
```bash
# 添加任务到待办池
redis-cli RPUSH openclaw:tasks:backlog '{"id":"task-001","type":"backend","desc":"修复编译错误"}'

# 获取所有待办任务
redis-cli LRANGE openclaw:tasks:backlog 0 -1

# 弹出第一个任务
redis-cli LPOP openclaw:tasks:backlog
```

### 已分配任务

**Key**: `openclaw:tasks:assigned:{agent}`

**类型**: String (JSON)

**值**: 分配给特定 agent 的任务

**示例**:
```bash
# 分配任务给 claude
redis-cli SET openclaw:tasks:assigned:claude '{"id":"task-001","type":"backend","desc":"修复编译错误"}'

# 获取 claude 的任务
redis-cli GET openclaw:tasks:assigned:claude
```

### 已完成任务

**Key**: `openclaw:tasks:completed`

**类型**: List

**值**: 已完成任务列表 (JSON 字符串)

**示例**:
```bash
# 添加已完成任务
redis-cli RPUSH openclaw:tasks:completed '{"id":"task-001","agent":"claude","completed_at":"2026-02-01T22:00:00Z"}'

# 获取所有已完成任务
redis-cli LRANGE openclaw:tasks:completed 0 -1
```

### 失败任务

**Key**: `openclaw:tasks:failed`

**类型**: List

**值**: 失败任务列表 (JSON 字符串)

**示例**:
```bash
# 添加失败任务
redis-cli RPUSH openclaw:tasks:failed '{"id":"task-002","agent":"codex","error":"测试失败","failed_at":"2026-02-01T21:30:00Z"}'

# 获取所有失败任务
redis-cli LRANGE openclaw:tasks:failed 0 -1
```

### 任务状态

**Key**: `openclaw:task:{id}:status`

**类型**: String

**值**: `pending` | `planning` | `executing` | `reviewing` | `done` | `failed`

**示例**:
```bash
redis-cli SET openclaw:task:task-001:status executing
redis-cli GET openclaw:task:task-001:status
```

### 任务计划

**Key**: `openclaw:task:{id}:plan`

**类型**: String (JSON)

**值**: 任务计划内容

**示例**:
```bash
redis-cli SET openclaw:task:task-001:plan '{"steps":["分析错误","修复代码","运行测试"]}'
redis-cli GET openclaw:task:task-001:plan
```

### 任务进度

**Key**: `openclaw:task:{id}:progress`

**类型**: String (number)

**值**: 当前步骤号

**示例**:
```bash
redis-cli SET openclaw:task:task-001:progress "2"
redis-cli GET openclaw:task:task-001:progress
```

### 任务分配

**Key**: `openclaw:task:{id}:agent`

**类型**: String

**值**: 分配的 agent 名称

**示例**:
```bash
redis-cli SET openclaw:task:task-001:agent "claude"
redis-cli GET openclaw:task:task-001:agent
```

### 任务评分

**Key**: `openclaw:task:{id}:score`

**类型**: String (number)

**值**: 质量评分 (0-10)

**示例**:
```bash
redis-cli SET openclaw:task:task-001:score "8"
redis-cli GET openclaw:task:task-001:score
```

---

## 事件队列

### 待处理事件

**Key**: `openclaw:events:queue`

**类型**: List

**值**: 事件列表 (JSON 字符串)

**格式**:
```json
{
  "type": "task_completed",
  "agent": "claude",
  "data": {...},
  "timestamp": "2026-02-01T22:00:00Z"
}
```

**示例**:
```bash
# 添加事件
redis-cli RPUSH openclaw:events:queue '{"type":"task_completed","agent":"claude","timestamp":"2026-02-01T22:00:00Z"}'

# 获取所有事件
redis-cli LRANGE openclaw:events:queue 0 -1

# 弹出第一个事件
redis-cli LPOP openclaw:events:queue
```

### 正在处理的事件

**Key**: `openclaw:events:processing`

**类型**: String (JSON)

**值**: 当前正在处理的事件

**示例**:
```bash
redis-cli SET openclaw:events:processing '{"type":"task_completed","agent":"claude"}'
redis-cli GET openclaw:events:processing
redis-cli DEL openclaw:events:processing
```

---

## 工作流管理

### 当前工作流

**Key**: `openclaw:workflow:current`

**类型**: String

**值**: 当前工作流 ID

**示例**:
```bash
redis-cli SET openclaw:workflow:current "workflow-001"
redis-cli GET openclaw:workflow:current
```

### 工作流阶段

**Key**: `openclaw:workflow:{id}:phase`

**类型**: String (number)

**值**: 当前阶段 (1-6)

**阶段说明**:
1. 研究 (Research)
2. 构思 (Ideate)
3. 计划 (Plan)
4. 执行 (Execute)
5. 优化 (Optimize)
6. 评审 (Review)

**示例**:
```bash
redis-cli SET openclaw:workflow:workflow-001:phase "4"
redis-cli GET openclaw:workflow:workflow-001:phase
```

### 工作流任务列表

**Key**: `openclaw:workflow:{id}:tasks`

**类型**: List

**值**: 任务 ID 列表

**示例**:
```bash
redis-cli RPUSH openclaw:workflow:workflow-001:tasks "task-001"
redis-cli RPUSH openclaw:workflow:workflow-001:tasks "task-002"
redis-cli LRANGE openclaw:workflow:workflow-001:tasks 0 -1
```

---

## 流水线追踪

### 流水线阶段

**Key**: `openclaw:pipeline:{task_id}:stage`

**类型**: String

**值**: 当前阶段名称

**示例**:
```bash
redis-cli SET openclaw:pipeline:task-001:stage "reviewing"
redis-cli GET openclaw:pipeline:task-001:stage
```

### 流水线历史

**Key**: `openclaw:pipeline:{task_id}:history`

**类型**: List

**值**: 阶段历史 (JSON 字符串)

**格式**:
```json
{
  "stage": "executing",
  "started_at": "2026-02-01T20:00:00Z",
  "completed_at": "2026-02-01T21:00:00Z",
  "status": "success"
}
```

**示例**:
```bash
redis-cli RPUSH openclaw:pipeline:task-001:history '{"stage":"executing","status":"success"}'
redis-cli LRANGE openclaw:pipeline:task-001:history 0 -1
```

### 流水线结果

**Key**: `openclaw:pipeline:{task_id}:result`

**类型**: String (JSON)

**值**: 最终结果

**示例**:
```bash
redis-cli SET openclaw:pipeline:task-001:result '{"status":"success","commit":"abc123"}'
redis-cli GET openclaw:pipeline:task-001:result
```

---

## 学习系统

### 常见错误解决方案

**Key**: `openclaw:learn:errors`

**类型**: Hash

**字段**: 错误描述 → 解决方案

**示例**:
```bash
# 添加错误解决方案
redis-cli HSET openclaw:learn:errors "cargo not found" "安装 Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"

# 获取解决方案
redis-cli HGET openclaw:learn:errors "cargo not found"

# 获取所有错误
redis-cli HGETALL openclaw:learn:errors
```

### Agent 技能

**Key**: `openclaw:learn:agent_skills`

**类型**: Hash

**字段**: agent 名称 → 擅长的任务类型 (JSON 数组)

**示例**:
```bash
redis-cli HSET openclaw:learn:agent_skills "claude" '["backend","refactor","i18n"]'
redis-cli HGET openclaw:learn:agent_skills "claude"
redis-cli HGETALL openclaw:learn:agent_skills
```

### 任务耗时

**Key**: `openclaw:learn:task_duration`

**类型**: Hash

**字段**: 任务类型 → 平均耗时 (秒)

**示例**:
```bash
redis-cli HSET openclaw:learn:task_duration "backend" "3600"
redis-cli HGET openclaw:learn:task_duration "backend"
redis-cli HGETALL openclaw:learn:task_duration
```

### 失败模式

**Key**: `openclaw:learn:failure_patterns`

**类型**: Hash

**字段**: 失败模式 → 预防措施

**示例**:
```bash
redis-cli HSET openclaw:learn:failure_patterns "long_wait" "实现自动确认机制"
redis-cli HGET openclaw:learn:failure_patterns "long_wait"
redis-cli HGETALL openclaw:learn:failure_patterns
```

---

## 统计数据

### 今日完成数

**Key**: `openclaw:stats:today:completed`

**类型**: String (number)

**值**: 今日完成任务数

**示例**:
```bash
redis-cli INCR openclaw:stats:today:completed
redis-cli GET openclaw:stats:today:completed
```

### 今日失败数

**Key**: `openclaw:stats:today:failed`

**类型**: String (number)

**值**: 今日失败任务数

**示例**:
```bash
redis-cli INCR openclaw:stats:today:failed
redis-cli GET openclaw:stats:today:failed
```

### 今日审查数

**Key**: `openclaw:stats:today:reviews`

**类型**: String (number)

**值**: 今日代码审查数

**示例**:
```bash
redis-cli INCR openclaw:stats:today:reviews
redis-cli GET openclaw:stats:today:reviews
```

### Agent 效率评分

**Key**: `openclaw:stats:{agent}:efficiency`

**类型**: String (number)

**值**: 效率评分 (0-100)

**示例**:
```bash
redis-cli SET openclaw:stats:claude:efficiency "85"
redis-cli GET openclaw:stats:claude:efficiency
```

---

## 死锁检测

### 死锁恢复记录

**Key**: `openclaw:deadlock:recovery`

**类型**: Hash

**字段**:
- `last_detection`: 最后检测时间 (ISO 8601)
- `idle_time_seconds`: 无活动时长 (秒)
- `sessions_recovered`: 恢复的会话数
- `{agent}_status`: 各 agent 恢复后状态

**示例**:
```bash
# 记录死锁恢复
redis-cli HSET openclaw:deadlock:recovery last_detection "2026-02-01T14:08:05Z"
redis-cli HSET openclaw:deadlock:recovery idle_time_seconds "13809"
redis-cli HSET openclaw:deadlock:recovery sessions_recovered "3"
redis-cli HSET openclaw:deadlock:recovery claude_status "working"

# 获取恢复记录
redis-cli HGETALL openclaw:deadlock:recovery
```

---

## 批量操作示例

### 初始化 Agent 状态

```bash
#!/bin/bash

# 初始化 Claude
redis-cli SET openclaw:agent:claude:state IDLE
redis-cli SET openclaw:agent:claude:context_pct "0"

# 初始化 Gemini
redis-cli SET openclaw:agent:gemini:state IDLE
redis-cli SET openclaw:agent:gemini:context_pct "0"

# 初始化 Codex
redis-cli SET openclaw:agent:codex:state IDLE
redis-cli SET openclaw:agent:codex:context_pct "0"
```

### 清理过期数据

```bash
#!/bin/bash

# 清理今日统计 (每天 00:00 执行)
redis-cli DEL openclaw:stats:today:completed
redis-cli DEL openclaw:stats:today:failed
redis-cli DEL openclaw:stats:today:reviews

# 清理已完成任务 (保留最近 100 条)
redis-cli LTRIM openclaw:tasks:completed 0 99
```

### 获取系统状态

```bash
#!/bin/bash

echo "=== Agent 状态 ==="
redis-cli GET openclaw:agent:claude:state
redis-cli GET openclaw:agent:gemini:state
redis-cli GET openclaw:agent:codex:state

echo "=== 任务统计 ==="
redis-cli LLEN openclaw:tasks:backlog
redis-cli LLEN openclaw:tasks:completed
redis-cli LLEN openclaw:tasks:failed

echo "=== 今日统计 ==="
redis-cli GET openclaw:stats:today:completed
redis-cli GET openclaw:stats:today:failed
redis-cli GET openclaw:stats:today:reviews
```

---

## 版本历史

- **v1.0** (2026-02-01): 初始版本
