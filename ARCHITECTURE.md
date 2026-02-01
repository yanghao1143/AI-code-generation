# 三模型协作系统 - 系统架构

> 基于 OpenClaw 的多模型协作框架，参考 [ccg-workflow](https://github.com/fengshao1227/ccg-workflow) 设计理念

## 目录

- [核心原则](#核心原则)
- [角色分工](#角色分工)
- [工作流设计](#工作流设计)
- [状态机](#状态机)
- [数据架构](#数据架构)
- [任务分层](#任务分层)
- [智能决策](#智能决策)

---

## 核心原则

### 1. 角色分工

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw (指挥官/编排者)                   │
│  - 任务规划与分解 (WBS)                                       │
│  - 代码审核与合并                                             │
│  - 质量把关与验收                                             │
│  - 全局协调与决策                                             │
├─────────────────────────────────────────────────────────────┤
│         Claude CLI              │         Gemini CLI         │
│    (后端/逻辑/算法权威)          │    (前端/UI/设计权威)        │
│  - 复杂重构                      │  - 架构设计                 │
│  - i18n 迁移                     │  - UI 组件                  │
│  - 代码审查                      │  - 新功能开发               │
├─────────────────────────────────────────────────────────────┤
│                         Codex CLI                            │
│                    (修复/测试/清理权威)                        │
│  - Bug 修复                                                  │
│  - 测试编写                                                  │
│  - 代码清理                                                  │
│  - 性能优化                                                  │
└─────────────────────────────────────────────────────────────┘
```

### 2. 信任规则

| 领域 | 权威模型 | 说明 |
|------|----------|------|
| 后端逻辑 | Claude | 算法、数据流、错误处理 |
| 前端设计 | Gemini | UI/UX、视觉、交互 |
| 修复测试 | Codex | Bug 修复、测试、清理 |
| 最终决策 | OpenClaw | 审核、合并、验收 |

### 3. 零写入权限

**外部模型 (Claude/Gemini/Codex CLI) 不能直接修改代码**

工作流：
1. Agent 输出代码建议/Patch
2. OpenClaw 审核
3. 审核通过 → OpenClaw 执行修改
4. 审核失败 → 返回修改意见

---

## 角色分工

### OpenClaw (指挥官)

**核心职责**:
1. **需求分析**: 理解用户需求，评估完整性
2. **任务分解**: 使用 WBS 分解为可执行任务
3. **智能分配**: 根据任务类型分配给合适的 agent
4. **进度追踪**: 监控执行进度，处理阻塞
5. **质量把关**: 审核代码，验收结果
6. **协调冲突**: 处理多 agent 冲突

**决策规则**:
- 后端逻辑/重构/i18n → Claude
- 前端/UI/架构设计 → Gemini
- Bug修复/测试/清理 → Codex

### Claude CLI (后端权威)

**擅长领域**:
- 复杂算法实现
- 数据流重构
- i18n 国际化迁移
- 错误处理逻辑

**工作模式**:
- 接收任务 → 分析 → 输出代码建议 → 等待审核

### Gemini CLI (前端权威)

**擅长领域**:
- 架构设计
- UI 组件开发
- 用户体验优化
- 新功能开发

**工作模式**:
- 接收任务 → 设计 → 输出实现方案 → 等待审核

### Codex CLI (修复权威)

**擅长领域**:
- Bug 快速定位与修复
- 单元测试编写
- 死代码清理
- 性能优化

**工作模式**:
- 接收任务 → 修复 → 输出 Patch → 等待审核

---

## 工作流设计

### 6 阶段工作流

```
┌─────────┐    ┌─────────┐    ┌─────────┐
│ 1.研究  │ → │ 2.构思  │ → │ 3.计划  │
│ Research│    │ Ideate  │    │  Plan   │
└─────────┘    └─────────┘    └─────────┘
     ↓              ↓              ↓
  需求分析      方案对比       WBS分解
  上下文检索    多模型分析     任务清单
  完整性评分    交叉验证       依赖关系
     
┌─────────┐    ┌─────────┐    ┌─────────┐
│ 4.执行  │ → │ 5.优化  │ → │ 6.评审  │
│ Execute │    │ Optimize│    │ Review  │
└─────────┘    └─────────┘    └─────────┘
     ↓              ↓              ↓
  代码实现      代码审查       质量验收
  里程碑检查    性能优化       测试验证
  进度追踪      安全检查       最终确认
```

### 规划与执行分离

**规划阶段** (不修改代码):
1. 需求分析
2. 上下文检索
3. 多模型并行分析
4. 生成 WBS 任务清单
5. 保存计划到 `.claude/plan/`

**执行阶段** (按计划执行):
1. 读取计划文件
2. 按步骤执行
3. 每步验证
4. 失败则回滚

### 质量评分

每个阶段完成后评分 (0-10):

| 维度 | 分值 | 说明 |
|------|------|------|
| 目标明确性 | 0-3 | 需求是否清晰 |
| 预期结果 | 0-3 | 产出是否明确 |
| 边界范围 | 0-2 | 范围是否界定 |
| 约束条件 | 0-2 | 限制是否明确 |

**止损规则**:
- ≥7 分: 继续下一阶段
- <7 分: 停止，补充信息

---

## 状态机

### Agent 状态转换

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

### 状态说明

| 状态 | 说明 | 触发条件 |
|------|------|----------|
| IDLE | 空闲，等待任务 | 初始状态 / 任务完成 |
| WORKING | 工作中 | 接收到任务 |
| WAITING_CONFIRM | 等待用户确认 | 需要用户输入 |
| COMPLETED | 任务完成 | 工作完成 |
| REVIEWING | 代码审查中 | 完成后自动触发 |
| TESTING | 测试中 | 审查通过 |
| COMMITTING | 提交中 | 测试通过 |
| FAILED | 失败 | 审查/测试失败 |
| ERROR | 异常 | 执行错误 |

---

## 数据架构

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

### 任务状态

```
openclaw:task:{id}:status          # pending|planning|executing|reviewing|done|failed
openclaw:task:{id}:plan            # 计划内容 (JSON)
openclaw:task:{id}:progress        # 当前进度 (步骤号)
openclaw:task:{id}:agent           # 分配的 agent
openclaw:task:{id}:score           # 质量评分
```

### 工作流状态

```
openclaw:workflow:current          # 当前工作流 ID
openclaw:workflow:{id}:phase       # 当前阶段 (1-6)
openclaw:workflow:{id}:tasks       # 任务列表
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

---

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

---

## 智能决策

### 任务分配

1. 检查 `openclaw:learn:agent_skills` 获取 agent 擅长领域
2. 检查当前负载，优先分配给空闲 agent
3. 考虑任务依赖关系
4. 记录分配决策，用于后续学习

### 错误恢复

1. 检查 `openclaw:learn:errors` 是否有已知解决方案
2. 尝试已知方案
3. 失败则记录新错误，升级给用户
4. 成功则更新解决方案库

### 效率优化

1. 分析 `openclaw:stats` 识别瓶颈
2. 调整任务分配策略
3. 记录优化效果

### 死锁检测

**检测方式**: tmux 会话活动时间分析

**死锁阈值**: > 5 分钟无活动

**恢复流程**:
1. 发送 Ctrl+C 中断卡死会话
2. 重新派活任务
3. 验证恢复状态
4. 记录到 Redis: `openclaw:deadlock:recovery`

---

## 任务分解 (WBS)

### 分解层级

```
Level 1: 功能 (Feature)
    ↓
Level 2: 模块 (Module)
    ↓
Level 3: 文件 (File)
    ↓
Level 4: 任务 (Task)
```

### 任务模板

```markdown
## 任务: <任务名>

**类型**: 前端/后端/全栈
**分配**: Claude/Gemini/Codex
**预估**: X 任务点 (1点 ≈ 1-2小时)

### 输入
- <依赖的数据/前置任务>

### 输出
- <产出的结果>

### 步骤
1. <具体步骤>
2. <具体步骤>

### 验收标准
- [ ] <标准1>
- [ ] <标准2>
```

---

## 代码审查

### 审查报告模板

```markdown
## 审查报告

### Critical (必须修复)
- <问题描述>

### Major (应该修复)
- <问题描述>

### Minor (建议修复)
- <问题描述>

### 总体评价
- 代码质量: [优秀/良好/需改进]
- 是否可合并: [是/否/需修复后]
```

---

## 与定时任务集成

| 任务 | 角色 | 职责 |
|------|------|------|
| 🔄 流水线 | 工作流引擎 | 驱动 6 阶段流程 |
| 🎯 指挥官 | 战略规划 | WBS 分解，任务分配 |
| 👁️ 状态感知 | 监控 | 检测状态变化 |
| 🔍 代码审查 | 质量把关 | 审核代码质量 |
| ✅ 任务验收 | 验收 | 验证完成标准 |

### 事件流

```
用户需求 → 指挥官(WBS分解) → 任务队列
                ↓
        流水线(分配执行)
                ↓
    Agent完成 → 状态感知(检测) → 事件队列
                ↓
        流水线(触发审查)
                ↓
    代码审查 → 通过? → 是 → 流水线(触发测试)
                ↓ 否          ↓
           返回修改      测试通过? → 是 → 流水线(提交)
                              ↓ 否
                         返回修复
```

---

## 版本历史

- **v3.0** (2026-02-01): 整合指挥官架构和流水线架构
- **v2.0** (2026-02-01): 添加死锁检测与恢复机制
- **v1.0** (2026-02-01): 初始版本
