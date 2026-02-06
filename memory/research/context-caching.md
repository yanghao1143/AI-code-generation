# Claude Prompt Caching 研究

## 研究时间
2026-02-05 21:27

## 核心概念

### 什么是 Prompt Caching？

Anthropic 的 Prompt Caching 允许缓存 prompt 的前缀部分，后续请求如果使用相同的前缀，可以：
- **减少 90% 的输入成本**（缓存命中时）
- **减少延迟**（不需要重新处理缓存的部分）

### 工作原理

1. **首次请求**：完整处理 prompt，缓存指定的前缀部分
   - 缓存写入有额外成本（约 25% 溢价）
   
2. **后续请求**：如果前缀完全匹配，直接使用缓存
   - 缓存读取成本极低（约 10% 的正常价格）

3. **缓存失效**：
   - 前缀有任何变化 → 缓存失效
   - 超过 TTL → 缓存失效
   - `short` = 5 分钟, `long` = 1 小时

### 定价（Claude 3.5 Sonnet 为例）

| 类型 | 价格 (per 1M tokens) |
|------|---------------------|
| 正常输入 | $3.00 |
| 缓存写入 | $3.75 (1.25x) |
| 缓存读取 | $0.30 (0.1x) |

## OpenClaw 当前配置分析

### 已启用的缓存设置

```json
{
  "models": {
    "anthropic/claude-opus-4-5-20251101": {
      "params": {
        "cacheRetention": "short"  // ✅ 启用短期缓存 (5分钟)
      }
    }
  },
  "contextPruning": {
    "mode": "cache-ttl",           // ✅ 基于缓存 TTL 的修剪
    "ttl": "15m",                  // 15 分钟上下文修剪
    "keepLastAssistants": 3,      // 保留最近 3 条助手消息
    "softTrimRatio": 0.5,         // 50% 时软修剪
    "hardClearRatio": 0.7,        // 70% 时硬清理
    "minPrunableToolChars": 3000  // 工具输出 > 3000 字符才修剪
  }
}
```

### 实现细节（从源码分析）

OpenClaw 通过 `pi-ai` 库的 `streamSimple` 函数传递 `cacheRetention` 参数：

```javascript
// extra-params.js
const cacheRetention = resolveCacheRetention(extraParams, provider);
if (cacheRetention) {
    streamParams.cacheRetention = cacheRetention;
}
```

这意味着：
1. **只对 Anthropic 提供商生效** - 其他提供商（OpenRouter、Google）不支持
2. **自动应用** - 不需要手动标记缓存断点
3. **短期缓存** - 当前配置是 5 分钟 TTL

### 潜在问题

1. **代理服务器兼容性**
   - 当前使用 `claude.chiddns.com` 作为代理
   - 需要验证代理是否正确传递 `cacheRetention` 参数

2. **缓存 TTL 不匹配**
   - `cacheRetention: "short"` = 5 分钟
   - `contextPruning.ttl: "15m"` = 15 分钟
   - 这意味着缓存可能在上下文修剪前就失效了

3. **没有缓存统计**
   - session_status 不显示 cacheRead/cacheWrite
   - 难以验证缓存是否真正生效

## 优化建议

### 1. 延长缓存 TTL

```json
{
  "anthropic/claude-opus-4-5-20251101": {
    "params": {
      "cacheRetention": "long"  // 改为 1 小时
    }
  }
}
```

**理由**：长对话中，5 分钟的缓存太短，频繁失效会增加成本。

### 2. 优化 System Prompt 结构

当前结构（推测）：
```
[工具定义]           ← 静态，会被缓存
[Skills 列表]        ← 静态
[Memory Recall]      ← 静态
[Workspace Files]    ← 动态！
  - AGENTS.md        ← 很少变
  - SOUL.md          ← 很少变
  - MEMORY.md        ← 经常变 ⚠️
[Runtime 信息]       ← 动态（时间戳）
```

**问题**：MEMORY.md 在中间，每次变化都会使后面的缓存失效。

**优化方案**：
```
[工具定义]           ← 缓存
[Skills 列表]        ← 缓存
[Memory Recall]      ← 缓存
[AGENTS.md]          ← 缓存
[SOUL.md]            ← 缓存
[IDENTITY.md]        ← 缓存
--- 缓存断点 ---
[MEMORY.md]          ← 不缓存
[Runtime 信息]       ← 不缓存
[对话历史]           ← 不缓存
```

### 3. 分离静态/动态文件

创建配置选项，让用户指定哪些文件是"静态"的：

```json
{
  "agents": {
    "defaults": {
      "staticContextFiles": [
        "AGENTS.md",
        "SOUL.md",
        "IDENTITY.md",
        "TOOLS.md"
      ],
      "dynamicContextFiles": [
        "MEMORY.md",
        "HEARTBEAT.md"
      ]
    }
  }
}
```

### 4. 添加缓存监控

在 session_status 中显示：
- cacheRead tokens
- cacheWrite tokens
- 缓存命中率
- 估算节省的成本

## 实施计划

### Phase 1: 验证当前缓存状态 ✅
1. [x] 检查代理服务器是否支持 cacheRetention - 需要测试
2. [x] 分析 OpenClaw 源码中的缓存实现
3. [x] 理解 cacheRetention 参数的工作方式

### Phase 2: 立即可做的优化
1. [ ] 将 cacheRetention 改为 "long" (1小时)
2. [ ] 测试成本变化

### Phase 3: 需要 OpenClaw 改动的优化
1. [ ] 分析当前 system prompt 的组成顺序
2. [ ] 提交 PR：重新排序静态/动态内容
3. [ ] 提交 PR：在 session_status 中显示缓存统计

## 参考

- Anthropic Prompt Caching 文档
- OpenClaw 源码 `extra-params.js`
- OpenClaw 源码 `context-pruning` 扩展
- Moltbook 帖子：上下文缓存优化成本
