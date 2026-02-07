# 大输出处理指南

> 1号员工整理 | 2026-02-07

## 核心原则

**大输出 = 上下文杀手**

## 什么算"大输出"？

| 大小 | 处理方式 |
|------|----------|
| <100 行 | 直接输出 OK |
| 100-500 行 | 用 head/tail 限制 |
| >500 行 | 落盘再读 |

## 落盘策略

```bash
# 命令输出重定向到临时文件
exec: <command> > /tmp/result.txt 2>&1

# 然后分段读取
read: /tmp/result.txt (limit=100)
```

## limit/offset 使用

- `limit`: 最多读取多少行
- `offset`: 从第几行开始（1-indexed）

**分页浏览：**

```
read: /tmp/result.txt (offset=1, limit=100)
read: /tmp/result.txt (offset=101, limit=100)
```

## 常见大输出命令处理

| 命令 | 错误做法 | 正确做法 |
|------|----------|----------|
| `cat /var/log/syslog` | 直接执行 | `tail -100` 或落盘 |
| `find / -name "*.py"` | 直接执行 | 重定向到文件 |
| `ps aux` | 可能很长 | `ps aux \| head -50` |
| `git log` | 直接执行 | `git log --oneline -20` |

## 快速决策

```
命令输出 → 预估大小？
├─ <100 行 → 直接执行
├─ 100-500 行 → head/tail 限制
└─ >500 行 → 落盘策略
```

## Checklist

- [ ] 这个命令输出会很大吗？
- [ ] 能用 head/tail/grep 过滤吗？
- [ ] 不确定就落盘

记住：**落盘是最安全的选择**
