# TOOLS-CHEATSHEET.md - 常用工具参数速查

> 快速参考，避免参数名写错

## 文件操作

### read

| 参数 | 必填 | 说明 |
|------|------|------|
| `file_path` 或 `path` | ✅ | 文件路径 |
| `offset` | ❌ | 起始行号（从1开始） |
| `limit` | ❌ | 读取行数 |

### write

| 参数 | 必填 | 说明 |
|------|------|------|
| `file_path` 或 `path` | ✅ | 文件路径 |
| `content` | ✅ | 文件内容 |

### edit

| 参数 | 必填 | 说明 |
|------|------|------|
| `file_path` 或 `path` | ✅ | 文件路径 |
| `oldText` 或 `old_string` | ✅ | 要替换的原文（必须精确匹配） |
| `newText` 或 `new_string` | ✅ | 替换后的新文本 |

## 执行命令

### exec

| 参数 | 必填 | 说明 |
|------|------|------|
| `command` | ✅ | 要执行的命令 |
| `workdir` | ❌ | 工作目录 |
| `timeout` | ❌ | 超时秒数 |
| `background` | ❌ | 后台运行 |

### process

| 参数 | 必填 | 说明 |
|------|------|------|
| `action` | ✅ | list / poll / log / write / send-keys / kill |
| `sessionId` | 视action | 会话ID |

## 常见错误

| 错误 | 原因 | 修正 |
|------|------|------|
| `missing required args: file_path` | 用了 `path` 但工具需要 `file_path` | 统一用 `file_path` |
| `missing required args: content` | write 少传了内容 | 确保 content 参数有值 |
| `oldText not found` | edit 的匹配文本不精确 | 复制原文，注意空格和换行 |

**记住：不确定就查这个表！**
