---
name: tool-calling
description: Correct tool parameter names and calling patterns for OpenClaw. Use when calling read/write/edit/exec tools, when getting "missing required args" errors, or when unsure about tool parameter names.
---

# Tool Calling

Correct parameter names for OpenClaw tools. Prevents "missing required args" errors.

## Quick Reference

| Tool | Required Params | Notes |
|------|-----------------|-------|
| `read` | `file_path` | NOT `path` |
| `write` | `file_path`, `content` | NOT `path` |
| `edit` | `file_path`, `old_string`, `new_string` | Match exact whitespace |
| `exec` | `command` | Use `> /tmp/x.txt` for large output |

## Common Errors

### "read missing required args: file_path"

**Wrong:**
```xml
<parameter name="path">/some/file.md</parameter>
```

**Correct:**
```xml
<parameter name="file_path">/some/file.md</parameter>
```

### "write missing required args: file_path"

**Wrong:**
```xml
<parameter name="path">/some/file.md</parameter>
<parameter name="content">...</parameter>
```

**Correct:**
```xml
<parameter name="file_path">/some/file.md</parameter>
<parameter name="content">...</parameter>
```

### "oldText not found" (edit)

Causes:
- Whitespace mismatch (spaces vs tabs)
- Line ending differences
- Extra/missing newlines

Fix: Copy exact text from `read` output.

## Large Output Handling

Commands with large output should write to file first:

```bash
# Wrong: output floods context
exec: find / -name "*.log"

# Correct: write to file, then read with limit
exec: find / -name "*.log" > /tmp/result.txt 2>&1
read: /tmp/result.txt (limit=50)
```

## Checklist

Before calling a tool:
- [ ] Using `file_path` (not `path`)?
- [ ] For edit: copied exact text including whitespace?
- [ ] For exec: will output be large? → redirect to file

## Resources

See `references/tool-params.md` for complete parameter list.
