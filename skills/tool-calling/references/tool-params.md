# Tool Parameters Reference

Complete parameter reference for OpenClaw tools.

## File Operations

### read

Read file contents.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `file_path` | ✅ | Path to file |
| `offset` | ❌ | Start line (1-indexed) |
| `limit` | ❌ | Max lines to read |

```xml
<invoke name="read">
  <parameter name="file_path">/path/to/file.md</parameter>
  <parameter name="limit">100</parameter>
</invoke>
```

### write

Create or overwrite file.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `file_path` | ✅ | Path to file |
| `content` | ✅ | Content to write |

```xml
<invoke name="write">
  <parameter name="file_path">/path/to/file.md</parameter>
  <parameter name="content">File content here</parameter>
</invoke>
```

### edit

Replace exact text in file.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `file_path` | ✅ | Path to file |
| `old_string` | ✅ | Exact text to find |
| `new_string` | ✅ | Replacement text |

```xml
<invoke name="edit">
  <parameter name="file_path">/path/to/file.md</parameter>
  <parameter name="old_string">old text</parameter>
  <parameter name="new_string">new text</parameter>
</invoke>
```

**Critical:** `old_string` must match exactly, including:
- Whitespace (spaces, tabs)
- Line endings
- Indentation

## Command Execution

### exec

Run shell command.

| Parameter | Required | Description |
|-----------|----------|-------------|
| `command` | ✅ | Shell command |
| `workdir` | ❌ | Working directory |
| `timeout` | ❌ | Timeout in seconds |
| `background` | ❌ | Run in background |

```xml
<invoke name="exec">
  <parameter name="command">ls -la</parameter>
  <parameter name="workdir">/home/user</parameter>
</invoke>
```

## Output Size Guidelines

| Expected Output | Strategy |
|-----------------|----------|
| < 100 lines | Direct output OK |
| 100-500 lines | Use `limit` parameter |
| > 500 lines | Write to file, then read with limit |

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| `path` | `file_path` |
| `old_text` | `old_string` |
| `new_text` | `new_string` |
| `file` | `file_path` |
