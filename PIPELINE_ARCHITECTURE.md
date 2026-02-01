# 三模型协作系统 - 架构设计

## Agent 状态机

```
IDLE ──派活──→ WORKING
                  │
                  ├──需确认──→ WAITING_CONFIRM ──解卡──→ WORKING
                  │
                  ├──完成──→ COMPLETED ──触发审查──→ REVIEWING
                  │                                      │
                  │                    ┌──审查通过──→ TESTING
                  │                    │                 │
                  │                    │    ┌──测试通过──→ COMMITTING ──→ IDLE (派新活)
                  │                    │    │
                  │                    │    └──测试失败──→ FAILED
                  │                    │
                  │                    └──审查失败──→ FAILED
                  │
                  └──异常──→ ERROR ──恢复──→ IDLE
                                │
                        FAILED ←┘ ──派修复──→ WORKING
```

## Redis 数据结构

### Agent 状态
```
openclaw:agent:{name}:state        # IDLE|WORKING|WAITING_CONFIRM|COMPLETED|REVIEWING|TESTING|COMMITTING|FAILED|ERROR
openclaw:agent:{name}:task         # 当前任务描述
openclaw:agent:{name}:task_id      # 任务ID
openclaw:agent:{name}:started_at   # 任务开始时间
openclaw:agent:{name}:last_active  # 最后活动时间
openclaw:agent:{name}:context_pct  # context 使用百分比
```

### 事件队列
```
openclaw:events:queue              # LIST: 待处理事件 [{type, agent, data, timestamp}]
openclaw:events:processing         # 正在处理的事件
```

### 任务管理
```
openclaw:tasks:backlog             # LIST: 待办任务池
openclaw:tasks:assigned:{agent}    # 已分配给 agent 的任务
openclaw:tasks:completed           # LIST: 已完成任务
openclaw:tasks:failed              # LIST: 失败任务
```

### 流水线追踪
```
openclaw:pipeline:{task_id}:stage      # 当前阶段
openclaw:pipeline:{task_id}:history    # LIST: 阶段历史
openclaw:pipeline:{task_id}:result     # 最终结果
```

### 学习系统
```
openclaw:learn:errors              # HASH: 常见错误 → 解决方案
openclaw:learn:agent_skills        # HASH: agent → 擅长的任务类型
openclaw:learn:task_duration       # HASH: 任务类型 → 平均耗时
openclaw:learn:failure_patterns    # HASH: 失败模式 → 预防措施
```

### 统计数据
```
openclaw:stats:today:completed     # 今日完成数
openclaw:stats:today:failed        # 今日失败数
openclaw:stats:today:reviews       # 今日审查数
openclaw:stats:{agent}:efficiency  # agent 效率评分
```

## 任务分层

### Layer 0: 基础设施 (最高频)
- ⚡ 解卡: 处理确认提示
- 👁️ 心跳: 检测存活

### Layer 1: 状态感知 (高频)
- 🔍 状态检测: 感知状态变化，写入事件

### Layer 2: 事件驱动 (中频)
- 🔄 流水线: 响应事件，驱动工作流
- 🚨 异常处理: 响应错误事件

### Layer 3: 战略决策 (低频)
- 🎯 指挥官: 全局规划，任务分配
- ⏱️ 效率分析: 优化建议

### Layer 4: 质量保证 (最低频)
- 🏗️ 架构守护
- 🧹 代码质量
- 🔐 依赖安全

## 智能决策规则

### 任务分配
1. 检查 openclaw:learn:agent_skills 获取 agent 擅长领域
2. 检查当前负载，优先分配给空闲 agent
3. 考虑任务依赖关系
4. 记录分配决策，用于后续学习

### 错误恢复
1. 检查 openclaw:learn:errors 是否有已知解决方案
2. 尝试已知方案
3. 失败则记录新错误，升级给用户
4. 成功则更新解决方案库

### 效率优化
1. 分析 openclaw:stats 识别瓶颈
2. 调整任务分配策略
3. 记录优化效果
