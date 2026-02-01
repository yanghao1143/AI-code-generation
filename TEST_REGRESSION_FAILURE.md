# 测试回归检测失败报告

**时间**: 2026-02-01 22:08:55
**Cron 任务**: 04327716-397b-444f-bf9f-5d715d0e4ae0

## 问题描述

测试回归检测失败：cargo 命令未找到

## 详细信息

- **命令**: `cargo test -p cc_switch -p multi_model_dispatch -p i18n`
- **错误**: `/bin/bash: line 1: cargo: command not found`
- **退出码**: 127

## 环境检查

- cargo 不在 PATH 中
- ~/.cargo/bin/cargo 不存在
- 当前 PATH: `/home/jinyang/.nvm/versions/node/v22.22.0/bin:/usr/local/bin:/usr/bin:/bin:/home/jinyang/.local/bin:/home/jinyang/.npm-global/bin:/home/jinyang/bin:/home/jinyang/.nvm/current/bin:/home/jinyang/.fnm/current/bin:/home/jinyang/.volta/bin:/home/jinyang/.asdf/shims:/home/jinyang/.local/share/pnpm:/home/jinyang/.bun/bin`

## 修复建议

### 1. 检查 Rust 安装状态
```bash
rustc --version
rustup --version
```

### 2. 如果未安装，安装 Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### 3. 如果已安装，配置环境变量
```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
export PATH="$HOME/.cargo/bin:$PATH"
source ~/.cargo/env
```

### 4. 验证安装
```bash
cargo --version
```

### 5. 重新运行测试
```bash
cargo test -p cc_switch -p multi_model_dispatch -p i18n
```

## 派发修复任务

需要将此任务派发给 agents 进行修复。

## Redis 缓存

- `openclaw:test:regression:last_run` = 当前时间
- `openclaw:test:regression:status` = FAILED
- `openclaw:test:regression:error` = cargo command not found - Rust environment not configured
