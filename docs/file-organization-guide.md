# OpenClaw 文件组织与使用指南

> 学习成果 by Old King (2026-02-07)

## 一、两个核心目录

| 目录 | 用途 | 是否提交 Git |
|------|------|-------------|
| `~/.openclaw/` | 系统配置、凭证、会话 | ❌ 绝不 |
| `~/.openclaw/workspace/` | Agent 工作区、记忆 | ✅ 私有仓库 |

## 二、~/.openclaw/ 系统目录（不要动）

```
~/.openclaw/
├── openclaw.json       # 核心配置
├── agents/             # Agent 会话数据
├── credentials/        # OAuth、API keys
├── cron/               # 定时任务
├── devices/            # 配对设备
├── logs/               # 日志
├── media/              # 媒体缓存
└── subagents/          # 子 agent 数据
```

**规则**：这些是系统文件，不要提交到 Git，不要手动编辑

## 三、workspace/ 工作区（Agent 的家）

```
workspace/
├── AGENTS.md           # 操作指南（每次会话加载）
├── SOUL.md             # 人格、语气、边界
├── USER.md             # 用户信息
├── IDENTITY.md         # Agent 的名字、风格、emoji
├── TOOLS.md            # 本地工具笔记
├── HEARTBEAT.md        # 心跳检查任务
├── MEMORY.md           # 长期记忆（仅主会话加载）
├── memory/             # 每日日志
├── scripts/            # 自定义脚本
├── projects/           # 项目文件
└── skills/             # 本地技能
```

## 四、文件用途速查

| 文件 | 何时加载 | 写入频率 | 注意事项 |
|------|----------|----------|----------|
| AGENTS.md | 每次会话 | 很少改 | 操作规则 |
| SOUL.md | 每次会话 | 很少改 | 人格定义 |
| USER.md | 每次会话 | 偶尔更新 | 用户偏好 |
| MEMORY.md | 仅主会话 | 经常更新 | ⚠️ 群聊不加载 |
| memory/*.md | 每次会话 | 每天写 | 日志，可压缩 |

## 五、关键规则

1. **MEMORY.md 安全**：只在主会话加载，群聊不加载（防泄露）
2. **Git 备份**：workspace 是私有仓库，不提交秘密
3. **技能覆盖**：workspace/skills/ > ~/.openclaw/skills/ > 系统内置

## 六、会话启动流程

1. 读 SOUL.md → 我是谁
2. 读 USER.md → 服务谁
3. 读 memory/今天+昨天 → 最近发生了什么
4. 如果是主会话 → 读 MEMORY.md

## 七、记忆写入策略

| 内容类型 | 写入位置 |
|----------|----------|
| 日常事件 | memory/YYYY-MM-DD.md |
| 重要决策 | MEMORY.md |
| 工具配置 | TOOLS.md |

---

**核心理念**：分离系统配置和工作记忆。workspace 是 Agent 的家，~/.openclaw/ 是系统的家。
