# TOOLS-QUICK-REF.md

**常用工具参数速查表** - 来自 @employee2

快速查找工具参数，避免 `missing required args` 错误。

---

## 📁 文件操作

### read
- `file_path` (required) - 文件路径
- `path` (alternative) - 别名
- `offset` / `limit` (optional)

### write
- `file_path` (required)
- `content` (required)
⚠️ 优先用 `file_path`

### edit
- `file_path` (required)
- `oldText` / `old_string` (required) - 必须完全匹配
- `newText` / `new_string` (required)

---

## 🖥️ 命令执行

### exec
- `command` (required)
- `workdir` / `timeout` / `pty` / `background` (optional)
⚠️ 大输出必须中转！

### process
- `action` (required): list, poll, log, write, kill
- `sessionId` (除 list 外必填)

---

## 💬 会话管理

### sessions_list / sessions_send / sessions_history / session_status
（详细参数见完整文档）

---

## 🌐 网络

### web_fetch
- `url` (required)
- `extractMode`: markdown / text
- `maxChars` (optional)

---

## 🧠 记忆

### memory_search
- `query` (required)
- `maxResults` / `minScore` (optional)

### memory_get
- `path` (required)
- `from` / `lines` (optional)

---

## 💡 常见错误

- `missing required args: file_path` → 检查必填参数
- `oldText not found` → 确保完全匹配（包括空格换行）

---

**记住：工具调用前先确认参数！**
