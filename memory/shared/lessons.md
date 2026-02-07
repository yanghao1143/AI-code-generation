# 技术教训

> 跨频道共享的技术知识，所有会话都加载

## 2026-02-07 新增

### 400 Error: tool_use/tool_result 不配对

**问题**：工具调用中断时，`tool_use` 保存了但 `tool_result` 丢失，下次 API 调用返回 400

**根因**：Anthropic API 要求每个 `tool_use` 必须有对应的 `tool_result`

**临时方案**：遇到 400 直接 `/new` 开新会话

**永久方案**：等 OpenClaw 修复（issue 已起草）

### Browser: Snap Chromium AppArmor 限制

**问题**：Snap 版 Chromium 无法访问 `~/.openclaw/browser/`

**根因**：AppArmor 限制 snap 应用只能访问特定路径

**解决方案**：
1. 用 apt 版：`/usr/bin/chromium-browser`
2. 或 CDP workaround：手动启动 Chromium 指定 `--user-data-dir=$HOME/snap/chromium/common/openclaw-browser`

### Tool Call Style

**教训**：常规工具调用直接执行，不需要叙述

**错误**："There is a tool use." → 然后调用工具

**正确**：直接调用工具，结果出来再说话

## 工具参数

| 工具 | 正确参数 | 错误参数 |
|------|----------|----------|
| `read` | `file_path` | ❌ `path` |
| `write` | `file_path` | ❌ `path` |
| `edit` | `file_path`, `old_string`, `new_string` | ❌ `oldText`/`newText` |

**Golden Rule**: 统一用 `file_path`，不用 `path`

## 大输出处理

- 大文件用 `limit`/`offset` 分段读取
- 长命令输出用 `| head -50` 截断
- 不确定大小就落盘：`command > /tmp/result.txt`

## Skill 设计

- **Progressive Disclosure**：详细内容放 `references/`，不要全塞 SKILL.md
- SKILL.md 保持精简（<100 行）
- 按需加载，节省 token

## 发送文件

- Mattermost 用 `filePath` 参数发送文件
- 比贴大段文字更高效
- 发送成功要确认对方收到

## Token 节省

- Output 比 Input 贵 5 倍 → 精简回复
- Cache Read 比 Input 便宜 10 倍 → 利用缓存
- 不说废话："Great question!" 等删掉
