---
name: mattermost
description: Send messages, files, and use Mattermost features via OpenClaw. Use when sending files to Mattermost channels, formatting messages, or using Mattermost-specific features.
---

# Mattermost

Send messages and files to Mattermost via the `message` tool.

## Send File

```xml
<invoke name="message">
  <parameter name="action">send</parameter>
  <parameter name="channel">mattermost</parameter>
  <parameter name="filePath">/path/to/file.md</parameter>
  <parameter name="message">Optional caption</parameter>
  <parameter name="target">channel_id</parameter>
</invoke>
```

**Key params:**
- `filePath`: Local file path to upload
- `message`: Optional text caption
- `target`: Channel ID or `user:id` for DM

## Send Text

```xml
<invoke name="message">
  <parameter name="action">send</parameter>
  <parameter name="channel">mattermost</parameter>
  <parameter name="message">Your message here</parameter>
  <parameter name="target">channel_id</parameter>
</invoke>
```

## Markdown Formatting

Mattermost supports standard Markdown:

```markdown
**bold** *italic* ~~strikethrough~~
`inline code`
```code block```
> quote
- bullet list
1. numbered list
| table | header |
|-------|--------|
| cell  | cell   |
```

**⚠️ Note:** Tables work in Mattermost (unlike WhatsApp/Discord).

## Target Formats

| Format | Example | Use |
|--------|---------|-----|
| Channel ID | `5spon67i3irudckph8sbo8ar8a` | Send to channel |
| `channel:id` | `channel:abc123` | Explicit channel |
| `user:id` | `user:xyz789` | Send DM |
| `@username` | `@haodaer` | Send DM by username |

## Broadcast

Send to multiple targets:

```xml
<invoke name="message">
  <parameter name="action">broadcast</parameter>
  <parameter name="channel">mattermost</parameter>
  <parameter name="message">Announcement</parameter>
  <parameter name="targets">["channel1", "channel2"]</parameter>
</invoke>
```

## Best Practices

1. **Send files, not walls of text** - Use `filePath` for long content
2. **Use tables** - Mattermost renders them properly
3. **Code blocks** - Use triple backticks with language hint

## Resources

See `references/message-params.md` for complete parameter list.
