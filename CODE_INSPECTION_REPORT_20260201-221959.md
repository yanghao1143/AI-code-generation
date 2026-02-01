# 代码质量巡检报告

**扫描时间**: 2026-02-01 22:19:59 (GMT+8)
**扫描路径**: /mnt/d/ai软件/zed/crates

## cc_switch crate

### 基本统计
- 总行数: 5590
- 源文件数: 14

### 未使用的 imports
- 检测到的 use 语句: 90

### TODO/FIXME
发现 1 个 TODO/FIXME:
- /mnt/d/ai软件/zed/crates/cc_switch/src/config_sync.rs:763:        // TODO: Implement update logic (git pull)

### 注释代码块
发现 10 个可能的注释代码块:
- /mnt/d/ai软件/zed/crates/cc_switch/src/cc_switch_panel.rs:1://! CC-Switch Panel implementation
- /mnt/d/ai软件/zed/crates/cc_switch/src/cc_switch_panel.rs:467:                // ... (Providers implementation remains same)
- /mnt/d/ai软件/zed/crates/cc_switch/src/cc_switch_panel.rs:523:                // on_delete callback
- /mnt/d/ai软件/zed/crates/cc_switch/src/cc_switch_panel.rs:608:                // on_delete callback
- /mnt/d/ai软件/zed/crates/cc_switch/src/cc_switch_panel.rs:637:                // Let's modify SkillsView constructor to take list? 
- /mnt/d/ai软件/zed/crates/cc_switch/src/views/add_provider_modal.rs:98:        // Simplified test - just validate that API key is not empty
- /mnt/d/ai软件/zed/crates/cc_switch/src/views/add_provider_modal.rs:99:        // A real implementation would use ApiClient to validate
- /mnt/d/ai软件/zed/crates/cc_switch/src/views/add_skill_modal.rs:59:            // Simple parsing logic: try to extract owner/repo
- /mnt/d/ai软件/zed/crates/cc_switch/src/views/mcp_view.rs:238:    // Using render_server_item_simple instead
- /mnt/d/ai软件/zed/crates/cc_switch/src/views/mcp_view.rs:265:    /// Simplified server item render without context menu (for non-Entity usage)

### Deprecated API
✅ 无 deprecated API

### unwrap/expect 调用
- unwrap/expect 调用数: 36

### 调试宏
✅ 无调试宏

### unsafe 块
✅ 无 unsafe 块

## multi_model_dispatch crate

### 基本统计
- 总行数: 565
- 源文件数: 8

### 未使用的 imports
- 检测到的 use 语句: 25

### TODO/FIXME
发现 1 个 TODO/FIXME:
- /mnt/d/ai软件/zed/crates/multi_model_dispatch/src/multi_model_dispatch.rs:201:                            // TODO: Display plan somewhere? For now just log/notify.

### 注释代码块
发现 5 个可能的注释代码块:
- /mnt/d/ai软件/zed/crates/multi_model_dispatch/src/multi_model_dispatch.rs:84:        // Simple default for now, can be hooked to settings later
- /mnt/d/ai软件/zed/crates/multi_model_dispatch/src/settings.rs:28:        // For now, return default as we haven't added this to the main SettingsContent struct
- /mnt/d/ai软件/zed/crates/multi_model_dispatch/src/settings.rs:29:        // In a real implementation, we would either add it to SettingsContent 
- /mnt/d/ai软件/zed/crates/multi_model_dispatch/src/settings.rs:33:        // but to satisfy the trait we must implement this.
- /mnt/d/ai软件/zed/crates/multi_model_dispatch/src/views/agent_list_view.rs:52:                                // Simple text for model for now, can be dropdown later

### Deprecated API
✅ 无 deprecated API

### unwrap/expect 调用
- unwrap/expect 调用数: 0

### 调试宏
✅ 无调试宏

### unsafe 块
✅ 无 unsafe 块

---

**报告生成时间**: 2026-02-01 22:20:00
