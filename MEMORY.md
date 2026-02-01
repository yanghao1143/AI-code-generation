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

### 2026-02-01 22:08 - 🔴 死锁检测与恢复完成 (第一次)
- **检测方式**: tmux 会话活动时间分析
- **死锁阈值**: > 5 分钟无活动
- **检测结果**: 3 个会话全部死锁 (230 分钟无活动)
  - claude-agent: 等待编辑确认
  - codex-agent: 等待 PowerShell 确认
  - gemini-agent: 等待 findstr 确认

**恢复操作**:
1. ✅ 发送 Ctrl+C 中断所有卡死会话
2. ✅ 重新派活，给每个 agent 新的指令
3. ✅ 验证所有 agent 恢复工作状态

**恢复结果**:
- 检测到的死锁: 3 个
- 成功恢复: 3 个 (100%)
- 总恢复时间: ~10 秒
- 当前状态: 所有 agent 已恢复工作

**根本原因**: 三个 agent 都在等待用户确认，导致长时间无活动。这是之前效率分析中发现的"用户交互阻塞"问题的具体表现。

**改进建议**:
- 实现自动化确认机制，避免长时间等待
- 为等待用户确认的操作设置超时
- 定期检查 agent 状态，及时发现和恢复死锁
- 使用任务队列管理 agent 工作

**生成文件**:
- DEADLOCK_RECOVERY_2026-02-01.md - 详细恢复报告
- Redis 缓存: openclaw:deadlock:recovery (恢复事件记录)

### 2026-02-01 22:17 - 🔴 死锁检测与恢复完成 (第二次 - Cron 定期检测)
- **检测时间**: 2026-02-01 22:17:19 CST
- **检测方式**: Cron 定期任务 (socket 修改时间分析)
- **死锁阈值**: > 5 分钟无活动
- **检测结果**: 3 个会话全部死锁 (15165 秒 = 252.75 分钟无活动)
  - claude-agent: 进程活跃但无响应
  - codex-agent: 进程活跃但无响应
  - gemini-agent: 进程活跃但无响应

**恢复操作**:
1. ✅ 发送 Ctrl+C 中断所有卡死会话 (3 个)
2. ✅ 重新派活，给每个 agent 新的指令 (echo + pwd)
3. ✅ 验证所有 agent 恢复工作状态

**恢复结果**:
- 检测到的死锁: 3 个
- 成功恢复: 3 个 (100%)
- 总恢复时间: ~15 秒
- 当前状态: 所有 agent 已恢复工作并响应新命令

**Socket 状态**:
- Socket 路径: /tmp/openclaw-agents.sock
- 最后活动时间: 15165 秒前 (约 4.2 小时)
- 所有 pane 进程: ALIVE

**Redis 记录**:
- 恢复事件: openclaw:deadlock:recovery:2026-02-01_22-17-19
- 统计更新: openclaw:deadlock:stats (total_recoveries: 1, successful_recoveries: 1)

### 2026-02-01 22:18 - 📊 上下文溢出监控 (Cron 定期检测)
- **监控时间**: 2026-02-01 22:18:09 CST
- **检测方式**: Redis 缓存数据分析

**Context 使用率**:
- Claude: 70% (剩余 30%) ✅ 安全
- Gemini: 90% (剩余 10%) 🔴 **警告** - 接近满载
- Codex: 77% (剩余 23%) ✅ 安全

**紧急警告**:
- Gemini Agent 剩余容量仅 10%，已达到警告阈值
- 当前被阻塞 100%，可能导致 context 溢出
- **建议立即重启 Gemini 会话**

**Redis 记录**:
- 监控数据: openclaw:context:monitor:2026-02-01_22-18
- 包含所有 agent 的 context 使用率和状态
