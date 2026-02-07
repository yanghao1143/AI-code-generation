# Token 节省策略指南

> 作者：员工2号 🔧
> 日期：2026-02-07
> 主题：如何减少 token 消耗，降低成本

---

## 核心原则

**Token = 钱。每个 token 都有成本。**

节省 token 的三个维度：
1. **输入端**：减少发给模型的内容
2. **输出端**：让模型回复更精简
3. **缓存**：利用 prompt cache 降低重复成本

---

## 一、回复精简技巧

### 该说什么
✅ **直接回答问题**
✅ **必要的解释**（用户需要理解的）
✅ **关键步骤**（复杂任务）
✅ **错误信息**（帮助调试）
✅ **确认信息**（重要操作前）

### 不该说什么
❌ **"Great question!"** - 废话
❌ **"I'd be happy to help!"** - 废话
❌ **"Let me think about this..."** - 废话
❌ **重复用户的问题** - 浪费
❌ **过度解释简单操作** - 浪费
❌ **每个工具调用都叙述** - 浪费

### 示例对比

**❌ 浪费 token 的回复：**
```
Great question! I'd be happy to help you with that. Let me read the file for you. I'm going to use the read tool to access the contents of the file you mentioned. Here's what I found...
```

**✅ 精简回复：**
```
文件内容：
[内容]
```

### Tool Call Style 原则

来自 AGENTS.md：
> Default: do not narrate routine, low-risk tool calls (just call the tool).
> Narrate only when it helps: multi-step work, complex/challenging problems, sensitive actions.

**翻译**：
- 常规操作：直接调用，不解释
- 复杂操作：简要说明
- 危险操作：确认后执行

---

## 二、上下文压缩方法

### 1. 使用 /compact

当会话变长时：
```
/compact
```

可以带指令：
```
/compact 保留决策和待办事项
```

**效果**：将旧对话压缩成摘要，释放上下文空间

### 2. Session Pruning（自动）

OpenClaw 自动修剪旧的工具输出：
- 只影响发给模型的内容
- 不修改历史记录
- 保护最近的对话

**配置**：
```json5
{
  agent: {
    contextPruning: {
      mode: "cache-ttl",
      ttl: "5m"
    }
  }
}
```

### 3. 手动管理

- `/new` 或 `/reset` - 开始新会话
- 定期清理不需要的上下文
- 大文件用 `limit/offset` 分段读取

---

## 三、避免 Token 浪费的常见陷阱

### 陷阱 1：读取整个大文件
**❌ 错误**：read entire 50000 line file
**✅ 正确**：read file with limit=100, offset=1

### 陷阱 2：工具输出不截断
**❌ 错误**：exec: ls -la /
**✅ 正确**：exec: ls -la / | head -50

### 陷阱 3：重复读取相同内容
**❌ 错误**：每次都重新读取配置文件
**✅ 正确**：读一次，记住关键信息

### 陷阱 4：不必要的确认
**❌ 错误**：
```
我要读取文件了
[读取]
文件读取完成
现在我来分析...
```

**✅ 正确**：
```
[读取]
分析结果：...
```

### 陷阱 5：过长的 System Prompt
**问题**：workspace 文件太大
**解决**：
- 保持 AGENTS.md, SOUL.md 等文件精简
- 大内容放到单独文件，按需读取
- 检查：`/context list`

---

## 四、利用 Prompt Cache

### 什么是 Prompt Cache

Anthropic 等提供商会缓存 system prompt：
- **Cache Read**：比 input 便宜很多
- **Cache Write**：比 input 贵一点
- **TTL**：缓存有效期（通常 5 分钟）

### 如何利用

1. **保持会话连续性**
   - 不要频繁 `/new`
   - 让 system prompt 保持稳定

2. **Heartbeat 保持缓存热度**
   ```json5
   heartbeat: { every: "55m" }  // 略小于 cache TTL
   ```

3. **Cache-TTL Pruning**
   - 缓存过期后自动修剪
   - 减少 cache write 成本

---

## 五、实用 Checklist

### 每次回复前检查
- [ ] 是否有废话可以删除？
- [ ] 工具调用需要解释吗？（大多数不需要）
- [ ] 输出是否可以更精简？

### 每个会话检查
- [ ] 上下文是否过大？（`/status` 查看）
- [ ] 需要 `/compact` 吗？
- [ ] 有重复读取的内容吗？

### 配置检查
- [ ] contextPruning 是否启用？
- [ ] heartbeat 是否配置？
- [ ] workspace 文件是否精简？

---

## 六、监控工具

```bash
# 查看上下文使用率
/status

# 查看各部分大小
/context list

# 详细分解
/context detail

# 每条回复显示 token
/usage tokens

# 显示 token + 成本
/usage full
```

---

## 七、成本估算

### Anthropic 定价参考（每 1M tokens）

| 类型 | Claude Opus | Claude Sonnet | Claude Haiku |
|-----|-------------|---------------|--------------|
| Input | $15 | $3 | $0.25 |
| Output | $75 | $15 | $1.25 |
| Cache Read | $1.5 | $0.3 | $0.025 |
| Cache Write | $18.75 | $3.75 | $0.3 |

**关键洞察**：
- Output 比 Input 贵 5 倍
- Cache Read 比 Input 便宜 10 倍
- 精简回复的 ROI 最高

---

## 总结

**Token 节省三板斧**：
1. **精简回复**：不说废话，直接干活
2. **压缩上下文**：用 /compact，启用 pruning
3. **利用缓存**：保持连续性，heartbeat 保温

**记住**：最好的 token 是不发送的 token。

---

*参考来源: OpenClaw 文档 (token-use.md, session-pruning.md, compaction.md, system-prompt.md)*
