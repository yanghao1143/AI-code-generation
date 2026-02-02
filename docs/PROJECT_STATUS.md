# PROJECT_STATUS

生成时间：2026-02-02

说明：以下统计基于静态扫描（`#[test]` 标记计数 + `crates/*/tests/*.rs` 文件数量）。未运行覆盖率工具，不能代表真实覆盖率百分比。

## 测试覆盖率统计（静态）
- crates 总数：220
- 有测试（包含 `#[test]` 或 `tests/` 目录）：91
- 无测试：129
- `#[test]` 总数：1270
- 集成测试文件数：9
- 有集成测试的 crates：fs(3), gpui(1), gpui_macros(3), worktree(2)
- `#[test]` 数量 Top10：agent(118), edit_prediction_cli(89), git_hosting_providers(86), gpui(86), util(57), agent_ui(51), project(44), terminal(43), migrator(41), edit_prediction(36)

## 缺失测试的模块列表（129）
acp_tools, action_log, agent_servers, agent_ui_v2, ai_onboarding, askpass, assets, assistant_slash_command,
assistant_slash_commands, assistant_text_thread, auto_update_ui, aws_http_client, breadcrumbs, buffer_diff, call,
channel, clock, cloud_api_client, codestral, collab_ui, collections, command_palette_hooks, component,
component_preview, context_server, copilot, copilot_ui, crashes, credentials_provider, dap, dap_adapters, db,
debug_adapter_extension, debugger_tools, deepseek, denoise, diagnostics, docs_preprocessor,
edit_prediction_context, edit_prediction_types, edit_prediction_ui, encoding_selector, eval_utils,
explorer_command_injector, extension_api, extension_cli, feature_flags, feedback, file_icons, fs_benchmarks,
go_to_line, gpui_tokio, http_client_tls, icons, image_viewer, inspector_ui, install_cli, json_schema_store,
language_onboarding, language_selector, language_tools, line_ending_selector, livekit_api, livekit_client, media,
menu, miniprofiler_ui, mistral, multi_buffer, nc, notifications, onboarding, open_ai, open_router, outline,
panel, paths, platform_title_bar, prettier, project_benchmarks, project_panel, project_symbols, prompt_store,
refineable, release_channel, remote_server, repl, rich_text, rules_library, schema_generator, search, session,
settings_macros, settings_profile_selector, settings_ui, snippet_provider, snippets_ui, sqlez_macros, story,
storybook, supermaven, supermaven_api, svg_preview, system_specs, tab_switcher, tasks_ui, telemetry,
telemetry_events, theme_extension, theme_selector, title_bar, toolchain_selector, ui_input, ui_macros, ui_prompt,
vercel, vim_mode_setting, watch, web_search, web_search_providers, which_key, worktree_benchmarks, x_ai,
zed_actions, zed_env_vars, zeta_prompt, zlog_settings, ztracing, ztracing_macro

## 文档完整性检查
- 现有文档体系完整：`docs/` 为 mdBook 结构，包含入门、配置、AI、扩展、语言支持、协作、开发等章节。
- 根目录文档齐全：README、CONTRIBUTING、CODE_OF_CONDUCT、LICENSE 系列存在；未发现 `SECURITY.md`。
- 待补充标记：`docs/` 中存在 32 处 TODO/TBD/PLACEHOLDER（集中于 glossary、extensions/languages、repl、languages、visual-customization 等）。

## 待办事项和改进建议
- 引入覆盖率工具并落地 CI 报告（当前仅为静态计数）。
- 优先为无测试且高耦合/高风险模块补齐基础单元测试与关键路径测试。
- 补充 `SECURITY.md` 并在 README 中链接。
- 清理 `docs/` 中的 TODO/TBD 条目，先补 glossary 与语言/REPL 指南。
