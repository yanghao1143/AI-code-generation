# Chi Code 国际化 (i18n) 状态报告

**日期**: 2026年2月2日
**关注语言**: 简体中文 (zh-CN)

## 1. 概览

Chi Code 的中文化工作正在进行中，主要的 UI 元素已经完成翻译，但仍有部分新功能（特别是 AI Agent 模块）存在缺失。

| 指标 | 数量 | 说明 |
| :--- | :--- | :--- |
| **源语言键数 (en-US)** | 2223 | 基准键值总量 |
| **目标语言键数 (zh-CN)** | 2305 | 包含翻译键及可能的过期键 |
| **缺失翻译键数** | 292 | 存在于 en-US 但 zh-CN 中缺失 |
| **潜在过期键数** | ~374 | 存在于 zh-CN 但 en-US 中缺失 (估算: 2305 - (2223 - 292)) |

> **注意**: 中文文件键数多于英文文件，表明存在大量已废弃但在中文翻译文件中未清理的键值对。

## 2. 关键缺失翻译 (Missing Translations)

以下是目前 `zh-CN` 中缺失的主要翻译类别：

### 2.1 AI Agent 模块 (优先级：高)
Agent 模块是近期更新的重点，大量相关文本未翻译：
- `agent-no-past-threads`: You don't have any past threads yet.
- `agent-toggle-mode-menu`: Toggle Mode Menu
- `agent-restore-checkpoint`: Restore Checkpoint
- `agent-run-command`: Run Command
- `agent-plan`: Plan
- `agent-edits`: Edits
- `agent-waiting-confirmation`: Waiting Confirmation
- `agent-start-new-thread`: Start New Thread

### 2.2 搜索与替换 (优先级：中)
部分编辑器内部搜索功能的文本缺失：
- `buffer-search-next`: Select Next Match

### 2.3 配置与设置 (优先级：中)
新增加的配置选项和说明缺失：
- `settings-page-ai`: AI (部分页面标题)
- `agent-configure-default-model`: Configure Default Model
- `agent-configure-mcp-tools`: Configure MCP Tools

## 3. 潜在未翻译内容 (Untranslated Values)

检测到部分键的值在中文文件中与英文完全一致，可能是漏翻或专有名词：
- `panel-git`: "Git" (专有名词，无需翻译)
- `agent-zed-agent`: "Zed Agent" (专有名词)
- `repl-type-jupyter`: "Jupyter" (专有名词)
- `cc-mcp`: "MCP" (专有名词)

## 4. 建议与后续行动

1.  **补全 AI 模块翻译**: 重点针对 `agent-*` 开头的键值进行补充翻译，这是用户感知最明显的部分。
2.  **清理过期键值**: `zh-CN/main.ftl` 中包含约 370 个不再使用的键值，建议使用工具对比清理，以减小文件体积并避免混淆。
3.  **同步流程优化**: 建议引入自动化脚本，在每次 `en-US` 更新后自动检测并标记 `zh-CN` 中的新增或变动键值。

## 5. 详细缺失列表 (部分)

| Key | English Value |
| --- | --- |
| `agent-no-past-threads` | You don't have any past threads yet. |
| `agent-delete-all-history` | Delete All History |
| `agent-restore-checkpoint` | Restore Checkpoint |
| `agent-run-command` | Run Command |
| `agent-plan` | Plan |
| `agent-edits` | Edits |
| `agent-reject-all` | Reject All |
| `agent-review-changes` | Review Changes |
| `agent-start-new-thread` | Start New Thread |
| `agent-models` | Models |