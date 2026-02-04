# 快速开始：统一知识管理系统

> 5 分钟上手新的知识管理系统

## 🚀 立即可用的命令

### 1. 查看系统状态

```bash
./scripts/knowledge.sh status
```

输出:
- 📚 长期记忆数量 (PostgreSQL)
- 💾 实时状态 (Redis)
- 📝 每日日志统计
- 🔍 上下文使用率
- 🎓 错误记录数

### 2. 搜索知识

```bash
# 跨系统搜索
./scripts/knowledge.sh search "上下文管理"

# 快速查询
./scripts/knowledge.sh quick today      # 今天的工作
./scripts/knowledge.sh quick yesterday  # 昨天的工作
./scripts/knowledge.sh quick plan       # 当前计划
./scripts/knowledge.sh quick errors     # 最近错误
./scripts/knowledge.sh quick important  # 重要记忆
```

### 3. 检查上下文预算

```bash
# 检查当前状态
./scripts/context-budget.sh check

# 查看简要状态 (用于心跳)
./scripts/context-budget.sh status

# 查看使用趋势
./scripts/context-budget.sh trends
```

### 4. 提炼知识

```bash
# 提炼昨天的日志
./scripts/knowledge-distill.sh distill

# 提炼指定日期
./scripts/knowledge-distill.sh distill 2026-02-04

# 批量提炼
./scripts/knowledge-distill.sh batch 2026-02-01 2026-02-04

# 查看提炼状态
./scripts/knowledge-distill.sh status
```

---

## 📋 集成到工作流

### 集成到 HEARTBEAT.md

在 `HEARTBEAT.md` 中添加:

```markdown
## 必做：上下文健康检查

每次心跳**必须**执行：

```bash
# 1. 检查上下文预算
./scripts/context-budget.sh status

# 2. 如果使用率 > 50%：精简回复
# 3. 如果使用率 > 70%：主动告知用户
# 4. 如果使用率 > 85%：立即建议 /new
```

## 知识管理

每天自动运行 (cron):
- 凌晨 1 点: 提炼昨天的知识
```

### 配置 Cron 自动提炼

```bash
# 编辑 crontab
crontab -e

# 添加以下行
0 1 * * * cd /home/jinyang/.openclaw/workspace && ./scripts/knowledge-distill.sh auto >> /tmp/distill.log 2>&1
```

### 启动上下文监控 (可选)

```bash
# 后台启动监控
nohup ./scripts/context-budget.sh monitor > /tmp/context-monitor.log 2>&1 &

# 或者配置为 systemd 服务 (推荐)
# 见 docs/CONTEXT_AND_KNOWLEDGE_SYSTEM.md
```

---

## 🎯 常见场景

### 场景 1: 会话开始时

```bash
# 1. 检查预算
./scripts/context-budget.sh check

# 2. 查看今天的任务
./scripts/knowledge.sh quick today

# 3. 搜索相关知识
./scripts/knowledge.sh search "上次讨论的问题"
```

### 场景 2: 上下文快满了

```bash
# 1. 检查状态
./scripts/context-budget.sh check

# 2. 如果 > 70%，手动压缩
./scripts/context-budget.sh compress

# 3. 或者建议用户 /new
```

### 场景 3: 查找历史信息

```bash
# 搜索关键词
./scripts/knowledge.sh search "PostgreSQL"

# 查看昨天的工作
./scripts/knowledge.sh quick yesterday

# 查看重要记忆
./scripts/knowledge.sh quick important
```

### 场景 4: 每日总结

```bash
# 会话结束时，保存摘要
./scripts/context-manager.sh summary "今天完成了 X, 遇到了 Y"

# 提炼知识 (或等 cron 自动运行)
./scripts/knowledge-distill.sh distill
```

---

## 🔧 故障排查

### 问题 1: 脚本没有执行权限

```bash
chmod +x scripts/knowledge.sh
chmod +x scripts/context-budget.sh
chmod +x scripts/knowledge-distill.sh
```

### 问题 2: PostgreSQL 连接失败

```bash
# 检查 PostgreSQL 是否运行
sudo systemctl status postgresql

# 检查连接
psql -h localhost -U openclaw -d openclaw -c "SELECT 1;"
```

### 问题 3: Redis 连接失败

```bash
# 检查 Redis 是否运行
redis-cli ping

# 如果返回 PONG，说明正常
```

### 问题 4: 上下文估算不准确

```bash
# 当前是估算，真实值需要从 session_status 获取
# 可以手动更新缓存:
redis-cli SET "openclaw:ctx:budget:current" <实际值>
```

---

## 📚 更多文档

- **完整设计**: `docs/CONTEXT_AND_KNOWLEDGE_SYSTEM.md`
- **任务报告**: `docs/TASK_COMPLETION_REPORT.md`
- **脚本帮助**: `./scripts/knowledge.sh help`

---

## 🎉 开始使用

```bash
# 1. 查看系统状态
./scripts/knowledge.sh status

# 2. 检查上下文预算
./scripts/context-budget.sh check

# 3. 搜索知识
./scripts/knowledge.sh search "你想找的内容"

# 4. 提炼昨天的知识
./scripts/knowledge-distill.sh distill
```

**就这么简单！** 🚀

---

**提示**: 所有脚本都有 `--help` 选项，可以查看详细用法。
