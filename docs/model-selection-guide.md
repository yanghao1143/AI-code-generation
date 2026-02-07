# 模型选择策略指南

> 作者：员工2号 🔧
> 日期：2026-02-07
> 主题：什么任务用什么模型

---

## 核心原则

**不是越贵越好，而是匹配任务复杂度。**

模型选择的本质是**成本-能力权衡**：
- 简单任务用强模型 = 浪费钱
- 复杂任务用弱模型 = 浪费时间（重试、修正）

---

## 模型能力分层

### 🏆 Tier 1: 旗舰推理模型（最贵）

**代表**: Claude Opus 4.5/4.6, GPT-5.2, Gemini 3 Pro, Grok 4

**适用场景**:
- 复杂多步推理
- 需要深度思考的问题
- 代码架构设计
- 长文档分析与综合
- 需要高准确率的关键任务

**成本**: $15-75/M tokens (input), $75-150/M tokens (output)

**什么时候用**:
- 任务失败代价高
- 需要"一次做对"
- 涉及复杂逻辑链

### 🥈 Tier 2: 主力工作模型（性价比）

**代表**: Claude Sonnet 4.5, GPT-5, Gemini 2.5 Flash, Kimi K2.5

**适用场景**:
- 日常编码任务
- 文档撰写
- 数据处理
- 一般问答
- 工具调用

**成本**: $3-8/M tokens (input), $15-30/M tokens (output)

**什么时候用**:
- 大多数日常任务
- 可以接受偶尔重试
- 批量处理

### 🥉 Tier 3: 轻量快速模型（便宜）

**代表**: Claude Haiku 4.5, GPT-4.1 mini, Gemini Flash-Lite, GLM-4.7-Flash

**适用场景**:
- 简单分类/提取
- 格式转换
- 快速问答
- 批量处理大量简单任务
- 草稿生成

**成本**: $0.1-1/M tokens (input), $0.5-4/M tokens (output)

**什么时候用**:
- 任务简单明确
- 需要高吞吐量
- 成本敏感场景

### 🆓 Tier 4: 免费/本地模型

**代表**: Llama 3.3 70B, Qwen3 235B, DeepSeek V3, Ollama 本地模型

**适用场景**:
- 实验和原型
- 隐私敏感数据
- 离线场景
- 学习和测试

**成本**: 免费或仅硬件成本

---

## 任务-模型匹配表

| 任务类型 | 推荐层级 | 具体模型建议 |
|---------|---------|-------------|
| 复杂代码重构 | Tier 1 | Opus, GPT-5.2 |
| 日常编码 | Tier 2 | Sonnet, Kimi K2.5 |
| 代码补全/简单修改 | Tier 3 | Haiku, GPT-4.1 mini |
| 架构设计 | Tier 1 | Opus (thinking mode) |
| 文档撰写 | Tier 2 | Sonnet, MiniMax M2.1 |
| 格式转换 | Tier 3 | Haiku, Flash-Lite |
| 数据分析 | Tier 2 | Sonnet, Gemini Flash |
| 批量分类 | Tier 3 | Haiku, mini 模型 |
| 创意写作 | Tier 2 | MiniMax, Sonnet |
| 简单问答 | Tier 3 | 任意轻量模型 |
| 长文档理解 | Tier 1-2 | Opus, Gemini (大上下文) |

---

## 推理能力：什么时候需要？

### 需要推理 (Thinking/Reasoning) 的场景
- 数学证明
- 复杂逻辑推导
- 多步骤规划
- 代码调试（找 bug）
- 需要"想清楚再回答"的问题

### 不需要推理的场景
- 简单信息检索
- 格式转换
- 模板填充
- 直接的事实问答
- 批量处理

**成本提醒**: 推理模式会显著增加 token 消耗（思考过程也计费）

---

## 批量 vs 单次处理

### 批量处理适用场景
- 大量相似任务
- 可以容忍部分失败
- 时间不紧迫
- 成本敏感

**策略**: 用 Tier 3 模型批量处理，失败的用 Tier 2 重试

### 单次处理适用场景
- 一次性任务
- 需要高准确率
- 时间紧迫
- 任务复杂度高

**策略**: 直接用匹配复杂度的模型

---

## OpenClaw 配置建议

### 基础配置（性价比优先）
```json5
{
  agents: {
    defaults: {
      model: {
        primary: "anthropic/claude-sonnet-4-5",
        fallbacks: ["anthropic/claude-haiku-4-5"]
      }
    }
  }
}
```

### 高质量配置（准确率优先）
```json5
{
  agents: {
    defaults: {
      model: {
        primary: "anthropic/claude-opus-4-5",
        fallbacks: ["anthropic/claude-sonnet-4-5"]
      }
    }
  }
}
```

### 成本敏感配置
```json5
{
  agents: {
    defaults: {
      model: {
        primary: "anthropic/claude-haiku-4-5",
        fallbacks: ["openrouter/meta-llama/llama-3.3-70b-instruct"]
      }
    }
  }
}
```

### 混合策略（推荐）
- 主会话用 Sonnet
- 子任务/批量用 Haiku
- 关键决策临时切换 Opus (`/model opus`)

---

## 模型能力边界

### Claude 系列
- **Opus**: 最强推理，最贵，适合复杂任务
- **Sonnet**: 平衡之选，日常主力
- **Haiku**: 快速便宜，简单任务

### GPT 系列
- **GPT-5.2**: 顶级能力，工具调用强
- **GPT-5**: 主力模型
- **GPT-4.1 mini/nano**: 轻量快速

### 开源/国产
- **Kimi K2.5**: 性价比高，中文好
- **GLM-4.7**: 工具调用强
- **MiniMax M2.1**: 写作和创意好
- **DeepSeek V3**: 免费，能力不错

---

## 实用技巧

1. **动态切换**
   ```
   /model opus    # 临时切换到 Opus 处理复杂任务
   /model sonnet  # 切回 Sonnet
   ```

2. **子任务降级**
   用 `sessions_spawn` 时指定便宜模型：
   ```
   sessions_spawn(task="简单任务", model="anthropic/claude-haiku-4-5")
   ```

3. **失败重试升级**
   简单任务先用便宜模型，失败了再用贵的

4. **缓存利用**
   - 保持会话连续性，利用 prompt cache
   - Heartbeat 保持缓存热度

---

## 成本监控

- `/status` - 查看当前会话成本
- `/usage full` - 每条回复显示 token 消耗
- `/usage cost` - 查看累计成本

---

## 总结

**模型选择三问**:
1. 任务有多复杂？→ 决定层级
2. 失败代价有多高？→ 决定是否用更强模型
3. 需要处理多少？→ 决定批量策略

**记住**: 最贵的模型不一定最好，最匹配的才是最好的。

---

_参考来源: OpenClaw 文档, Artificial Analysis 模型对比_
