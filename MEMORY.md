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

### 2026-02-01 22:02 - Agent 效率分析完成
- **分析周期**: 4h 45m (18:17 - 22:02)
- **总体效率**: 中等 (⭐⭐)
- **产出量**: 7 任务 / 4.75h (⭐⭐⭐)
- **等待时间**: 66.7% 被阻塞 (⭐ ❌)
- **完成率**: 65.7% (⭐⭐)
- **Context 效率**: 79% 平均 (⭐⭐⭐)

**Agent 排名**:
- 产出效率: Gemini (5任务) > Claude (2任务) > Codex (2任务)
- 稳定性: Claude (0%等待) > Gemini/Codex (100%等待)
- Context 效率: Claude (70%) > Codex (77%) > Gemini (90%)

**关键问题**:
1. ❌ 用户交互阻塞 (66.7%) - Gemini 等待 findstr 确认, Codex 等待 PowerShell 确认
2. ⚠️ Gemini context 接近满 (90%) - 需要立即重启会话
3. 📉 任务分配不均衡 - Codex 产出最低且被阻塞

**优化建议**:
- 立即: 自动化用户确认, 重启 Gemini, 手动确认 Codex
- 短期: 改进任务分配, 监控 context, 并行化处理
- 长期: 自动化确认机制, context 自动管理, 智能任务分配

**生成文件**:
- AGENT_STATUS.md - 详细效率分析报告
- AGENT_OPTIMIZATION.md - 优化建议和实施方案
- AGENT_ANALYSIS_SUMMARY.txt - 最终报告
- Redis 缓存: openclaw:agent:efficiency (12个指标)
