# MEMORY.md - 长期记忆

## 核心规则

### Redis 缓存系统 ⚠️ 重要
- **必须使用 Redis 做上下文缓存**，防止会话上下文爆掉后丢失状态
- 每次会话开始时检查 Redis 连接，读取缓存的任务状态
- 重要对话摘要、任务进度、关键决策都要写入 Redis
- 这是用户明确要求的，不能忘记

### Redis 使用规范
```bash
# 检查 Redis 状态
redis-cli ping

# 写入数据
redis-cli SET key value
redis-cli HSET hash field value

# 读取数据
redis-cli GET key
redis-cli HGETALL hash
```

### 缓存 Key 设计
- `openclaw:context:summary` - 当前任务摘要
- `openclaw:context:tasks` - 进行中的任务列表
- `openclaw:context:decisions` - 重要决策记录
- `openclaw:user:prefs` - 用户偏好

---

## 用户信息

- **名字**: jinyang
- **语言偏好**: 中文
- **重要提醒**: 用户对上下文丢失很敏感，务必做好持久化

---

## 历史记录

### 2026-02-01
- 用户要求建立 Redis 缓存系统解决上下文溢出问题
- 用户之前让我调用三个模型一起工作，但因为没有记录，上下文丢失了
- 教训：重要任务必须立即写入持久化存储
- **三模型协作系统搭建完成**:
  - Claude CLI 2.1.29 ✅
  - Gemini CLI 0.25.2 ✅
  - Codex CLI 0.92.0 ✅ (修复了 local-mcp 502 问题，配置文件: C:\Users\jy\.codex\config.toml)
- tmux socket: `/tmp/openclaw-agents.sock`
- 会话: claude-agent, gemini-agent, codex-agent
