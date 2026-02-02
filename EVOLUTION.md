# EVOLUTION.md - 自我进化记录

## 进化框架 v2 (2026-02-02)

### 核心改进

1. **统一诊断引擎** - 7种状态识别
   - `api_failure` - API 连接失败
   - `needs_confirm` - 等待确认
   - `context_low` - Context 不足 (<30%)
   - `loop_detected` - 循环检测
   - `pending_input` - 未发送输入
   - `idle` - 空闲状态
   - `working` - 正常工作中

2. **智能修复引擎** - 针对性修复
   - API 失败 → 重启并使用正确环境变量
   - 确认界面 → 智能识别确认方式
   - Context 低 → 重启会话
   - 循环检测 → 发送 "1" 跳出
   - 未发送输入 → 发送 Enter
   - 空闲 → 自动派活

3. **自动确认启动流程** - 处理所有启动确认
   - 主题选择
   - API Key 确认
   - 权限确认
   - 安全警告

4. **学习系统** - 记录修复统计
   - Redis 存储修复历史
   - 统计各类问题频率
   - 为未来优化提供数据

### Agent 配置

| Agent | 启动命令 | 专长 |
|-------|----------|------|
| claude-agent | `ANTHROPIC_AUTH_TOKEN=... claude --dangerously-skip-permissions` | i18n, refactor, backend |
| gemini-agent | `gemini` | i18n, frontend, ui |
| codex-agent | `codex` | fix, test, optimize |

### 使用方法

```bash
# 快速检查 (静默，只输出异常)
./scripts/evolution-v2.sh check

# 详细状态
./scripts/evolution-v2.sh status

# 修复单个 agent
./scripts/evolution-v2.sh repair claude-agent

# 添加任务
./scripts/evolution-v2.sh add-task "任务描述" [high|normal]

# 记录学习
./scripts/evolution-v2.sh learn "症状" "解决方案" "成功率"
```

### 进化历史

| 日期 | 版本 | 改进 |
|------|------|------|
| 2026-02-02 11:49 | v2.0 | 统一诊断/修复引擎，自动确认启动，学习系统 |
| 2026-02-02 11:16 | v1.5 | high-perf.sh 高性能并发调度 |
| 2026-02-02 10:25 | v1.0 | director.sh 技术总监系统 |

---

## 待进化项目

- [ ] 预测性维护 - 在问题发生前预防
- [ ] 任务智能分配 - 根据 agent 专长和负载分配
- [ ] 自动扩缩容 - 根据任务量动态调整 agent 数量
- [ ] 跨 agent 协作 - 复杂任务拆分和协调
