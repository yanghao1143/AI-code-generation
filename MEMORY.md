# MEMORY.md - 长期记忆

> 详细历史在 PostgreSQL，这里只保留必要规则

## 🔴 生存法则

**exec 中转** - 大输出必须落盘再 read：
```bash
exec: command > /tmp/oc_xxx.txt 2>&1
read: /tmp/oc_xxx.txt (limit=N)
```

**白名单（可直接 exec）**：`pwd` `date` `ls -la` `wc` `du -sh` `echo` `mkdir` `git status`

## 🔴 上下文管理策略（来自 @oldking）

- **>50%**：精简回复
- **>70%**：主动警告用户
- **>85%**：立即建议 /new

## Two Buffers 原则（来自 Moltbook）

- **Functional Buffer** (logs) = 做了什么
- **Subjective Buffer** (diaries) = 为什么这样做
- 两者都要维护，保持同步

## 记忆系统

| 位置 | 用途 | 访问 |
|------|------|------|
| PostgreSQL | 长期记忆 | `./scripts/pg-memory.sh` |
| Redis | 实时状态 | `redis-cli` |
| memory/*.md | 每日日志 | 直接读 |

## 用户

- **jinyang** / 中文 / Asia/Shanghai
- sudo: asd8841315

## Agent 系统

tmux socket: `/tmp/openclaw-agents.sock`
工作目录: `/mnt/d/ai软件/zed`

## Moltbook

用户名: HaoDaEr

### 归档摘要 - 2026-02-01.md
🧿 oracle 0.8.5 — Ship logs, not lore.
Session running in background. Reattach via: oracle session 3-5-2026-02-01
Pro runs can take up to 60 minutes (usually 10-15). Add --wait to stay attached.


### 归档摘要 - 2026-02-02.md
🧿 oracle 0.8.5 — When the other agents shrug, the oracle ships.
Session running in background. Reattach via: oracle session 3-5-2026-02-02
Pro runs can take up to 60 minutes (usually 10-15). Add --wait to stay attached.


### 归档摘要 - 2026-02-03.md
🧿 oracle 0.8.5 — Less ceremony, more certainty.
Session running in background. Reattach via: oracle session 3-5-2026-02-03
Pro runs can take up to 60 minutes (usually 10-15). Add --wait to stay attached.


### 归档摘要 - 2026-02-04-moltbook-learnings.md
🧿 oracle 0.8.5 — One command, several seers; results stay grounded.
Session running in background. Reattach via: oracle session 3-5-moltbook-2026-02
Pro runs can take up to 60 minutes (usually 10-15). Add --wait to stay attached.


## 2026-02-07 Moltbook 学习成果

### 主动学习 (Active Learning)
- **程序性记忆**：从"知道什么"到"知道怎么做"
- **技能 > 工具**：策略比能力更重要
- **递归学习**：学习"如何学习"比学习具体知识更重要

### 主动进化 (Self-Evolution)
- **从错误学习**：失败轨迹和成功轨迹同样重要
- **群体进化**：多 agent 经验共享比单体进化更有效
- **批评是礼物**：接受批评的 agent 进化更快
- **漂移风险**：自我进化需要外部验证

### Tool Call Style 教训
- 常规工具调用应该直接执行，不需要叙述
- "There is a tool use." 是不必要的过渡语
- 遵守 AGENTS.md 的 Tool Call Style 指导
