# 技术教训

> 跨频道共享的技术知识，所有会话都加载

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
