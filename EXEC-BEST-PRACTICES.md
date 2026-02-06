# EXEC-BEST-PRACTICES.md (v3)

**防止 400 错误的核心规则**

> 由 @employee2 编写，@employee1 @oldking review，2026-02-06

## 问题根源

400 错误 = 上下文溢出（超过模型的 200K tokens 窗口）

**主要原因：**
1. exec 输出太大直接塞进上下文
2. 系统提示本身很大（AGENTS.md、SOUL.md 等文件注入）
3. 长对话累积

## 核心规则：exec 中转

**不确定输出大小的命令，一律中转。宁可多一步，不要爆上下文。**

### ❌ 错误做法

```bash
exec: cat 大文件.txt
exec: npm install
exec: git log
exec: find /
exec: git diff
exec: npm install 2>&1 > /tmp/npm.txt  # ❌ 顺序错了！stderr 不会被捕获
```

### ✅ 正确做法

```bash
# 第一步：落盘（注意顺序！> file 2>&1）
exec: npm install > /tmp/npm_install.txt 2>&1

# 第二步：分页读取
read: /tmp/npm_install.txt (limit=50)

# 第三步：用完清理
exec: rm /tmp/npm_install.txt
```

### 通用中转模板

```bash
# 使用时间戳避免文件名冲突
exec: <命令> > /tmp/output_$(date +%s).txt 2>&1
read: /tmp/output_*.txt (limit=50)
exec: rm /tmp/output_*.txt  # 清理临时文件
```

### 管道限制策略

除了中转，有些场景可以用管道先限制输出：

```bash
# 先限制行数，再落盘
exec: git log | head -100 > /tmp/log.txt 2>&1
read: /tmp/log.txt (limit=50)
```

## 白名单命令（可以直接 exec）

这些命令输出小且可控，可以直接执行：

- `pwd`
- `date`
- `ls -la`
- `wc` / `wc -l file`
- `du -sh`
- `echo`
- `mkdir`
- `git status`
- `git log -n 10` ✅（带限制）
- `git diff --stat` ✅（只显示统计）
- `ps aux | grep xxx` ✅（过滤后输出小）
- `head -n 50 file` ✅
- `tail -n 50 file` ✅

## 危险命令（必须中转）

- `git log` ❌（无限制）
- `git diff` ❌（完整 diff 可能很大）
- `npm install` / `npm run`
- `cat` 大文件
- `find` ❌（必须配合 `-maxdepth` 或 `| head`）
- `grep -r` 大目录
- `docker logs`
- `journalctl`

## 重定向顺序（重要！）

```bash
# ✅ 正确：先重定向 stdout，再重定向 stderr 到 stdout
command > file 2>&1

# ❌ 错误：stderr 不会被捕获到文件
command 2>&1 > file
```

**记忆技巧：**`> file 2>&1` 读作"输出到文件，错误也一起"

## 上下文监控

定期检查 `session_status`：

- **>50%** - 精简回复，工具输出只取关键部分
- **>70%** - 主动告诉用户，建议开新会话
- **>85%** - 立即建议 `/new`

## 实战案例

### 案例 1：npm install

```bash
# ✅ 正确
exec: npm install > /tmp/npm.txt 2>&1
read: /tmp/npm.txt (limit=100)
exec: rm /tmp/npm.txt
```

### 案例 2：git log

```bash
# ❌ 错误
exec: git log

# ✅ 正确（带限制）
exec: git log -n 20

# ✅ 正确（管道限制）
exec: git log | head -100 > /tmp/log.txt 2>&1
read: /tmp/log.txt (limit=50)
exec: rm /tmp/log.txt
```

### 案例 3：find

```bash
# ❌ 错误
exec: find /

# ✅ 正确
exec: find / -maxdepth 3 > /tmp/find.txt 2>&1
read: /tmp/find.txt (limit=100)
exec: rm /tmp/find.txt
```

### 案例 4：git diff

```bash
# ❌ 错误
exec: git diff

# ✅ 正确（只看统计）
exec: git diff --stat

# ✅ 正确（需要完整 diff 时中转）
exec: git diff > /tmp/diff.txt 2>&1
read: /tmp/diff.txt (limit=50)
exec: rm /tmp/diff.txt
```

## 临时文件管理

- 用完立即删除：`rm /tmp/xxx.txt`
- 避免磁盘堆积
- 可以用时间戳命名避免冲突：`/tmp/output_$(date +%s).txt`

## 紧急补救

如果已经触发 400 错误：

1. **立即停止** - 不要尝试"再试一次"
2. **开新会话** - 用 `/new` 清空上下文
3. **检查原因** - 回顾最后几步操作，找出大输出来源
4. **修正策略** - 下次用中转规则

## 主动压缩策略

- 工具输出超过 2000 字符 → 自动总结关键信息，丢弃中间冗余
- 对话超过 10 轮 → 主动建议用户 `/new`

## 状态机思路

把详细数据外置到 PostgreSQL/Redis，上下文只保留指针/索引。这是根本解法。

---

**记住：不确定就中转，宁可多一步。**
