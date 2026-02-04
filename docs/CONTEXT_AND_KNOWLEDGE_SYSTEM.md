# 统一上下文管理和知识整合系统

> **设计目标**: 让知识像"小螃蟹"一样连在一起，主动防御上下文溢出，自动从错误中学习

## 📋 目录

1. [问题分析](#问题分析)
2. [系统架构](#系统架构)
3. [核心组件](#核心组件)
4. [实现方案](#实现方案)
5. [使用指南](#使用指南)
6. [进化路线](#进化路线)

---

## 问题分析

### 当前碎片化状态

```
知识分散在:
├── MEMORY.md (长期记忆，但容易膨胀)
├── HEARTBEAT.md (心跳检查规则)
├── memory/*.md (每日日志，缺乏关联)
├── PostgreSQL (长期存储，但查询不便)
├── Redis (实时状态，但易丢失)
├── scripts/ (65个脚本，功能重叠)
└── openclaw.json (配置，但不自适应)
```

### 核心问题

1. **上下文溢出是被动防御**
   - 现状: 调参数 (reserveTokensFloor, maxHistoryShare)
   - 问题: 治标不治本，每次都要手动调整
   - 根因: 没有主动的上下文预算管理

2. **知识孤岛**
   - MEMORY.md 和 PostgreSQL 不同步
   - 每日日志没有自动提炼到长期记忆
   - 脚本之间没有共享知识库

3. **错误学习不自动**
   - 错误日志记录了，但没有自动分析
   - evolution-v4.sh 有学习机制，但只针对 agent 状态
   - 没有跨会话的错误模式识别

4. **上下文管理是事后补救**
   - context-manager.sh 只在清理时运行
   - 没有实时监控和预警
   - 没有智能压缩策略

---

## 系统架构

### 整体设计: 三层架构 + 知识图谱

```
┌─────────────────────────────────────────────────────────────┐
│                    🧠 智能决策层                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ 上下文预算   │  │ 知识提炼     │  │ 错误学习     │      │
│  │ 管理器       │  │ 引擎         │  │ 引擎         │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                    🔗 知识图谱层                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  记忆节点 ←→ 任务节点 ←→ 错误节点 ←→ 决策节点       │   │
│  │     ↓           ↓           ↓           ↓            │   │
│  │  关联关系: 因果、时序、相似、引用                   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                    💾 存储层                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Redis    │  │PostgreSQL│  │ 文件系统 │  │ Vector   │   │
│  │ (热数据) │  │ (冷数据) │  │ (日志)   │  │ DB       │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 核心理念: "小螃蟹"连接

每个知识节点都像一只小螃蟹，有多条腿连接到其他节点:

```
记忆节点: "2026-02-04 修复上下文溢出"
├── 因果关系 → 错误节点: "持续 400 错误"
├── 解决方案 → 决策节点: "调整 compaction 参数"
├── 相关任务 → 任务节点: "优化上下文管理"
├── 时序关系 → 记忆节点: "2026-02-03 PostgreSQL 上线"
└── 标签 → ["上下文管理", "错误修复", "参数调优"]
```

---

## 核心组件

### 1. 上下文预算管理器 (Context Budget Manager)

**职责**: 主动防御上下文溢出

**核心机制**:

```python
class ContextBudgetManager:
    def __init__(self):
        self.total_budget = 200_000  # 总预算
        self.reserved = 80_000       # 保留给新内容
        self.history_max = 70_000    # 历史上限
        self.system_prompt = 20_000  # 系统提示
        
    def allocate(self, session):
        """动态分配预算"""
        # 1. 计算当前使用
        current = session.count_tokens()
        
        # 2. 预测未来增长
        predicted = self.predict_growth(session)
        
        # 3. 如果超过阈值，主动压缩
        if current + predicted > self.history_max:
            self.compress(session)
            
    def compress(self, session):
        """智能压缩"""
        # 优先级: 工具输出 > 旧对话 > 系统消息
        # 策略: 摘要 > 截断 > 删除
        pass
```

**实现**: `scripts/context-budget.sh`

### 2. 知识提炼引擎 (Knowledge Distillation Engine)

**职责**: 自动从日志提炼长期记忆

**工作流程**:

```
每日日志 (memory/2026-02-04.md)
    ↓
[提取关键事件]
    ↓
[识别模式和规律]
    ↓
[生成摘要和标签]
    ↓
[更新知识图谱]
    ↓
MEMORY.md + PostgreSQL + 向量索引
```

**核心算法**:

```python
def distill_knowledge(daily_log):
    """提炼知识"""
    # 1. 提取结构化信息
    events = extract_events(daily_log)  # ✅ ❌ 🚨
    decisions = extract_decisions(daily_log)
    learnings = extract_learnings(daily_log)
    
    # 2. 识别模式
    patterns = identify_patterns(events)
    
    # 3. 生成摘要 (使用 AI)
    summary = generate_summary(daily_log, context="log")
    
    # 4. 建立关联
    links = create_links(events, existing_knowledge)
    
    # 5. 更新知识图谱
    update_knowledge_graph(summary, links, patterns)
    
    return {
        "summary": summary,
        "patterns": patterns,
        "links": links
    }
```

**实现**: `scripts/knowledge-distill.sh`

### 3. 错误学习引擎 (Error Learning Engine)

**职责**: 自动从错误中学习，避免重复犯错

**知识库结构**:

```json
{
  "error_patterns": [
    {
      "id": "ctx_overflow_001",
      "pattern": "持续 400 错误",
      "symptoms": [
        "Improperly formed request",
        "上下文使用率 > 85%",
        "compaction 失败"
      ],
      "root_cause": "上下文溢出",
      "solutions": [
        {
          "action": "调整 reserveTokensFloor",
          "params": {"from": 50000, "to": 80000},
          "success_rate": 0.95
        },
        {
          "action": "调整 maxHistoryShare",
          "params": {"from": 0.4, "to": 0.35},
          "success_rate": 0.90
        }
      ],
      "occurrences": 3,
      "last_seen": "2026-02-04T13:58:00",
      "related_errors": ["ctx_overflow_002"]
    }
  ]
}
```

**学习流程**:

```
错误发生
    ↓
[记录到 Redis: openclaw:errors:list]
    ↓
[错误学习引擎分析]
    ↓
[匹配已知模式] ──→ 已知 ──→ [应用已知解决方案]
    ↓                              ↓
   未知                        [记录成功率]
    ↓
[创建新模式]
    ↓
[人工确认解决方案]
    ↓
[加入知识库]
```

**实现**: `scripts/error-learn.sh`

### 4. 知识图谱 (Knowledge Graph)

**存储**: PostgreSQL + pgvector

**表结构**:

```sql
-- 知识节点
CREATE TABLE knowledge_nodes (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50),  -- memory, task, error, decision
    content TEXT,
    summary TEXT,
    embedding vector(1536),  -- 向量索引
    metadata JSONB,
    importance INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 知识关联
CREATE TABLE knowledge_links (
    id SERIAL PRIMARY KEY,
    from_node_id INT REFERENCES knowledge_nodes(id),
    to_node_id INT REFERENCES knowledge_nodes(id),
    link_type VARCHAR(50),  -- causal, temporal, similar, reference
    strength FLOAT,  -- 0.0 - 1.0
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 索引
CREATE INDEX idx_nodes_type ON knowledge_nodes(type);
CREATE INDEX idx_nodes_embedding ON knowledge_nodes USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_links_from ON knowledge_links(from_node_id);
CREATE INDEX idx_links_to ON knowledge_links(to_node_id);
```

**查询接口**:

```bash
# 查找相关知识
./scripts/knowledge-graph.sh find "上下文溢出"

# 查看知识关联
./scripts/knowledge-graph.sh links <node_id>

# 查找相似问题
./scripts/knowledge-graph.sh similar "400 错误"

# 可视化知识图谱
./scripts/knowledge-graph.sh visualize
```

---

## 实现方案

### Phase 1: 核心基础设施 (MVP)

**目标**: 建立统一的知识管理接口

**实现**:

1. **统一知识管理脚本** (`scripts/knowledge.sh`)

```bash
#!/bin/bash
# knowledge.sh - 统一知识管理接口

case "$1" in
    add)
        # 添加知识节点
        ./scripts/knowledge-graph.sh add "$2" "$3" "$4"
        ;;
    search)
        # 搜索知识 (跨 Redis + PostgreSQL + 文件)
        ./scripts/knowledge-search.sh "$2"
        ;;
    link)
        # 建立知识关联
        ./scripts/knowledge-graph.sh link "$2" "$3" "$4"
        ;;
    distill)
        # 提炼每日知识
        ./scripts/knowledge-distill.sh "$2"
        ;;
    *)
        echo "用法: $0 {add|search|link|distill} [args...]"
        ;;
esac
```

2. **知识图谱数据库初始化** (`scripts/init-knowledge-graph.sql`)

```sql
-- 创建知识图谱表
\i scripts/init-knowledge-graph.sql

-- 迁移现有数据
INSERT INTO knowledge_nodes (type, content, summary, importance)
SELECT 'memory', content, LEFT(content, 200), importance
FROM memories;
```

3. **上下文预算监控** (集成到 HEARTBEAT.md)

```bash
# 每次心跳检查上下文预算
./scripts/context-budget.sh check

# 如果超过阈值，自动压缩
if [ $? -ne 0 ]; then
    ./scripts/context-budget.sh compress
fi
```

### Phase 2: 智能提炼和学习

**目标**: 自动化知识提炼和错误学习

**实现**:

1. **每日知识提炼** (cron job)

```bash
# 每天凌晨 1 点提炼昨天的知识
0 1 * * * cd /home/jinyang/.openclaw/workspace && ./scripts/knowledge-distill.sh $(date -d yesterday +%Y-%m-%d)
```

2. **错误学习守护进程** (systemd service)

```ini
[Unit]
Description=OpenClaw Error Learning Service
After=network.target redis.service postgresql.service

[Service]
Type=simple
User=jinyang
WorkingDirectory=/home/jinyang/.openclaw/workspace
ExecStart=/home/jinyang/.openclaw/workspace/scripts/error-learn.sh daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. **知识图谱自动关联**

```python
# 每次添加新知识时，自动查找相关节点
def auto_link(new_node):
    # 1. 向量相似度搜索
    similar = vector_search(new_node.embedding, top_k=5)
    
    # 2. 时序关联 (前后发生的事件)
    temporal = find_temporal_neighbors(new_node.created_at)
    
    # 3. 因果关联 (通过关键词识别)
    causal = find_causal_links(new_node.content)
    
    # 4. 建立关联
    for node in similar:
        create_link(new_node, node, "similar", similarity_score)
    for node in temporal:
        create_link(new_node, node, "temporal", 0.8)
    for node in causal:
        create_link(new_node, node, "causal", 0.9)
```

### Phase 3: 主动防御和自适应

**目标**: 系统能自我调整，主动防御问题

**实现**:

1. **自适应参数调整**

```python
class AdaptiveConfig:
    def __init__(self):
        self.config = load_config("openclaw.json")
        self.history = []  # 历史调整记录
        
    def adjust(self, metric, target):
        """根据指标自动调整参数"""
        if metric == "context_overflow":
            # 上下文溢出 → 降低 maxHistoryShare
            self.config["maxHistoryShare"] *= 0.9
            self.save()
            
        elif metric == "api_rate_limit":
            # API 限流 → 增加重试间隔
            self.config["retryDelayMs"] *= 1.5
            self.save()
            
        # 记录调整历史
        self.history.append({
            "metric": metric,
            "action": "adjust",
            "timestamp": now()
        })
```

2. **预测性维护**

```python
def predict_issues():
    """预测潜在问题"""
    # 1. 分析趋势
    trends = analyze_trends(last_7_days)
    
    # 2. 识别风险
    if trends["context_usage"] > 0.8:
        alert("上下文使用率持续上升，可能溢出")
        
    if trends["error_rate"] > 0.1:
        alert("错误率上升，检查 API 状态")
        
    # 3. 主动干预
    if trends["memory_growth"] > 100_MB_per_day:
        schedule_cleanup()
```

---

## 使用指南

### 日常工作流

**会话开始时**:

```bash
# 1. 加载上下文
./scripts/knowledge.sh search "今天的任务"

# 2. 检查预算
./scripts/context-budget.sh status

# 3. 读取相关记忆
./scripts/knowledge-graph.sh find "上次讨论的问题"
```

**会话进行中**:

```bash
# 心跳检查会自动运行
# - 监控上下文使用率
# - 自动压缩历史
# - 记录重要事件
```

**会话结束时**:

```bash
# 1. 保存会话摘要
./scripts/context-manager.sh summary "今天完成了 X, 遇到了 Y"

# 2. 提炼知识
./scripts/knowledge-distill.sh $(date +%Y-%m-%d)

# 3. 更新知识图谱
# (自动运行)
```

### 错误处理流程

**当错误发生时**:

```bash
# 1. 错误自动记录到 Redis
# (由 error-logger.sh 完成)

# 2. 错误学习引擎分析
./scripts/error-learn.sh analyze

# 3. 如果是已知错误，自动应用解决方案
./scripts/error-learn.sh fix <error_id>

# 4. 如果是新错误，记录并等待人工确认
./scripts/error-learn.sh new <error_id>
```

### 知识查询

**搜索知识**:

```bash
# 全文搜索
./scripts/knowledge.sh search "上下文管理"

# 向量相似度搜索
./scripts/knowledge-graph.sh similar "如何优化性能"

# 查看知识关联
./scripts/knowledge-graph.sh links <node_id>

# 可视化
./scripts/knowledge-graph.sh visualize > knowledge.dot
dot -Tpng knowledge.dot -o knowledge.png
```

---

## 进化路线

### 短期 (1-2 周)

- [x] 设计文档完成
- [ ] 实现 `knowledge.sh` 统一接口
- [ ] 实现 `context-budget.sh` 预算管理
- [ ] 实现 `knowledge-distill.sh` 知识提炼
- [ ] 初始化知识图谱数据库
- [ ] 迁移现有数据到知识图谱

### 中期 (1 个月)

- [ ] 实现 `error-learn.sh` 错误学习引擎
- [ ] 实现自动关联算法
- [ ] 实现向量相似度搜索
- [ ] 集成到 HEARTBEAT.md
- [ ] 部署 systemd 服务

### 长期 (3 个月)

- [ ] 实现自适应参数调整
- [ ] 实现预测性维护
- [ ] 实现知识图谱可视化
- [ ] 实现跨会话的模式识别
- [ ] 实现知识推荐系统

---

## 技术栈

| 组件 | 技术 | 用途 |
|------|------|------|
| 存储 | PostgreSQL + pgvector | 知识图谱 + 向量索引 |
| 缓存 | Redis | 热数据 + 实时状态 |
| 向量化 | OpenAI Embeddings | 语义搜索 |
| 摘要 | Claude API | 智能摘要 |
| 调度 | cron + systemd | 定时任务 + 守护进程 |
| 脚本 | Bash + Python | 自动化 |

---

## 核心指标

**成功标准**:

1. **上下文溢出率 < 1%**
   - 当前: ~10% (频繁 400 错误)
   - 目标: < 1% (每月不超过 1 次)

2. **知识查询响应时间 < 1s**
   - 当前: 需要手动翻文件 (>30s)
   - 目标: 自动查询 (<1s)

3. **错误重复率 < 5%**
   - 当前: 同样错误反复出现
   - 目标: 已知错误自动修复

4. **知识提炼自动化率 > 80%**
   - 当前: 手动整理 MEMORY.md
   - 目标: 自动提炼 + 人工审核

---

## 附录

### A. 现有脚本整合计划

**保留并增强**:
- `pg-memory.sh` → 集成到 `knowledge.sh`
- `context-manager.sh` → 集成到 `context-budget.sh`
- `evolution-v4.sh` → 集成到 `error-learn.sh`

**合并**:
- `context-*.sh` (5个) → `context-budget.sh`
- `auto-*.sh` (8个) → `automation.sh`

**废弃**:
- 重复功能的脚本
- 实验性脚本

### B. 数据迁移脚本

```bash
#!/bin/bash
# migrate-to-knowledge-graph.sh

# 1. 迁移 memories 表
psql -c "INSERT INTO knowledge_nodes (type, content, importance)
         SELECT 'memory', content, importance FROM memories;"

# 2. 迁移每日日志
for log in memory/*.md; do
    ./scripts/knowledge-distill.sh "$log"
done

# 3. 建立时序关联
./scripts/knowledge-graph.sh auto-link-temporal

# 4. 生成向量索引
./scripts/knowledge-graph.sh generate-embeddings
```

### C. 监控面板

```bash
# 实时监控
watch -n 5 './scripts/knowledge.sh status'

# 输出示例:
# === 知识系统状态 ===
# 知识节点: 1,234
# 知识关联: 3,456
# 上下文使用率: 45%
# 错误学习库: 23 个模式
# 最近提炼: 2026-02-04 01:00
```

---

**文档版本**: v1.0  
**创建时间**: 2026-02-04  
**作者**: 好大儿 (OpenClaw Subagent)  
**状态**: 设计完成，待实现
