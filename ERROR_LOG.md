# 错误日志

> 记录踩过的坑，避免重复犯错

## 2026-02-01

### ERR-001: Mutex 锁污染
**模块**: cc_switch/config_sync.rs
**问题**: 测试中 Mutex panic 导致后续测试失败
**解决**: 使用 `unwrap_or_else(|e| e.into_inner())` 处理污染的锁
**教训**: 测试中使用共享状态要考虑 panic 情况

### ERR-002: get_home_dir 环境变量优先级
**模块**: cc_switch/config_sync.rs
**问题**: 测试设置 HOME 环境变量但函数没有优先读取
**解决**: 修改 get_home_dir() 优先检查 HOME/USERPROFILE 环境变量
**教训**: 测试环境和生产环境的差异要考虑

### ERR-003: unsafe env::set_var
**模块**: cc_switch/config_sync.rs
**问题**: Rust 1.91+ 要求 env::set_var 在 unsafe 块中
**解决**: 包装在 unsafe {} 块中
**教训**: 注意 Rust 版本更新带来的 API 变化

### ERR-004: haiku 模型不在允许列表
**模块**: cron 定时任务
**问题**: `anthropic/claude-haiku` 和 `anthropic/claude-haiku-4-5-20251001` 都不被允许
**解决**: 去掉 model 字段，使用默认模型
**教训**: 检查模型是否在 allowlist 中

### ERR-005: cron deliver 到 whatsapp 失败
**模块**: cron 定时任务
**问题**: deliver: true + to: "jinyang" 尝试发送到 whatsapp
**解决**: 去掉 deliver/to/channel 参数
**教训**: isolated 任务不需要 deliver

### ERR-006: git push 需要 pull first
**模块**: git 操作
**问题**: 远程有内容时直接 push 被拒绝
**解决**: `git pull --allow-unrelated-histories` 后再 push
**教训**: 新仓库初始化时先 pull

---

## 常见问题速查

| 问题 | 解决方案 |
|------|----------|
| 测试 Mutex 污染 | `unwrap_or_else(\|e\| e.into_inner())` |
| env::set_var 报错 | 包装在 `unsafe {}` 中 |
| cargo test 失败 | 先 `cargo check` 确认编译通过 |
| git push 被拒 | 先 `git pull --allow-unrelated-histories` |
| cron 模型不允许 | 去掉 model 字段用默认模型 |
| gateway timeout | 重试或简化 payload |

---

*最后更新: 2026-02-01 20:58*
