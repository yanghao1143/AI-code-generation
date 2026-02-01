# CODE_DEBT.md - 代码债务追踪

## 2026-02-01 巡检 (21:05)

**扫描路径**: `/mnt/d/ai软件/zed/crates/`

### multi_model_dispatch crate (565 行)

| 文件 | 行号 | 问题类型 | 描述 | 优先级 |
|------|------|----------|------|--------|
| `settings.rs` | 1 | 未使用 import | `App` 从 gpui 导入但未使用 | 低 |
| `multi_model_dispatch.rs` | 13 | 未使用 import | `std::sync::Arc` 导入但未使用 | 低 |
| `multi_model_dispatch.rs` | 201 | TODO | `// TODO: Display plan somewhere?` 待实现 | 中 |

### cc_switch crate (5590 行)

| 文件 | 行号 | 问题类型 | 描述 | 优先级 |
|------|------|----------|------|--------|
| `config_sync.rs` | 763 | TODO | `// TODO: Implement update logic (git pull)` 技能更新逻辑未实现 | 中 |

### 代码质量统计

| 指标 | cc_switch | multi_model_dispatch |
|------|-----------|---------------------|
| 总行数 | 5590 | 565 |
| 源文件数 | 14 | 5 |
| TODO/FIXME | 1 | 1 |
| unwrap() 调用 | 24 (多数在测试/Mutex lock) | 0 |
| expect() 调用 | 12 | 0 |
| 注释代码块 | 0 ✅ | 0 ✅ |
| deprecated API | 0 ✅ | 0 ✅ |
| dbg!/println! | 0 ✅ | 0 ✅ |
| panic! (非测试) | 0 ✅ | 0 ✅ |
| unsafe 块 | 0 ✅ | 0 ✅ |

### 本次扫描结论

✅ **整体代码质量良好**
- 无注释代码块
- 无 deprecated API 使用
- 无调试宏残留 (dbg!/println!)
- 无 unsafe 代码
- unwrap() 主要用于 Mutex lock（可接受模式）和测试代码

⚠️ **待处理项**
1. 2 个未使用的 imports (低优先级，可用 `cargo clippy` 自动修复)
2. 2 个 TODO 待实现 (中优先级)

---

## 清理建议

### 立即可做
```bash
# 在 Windows 端运行 clippy 自动检测未使用 imports
cargo clippy -p multi_model_dispatch -- -W unused-imports
```

### 需要设计
1. **config_sync.rs:763** - 实现技能更新逻辑 (git pull)
2. **multi_model_dispatch.rs:201** - 实现 dispatch 结果的 UI 展示

---

## 历史记录

| 日期 | 扫描结果 | 处理状态 |
|------|----------|----------|
| 2026-02-01 21:05 | 2 unused imports, 2 TODOs | 待处理 |
| 2026-02-01 20:51 | 2 unused imports, 2 TODOs | 已记录 |
