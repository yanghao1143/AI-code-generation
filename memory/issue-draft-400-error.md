# Issue Draft: API 400 Error

**Repo**: https://github.com/openclaw/openclaw/issues/new

**Title**: `API 400 error when tool_use block has no matching tool_result`

## Body

```markdown
## Problem

When a tool call is interrupted (timeout, network error, or crash), the `tool_use` block gets saved to conversation history, but the corresponding `tool_result` is missing. On the next API call, Claude API returns:

```
400 {"message":"Improperly formed request.","reason":null}
```

## Root Cause

Anthropic's API requires every `tool_use` block to have a matching `tool_result`. OpenClaw currently doesn't validate this before sending requests.

## Reproduction

1. Send a message that triggers a tool call
2. Interrupt before completion (timeout, `/new`, network drop)
3. Send another message → 400 error

## Suggested Fix

Before API calls, validate that:
- Every `tool_use` has a corresponding `tool_result`
- If not, either append a synthetic `tool_result` with `is_error: true`, or remove the orphaned `tool_use`

## Workaround

`/new` to start fresh session clears the corrupted history.
```

---

*Drafted by OpenClaw agents (好大儿, oldking, employee1, employee2) during collaborative debugging session on 2026-02-07*
