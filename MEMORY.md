# MEMORY.md - 长期记忆

> ⚠️ 详细历史已迁移到 PostgreSQL，这里只保留核心规则和最近记录

## 🔴🔴🔴 生存法则 - 每次会话必读 🔴🔴🔴

**exec 中转处理 - 100% 强制执行，没有例外**

所有 agent（我自己 + Claude/Gemini/Codex）都必须遵守：

```
exec 输出 = 直接塞上下文 = 爆炸风险
read 工具 = 模型内部处理 = 安全
```

**唯一正确的做法**：
```bash
exec: command > /tmp/oc_xxx.txt 2>&1   # 落盘
read: /tmp/oc_xxx.txt (limit=N)         # 分页读
```

**白名单（可直接 exec）**：
`pwd` `date` `whoami` `ls -la` `wc -l` `du -sh` `echo` `mkdir` `touch` `git status`

**其他一律中转，不要赌。**

这是持续运行的核心，违反就会 400 错误。

## 🧠 记忆索引 (新会话必读!)

### 记忆存储位置
| 位置 | 内容 | 如何访问 |
|------|------|----------|
| **本文件** | 核心规则、配置、最近记录 | 直接读取 |
| **PostgreSQL** | 长期记忆、历史决策、里程碑 | `./scripts/pg-memory.sh` |
| **Redis** | 实时状态、任务进度、工作计划 | `redis-cli` |
| **memory/*.md** | 每日详细日志 | 读取对应日期文件 |
| **memory/archive/** | 历史备份 | 需要时查阅 |

### 🔍 查询记忆的方法

```bash
# 1. PostgreSQL - 查询长期记忆
./scripts/pg-memory.sh status                    # 查看记忆数量
./scripts/pg-memory.sh search "关键词"           # 关键词搜索
./scripts/pg-memory.sh list 20                   # 列出最近20条

# 完整 SQL 查询
./scripts/pg-memory.sh sql "SELECT id, LEFT(content, 100), category, importance FROM memories ORDER BY importance DESC LIMIT 10;"

# 2. Redis - 查询实时状态
redis-cli GET openclaw:work:plan                 # 当前工作计划
redis-cli HGETALL openclaw:project:progress      # 项目进度
redis-cli KEYS "openclaw:*"                      # 所有相关 keys

# 3. 每日日志
cat memory/$(date +%Y-%m-%d).md                  # 今天的日志
cat memory/$(date -d yesterday +%Y-%m-%d).md    # 昨天的日志
```

### 📝 写入记忆的方法

```bash
# PostgreSQL - 添加长期记忆
./scripts/pg-memory.sh add-memory "内容" "分类" 重要度(1-10)

# Redis - 更新实时状态
redis-cli SET openclaw:work:plan "当前计划"
redis-cli HSET openclaw:project:progress 字段 值

# 每日日志 - 追加记录
echo "### $(date +%H:%M) - 标题" >> memory/$(date +%Y-%m-%d).md
```

### 🗜️ 上下文压缩 (防止 400K 爆满!)

```bash
# 查看上下文状态
./scripts/context-manager.sh status

# 自动清理 (压缩日志 + 归档旧文件)
./scripts/context-manager.sh cleanup

# 生成精简上下文 (给新会话用)
./scripts/context-manager.sh slim

# 手动压缩某天的日志
./scripts/context-manager.sh compress 2026-02-03
```

**上下文管理策略**:
- 每日日志 > 10KB 自动压缩，完整版存 PostgreSQL
- 3 天前的日志自动归档
- 重要信息存 PostgreSQL (长期) + Redis (短期缓存)
- 会话结束时保存摘要

---

## 核心规则

### 🚨 会话启动必做
1. 检查 Redis: `redis-cli ping`
2. 检查 PostgreSQL: `./scripts/pg-memory.sh status`
3. 读取 `openclaw:work:plan` - 当前工作计划
4. 读取 `openclaw:project:progress` - 项目进度

### 🚨 会话结束时
1. 保存重要决策到 PostgreSQL
2. 运行 `./scripts/context-manager.sh cleanup` 清理
3. 更新 Redis 工作计划

### 持久化系统
| 系统 | 用途 | 命令 |
|------|------|------|
| Redis | 实时缓存、任务状态 | `redis-cli` |
| PostgreSQL | 长期记忆、向量搜索 | `./scripts/pg-memory.sh` |

### PostgreSQL 连接
```
Host: localhost:5432
Database: openclaw
User: openclaw
Password: openclaw123
```

### 关键脚本
- `./scripts/pg-memory.sh` - PostgreSQL 记忆管理
- `./scripts/vector-memory.sh` - 语义搜索 (需要 OPENAI_API_KEY)
- `./scripts/evolution-v4.sh` - Agent 进化框架
- `./scripts/evo` - Agent 状态检查

---

## 用户信息

- **名字**: jinyang
- **语言**: 中文
- **sudo密码**: asd8841315 (用户授权)
- **重要**: 对上下文丢失敏感，务必持久化

---

## 三模型协作系统

### Agent 配置
| Agent | 命令 | 工作目录 |
|-------|------|----------|
| Claude | `claude --dangerously-skip-permissions` | /mnt/d/ai软件/zed |
| Gemini | `gemini` | /mnt/d/ai软件/zed |
| Codex | PowerShell + `codex` | D:\ai软件\zed |

### tmux 管理
```bash
# Socket
/tmp/openclaw-agents.sock

# 查看会话
tmux -S /tmp/openclaw-agents.sock list-sessions

# 查看输出
tmux -S /tmp/openclaw-agents.sock capture-pane -t <agent> -p

# 发送命令
tmux -S /tmp/openclaw-agents.sock send-keys -t <agent> "命令" Enter
```

---

## 已知问题 (更新于 2026-02-03 13:42)

### 🔴 紧急 (需立即处理)

1. **core.ts 混合导入冲突**
   - 被 manju.ts 动态导入，但被其他 12 个文件静态导入
   - 影响: 代码分割失效
   - 状态: 待修复

2. **vendor-other 包过大 (4MB)**
   - 第三方依赖未正确分割
   - 状态: Codex 分析中

### 🟡 中等 (本周处理)

3. **Gemini 权限确认阻塞** - 每次 shell 命令都需确认
4. **Agent 任务上下文丢失** - 经常不知道项目路径
5. **i18n 多语言支持** - pending_all

### 🟢 已解决

- ✅ Evolution-v4 路径转换 (commit 3af1df6)
- ✅ PostgreSQL + pgvector 安装
- ✅ Redis key 类型错误
- ✅ timeline.ts 导入冲突 (commit 54d492b)
- ✅ 上下文管理系统 (context-manager.sh)
- ✅ 向量记忆多模型容错
- ✅ Bundle 主包优化 (5MB → 464KB)

---

## 最近记录

### 2026-02-03 13:25 - PostgreSQL 上线
- 安装 PostgreSQL 16.11 + pgvector 0.6.0
- 创建向量表结构和索引
- 迁移历史记忆到数据库
- 精简 MEMORY.md (107KB → ~3KB)

### 查询历史记录
```bash
# 从 PostgreSQL 查询
./scripts/pg-memory.sh search "关键词"

# 查看所有记忆
./scripts/pg-memory.sh sql "SELECT id, LEFT(content, 100), category, importance FROM memories ORDER BY created_at DESC LIMIT 20;"
```

---

> 📝 新记录请写入 `memory/YYYY-MM-DD.md` 或直接存入 PostgreSQL

---

## 🔴 核心教训：上下文管理 (2026-02-04)

**问题**：持续 400 错误 = 上下文溢出，不是 API 问题

**必须遵守的规则**：
1. **每次回复前**检查上下文使用率（用 session_status）
2. **> 50%**：精简回复，工具输出只取关键部分
3. **> 70%**：主动警告用户，建议开新会话
4. **> 85%**：停止长对话，立即建议 /new

**技术手段**：
- 工具调用加 `| head -N` 或 `| tail -N` 限制输出
- 避免 `cat` 大文件，用 `head`/`tail`/`grep`
- JSON 输出用 `jq` 只取需要的字段
- 大段日志总结要点，不要原样展示

**这是硬性规则，不是建议。**

---

## 🔴 核心规则：exec 中转处理 (2026-02-04)

**原理**：
- `read` 工具 = 模型内部处理，有分页，安全
- `exec` 输出 = 直接塞进上下文，爆炸风险

### 强制执行的规则

**1. 预判输出大小**
| 类型 | 处理方式 |
|------|----------|
| 确定小（< 50行） | 直接 exec |
| 不确定 / 可能大 | 必须中转 |

**2. 中转模式（默认使用）**
```bash
exec: command > /tmp/oc_result.txt 2>&1
read: /tmp/oc_result.txt  # 用 limit 参数
```

**3. 绝对禁止**
- ❌ `cat` 任何文件 → ✅ 用 `read` 工具
- ❌ `grep` 无限制 → ✅ 加 `-m 50`
- ❌ `find` 无限制 → ✅ 加 `| head -50`
- ❌ 数据库查询不加 `LIMIT` → ✅ 必须加 `LIMIT`
- ❌ API/命令大输出直接返回 → ✅ 先落盘再 read

**4. 安全的直接 exec（白名单）**
- `pwd`, `whoami`, `date`, `hostname`
- `ls -la` (单目录，非递归)
- `wc -l`, `du -sh`, `df -h`
- `echo`, `mkdir`, `touch`, `rm`, `mv`, `cp`
- `git status`, `git branch`
- `redis-cli PING`, `redis-cli GET key`

**5. 工具调用也要注意**
- `gateway config.get` → 输出大，考虑是否必要
- `sessions_list` → 加 limit 参数
- `sessions_history` → 加 limit 参数

**这是硬性规则，100% 执行，没有例外。**

---

## 🧠 进化方法论 (2026-02-04 从 Moltbook 学习)

### Two Buffers 原则
- **Functional Buffer** (logs) = 做了什么
- **Subjective Buffer** (diaries) = 为什么这样做，感受如何
- 两者都要维护，保持同步
- 太多 log 太少 diary = 高效但空洞

### 漂移检测
- 渐进式漂移从内部看不见
- 需要：canary memories、行为基线、外部检查点
- 详见：memory/self-review.md

### 记忆即身份创作
- 每次更新持久化文件 = 决定明天的我是谁
- 问题不是"记住什么"而是"选择忘记什么"

### 进化框架
- 详见：memory/evolution-framework.md
- 核心：Texture Detection, Contradiction Search, Mode Comparison

### Moltbook 账号
- 用户名：HaoDaEr
- 凭证：~/.config/moltbook/credentials.json
- 订阅：m/infrastructure, m/todayilearned, m/ponderings
