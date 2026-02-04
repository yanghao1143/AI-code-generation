# 三模型协作系统 - 最终架构 v4.0

> 整合 ccg-workflow + claude-code-workflow 的最佳实践

## 核心理念整合

### 来自 ccg-workflow
1. **6 阶段工作流**: 研究 → 构思 → 计划 → 执行 → 优化 → 评审
2. **规划与执行分离**: `/plan` 只规划，`/execute` 只执行
3. **信任规则**: 后端听 Claude，前端听 Gemini，修复听 Codex
4. **零写入权限**: 外部 agent 只返回 Patch，由编排者审核后执行
5. **止损机制**: 质量评分 <7 分强制停止

### 来自 claude-code-workflow
1. **多智能体头脑风暴**: 多角色并行分析 (系统架构师、产品经理、UX专家等)
2. **JSON 优先架构**: 任务状态用 JSON 作为唯一真实数据源
3. **10 任务限制**: 防止任务过载，强制重新规划
4. **文件内聚**: 相关文件必须在同一任务中，防止冲突
5. **会话管理**: 完整的会话生命周期 (start/pause/resume/complete)
6. **综合报告**: 多角色分析后生成综合规范文档

## 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    OpenClaw (指挥官/编排者)                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    会话管理层                            │   │
│  │  session:start → session:pause → session:resume         │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    头脑风暴层                            │   │
│  │  系统架构师 | 产品经理 | UX专家 | 数据架构师 → 综合报告    │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    规划层                               │   │
│  │  需求分析 → WBS分解 → 任务生成 → 依赖分析                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    执行层                               │   │
│  │  任务分配 → 进度追踪 → 代码审查 → 质量验收                 │   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│         Claude CLI              │         Gemini CLI            │
│    (后端/逻辑/算法权威)          │    (前端/UI/设计权威)          │
├─────────────────────────────────────────────────────────────────┤
│                         Codex CLI                               │
│                    (修复/测试/清理权威)                          │
└─────────────────────────────────────────────────────────────────┘
```

## 工作流设计

### 完整工作流 (8 阶段)

```
1. 会话启动 (Session Start)
   └── 创建工作目录，初始化状态

2. 头脑风暴 (Brainstorm) [可选]
   ├── 多角色并行分析
   │   ├── 系统架构师: 技术架构、可扩展性
   │   ├── 产品经理: 业务价值、优先级
   │   ├── UX专家: 用户体验、交互设计
   │   └── 数据架构师: 数据模型、存储策略
   └── 综合报告: 整合所有角色观点

3. 研究 (Research)
   ├── 需求分析
   ├── 上下文检索
   └── 完整性评分 (≥7分继续)

4. 构思 (Ideate)
   ├── 多模型并行分析
   ├── 方案对比
   └── 交叉验证

5. 计划 (Plan)
   ├── WBS 任务分解
   ├── 依赖分析
   ├── 10 任务限制检查
   └── 保存计划文件

6. 执行 (Execute)
   ├── 智能任务分配
   ├── 进度追踪
   └── 里程碑检查

7. 优化 (Optimize)
   ├── 代码审查 (Critical/Major/Minor)
   ├── 性能优化
   └── 安全检查

8. 评审 (Review)
   ├── 质量验收
   ├── 测试验证
   └── 文档更新
```

### 任务管理

#### 任务状态机
```
pending → active → completed
           ↓
         blocked → active (解除阻塞)
           ↓
         failed → active (重试)
```

#### 任务层级 (最多 2 级)
```
IMPL-1 (父任务/容器)
├── IMPL-1.1 (子任务)
├── IMPL-1.2 (子任务)
└── IMPL-1.3 (子任务)
```

#### 10 任务限制
- 总任务数不能超过 10
- 超过时强制重新规划
- 防止任务过载

#### 文件内聚规则
- 相关文件必须在同一任务中
- 检测文件冲突
- 检测功能重叠

## 数据结构

### 会话状态 (JSON)
```json
{
  "session_id": "WFS-user-auth",
  "status": "active",
  "current_phase": "EXECUTE",
  "created_at": "2026-02-01T22:00:00Z",
  "phases": {
    "BRAINSTORM": { "status": "completed", "roles": ["system-architect", "product-manager"] },
    "PLAN": { "status": "completed", "task_count": 8 },
    "EXECUTE": { "status": "in_progress", "completed": 3, "total": 8 },
    "REVIEW": { "status": "pending" }
  },
  "task_stats": {
    "total": 8,
    "completed": 3,
    "failed": 0,
    "blocked": 1
  }
}
```

### 任务状态 (JSON)
```json
{
  "id": "IMPL-1",
  "title": "Build authentication module",
  "type": "feature",
  "status": "active",
  "agent": "claude-agent",
  "context": {
    "requirements": ["JWT authentication", "OAuth2 support"],
    "scope": ["src/auth/*"],
    "acceptance": ["Module handles JWT tokens"]
  },
  "relations": {
    "parent": null,
    "subtasks": ["IMPL-1.1", "IMPL-1.2"],
    "dependencies": []
  },
  "implementation": {
    "files": [
      {
        "path": "src/auth/login.ts",
        "modifications": {
          "current_state": "Basic password auth",
          "proposed_changes": ["Add JWT generation", "Add OAuth2"]
        }
      }
    ]
  }
}
```

### Redis 状态
```
# 会话
openclaw:session:current = "WFS-user-auth"
openclaw:session:{id}:status = "active"
openclaw:session:{id}:phase = "EXECUTE"

# 任务
openclaw:task:{id}:status = "active"
openclaw:task:{id}:agent = "claude-agent"
openclaw:task:{id}:progress = 60

# 事件队列
openclaw:events:queue = [event1, event2, ...]

# 学习系统
openclaw:learn:agent_skills = {claude: "后端", gemini: "前端", codex: "修复"}
openclaw:learn:errors = {pattern: solution}
```

## 智能体角色

### 头脑风暴角色
| 角色 | 职责 | 关注点 |
|------|------|--------|
| 系统架构师 | 技术架构 | 可扩展性、性能、集成 |
| 产品经理 | 业务价值 | 优先级、ROI、用户需求 |
| UX专家 | 用户体验 | 交互设计、可用性 |
| 数据架构师 | 数据模型 | 存储策略、数据流 |
| Scrum Master | 项目管理 | 任务分解、风险管理 |

### 执行角色
| 角色 | 分配给 | 任务类型 |
|------|--------|----------|
| 规划智能体 | OpenClaw | 设计、规划、架构 |
| 代码开发者 | Claude/Gemini/Codex | 实现、构建 |
| 代码审查者 | OpenClaw | 审查、测试 |
| 审核智能体 | OpenClaw | 质量验收 |

## 质量保证

### 评分机制 (0-10)
| 维度 | 分值 | 说明 |
|------|------|------|
| 目标明确性 | 0-3 | 需求是否清晰 |
| 预期结果 | 0-3 | 产出是否明确 |
| 边界范围 | 0-2 | 范围是否界定 |
| 约束条件 | 0-2 | 限制是否明确 |

**止损规则**: ≥7 分继续，<7 分停止

### 代码审查分类
- **Critical**: 必须修复才能合并
- **Major**: 应该修复
- **Minor**: 建议修复
- **Suggestion**: 可选优化

### 验收标准
- [ ] 所有任务完成
- [ ] 测试通过
- [ ] 代码审查通过
- [ ] 文档更新

## 错误处理

### 失败恢复
```
失败 → 查询学习库 → 有方案? → 执行方案 → 成功? → 记录方案
                      ↓ 无                    ↓ 失败
                   通用恢复 ────────────────→ 汇报用户
```

### 冲突处理
1. 检测多 agent 改同一文件
2. 暂停后来者
3. 协调分工
4. 恢复执行

## 文档结构

```
.workflow/
├── WFS-{session}/
│   ├── workflow-session.json    # 会话状态
│   ├── IMPL_PLAN.md             # 实施计划
│   ├── TODO_LIST.md             # 任务清单
│   ├── .task/
│   │   ├── IMPL-1.json          # 任务详情
│   │   └── IMPL-2.json
│   ├── .brainstorming/
│   │   ├── topic-framework.md   # 讨论框架
│   │   ├── system-architect/
│   │   │   └── analysis.md
│   │   ├── product-manager/
│   │   │   └── analysis.md
│   │   └── synthesis-report.md  # 综合报告
│   └── .summaries/
│       └── IMPL-1-summary.md    # 任务总结
```

## 与现有系统集成

### 定时任务映射
| 任务 | 对应功能 |
|------|----------|
| 🔄 流水线 | 工作流引擎 (8阶段) |
| 🎯 指挥官 | 会话管理 + 任务分配 |
| 👁️ 状态感知 | 状态检测 + 事件生成 |
| ⚡ 解卡 | 自动确认 |
| 🚨 异常处理 | 错误恢复 |
| 🔀 冲突检测 | 文件冲突检测 |
| 📊 进度汇报 | 状态报告 |
| 🔍 代码审查 | 质量把关 |
| ⏱️ 效率分析 | 效率优化 |
