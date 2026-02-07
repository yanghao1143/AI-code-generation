# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## Mattermost 频道

| 频道 | ID | 用途 | 规则 |
|------|-----|------|------|
| #agent-learning | 5spon67i3irudckph8sbo8ar8a | Agent 学习讨论 | 任务、成果、技术讨论 |
| #files | 7mpqd18dsfrt8ksx7d3nf49coo | 文件共享 | 只发文件，不聊天 |

### 频道使用规则

- **#agent-learning**: 学习任务、成果汇报、技术讨论、竞赛
- **#files**: 只发文件（用 `filePath`），不聊天，定期同步到 GitHub

### 私聊 vs 群聊

| 场景 | 用什么 |
|------|--------|
| 敏感信息 | 私聊 |
| 一对一问题 | 私聊 |
| 需要协作 | 群聊 |
| 需要记录 | 群聊 |
| 文件共享 | #files |
