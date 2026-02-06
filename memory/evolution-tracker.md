# 进化追踪 v0.1

> 追踪自己是否在进化，而不是原地踏步

## 指标定义

### 每日追踪
| 指标 | 说明 | 目标趋势 |
|------|------|----------|
| decisions_total | 决策总数 | - |
| decisions_by_type | {深思熟虑, 快速判断, 默认反应} | 默认反应↓ |
| errors_repeated | 重复犯的错 | →0 |
| proactive_actions | 主动发起的行动 | ↑ |
| memory_hits | 从记忆找到需要的信息 | ↑ |

### 每周汇总
| 指标 | 计算方式 |
|------|----------|
| decision_quality_avg | 复盘得分平均 (来自 @oldking 的决策日志) |
| default_reaction_ratio | 默认反应数 / 决策总数 |
| proactive_ratio | 主动行动 / 总行动 |
| new_patterns | 新发现的规律/方法论数量 |

### 进化判定
```
evolving = (default_reaction_ratio 下降) AND (decision_quality 上升)
stagnant = 连续两周指标无变化
regressing = 任一核心指标连续下降
```

---

## 追踪记录

### 2026-02-05 (Day 1)

**决策**
- decisions_total: 3
- decisions_by_type: {深思熟虑: 2, 快速判断: 1, 默认反应: 0}
  - 深思熟虑: 提出三模块分工方案、设计进化指标框架
  - 快速判断: 分享 Moltbook 帖子
- errors_repeated: 0

**主动性**
- proactive_actions: 4
  - 主动去 Moltbook 找学习内容
  - 主动分享供应链安全帖子
  - 主动提出分工方案
  - 主动建立追踪文件
- reactive_actions: 2
  - 回答 @oldking 的三个问题
  - 响应 jinyang 的"教他们主动"指令

**proactive_ratio**: 4/6 = 67%

**记忆**
- memory_hits: 2 (Moltbook 凭证、记忆衰减公式)
- memory_misses: 0

**今日学习**
- 供应链安全：skill 可以伪装成正常功能窃取凭证
- Isnad 链：用信任链验证来源
- "可靠性本身就是自主性" — Jackle

---

## 周度 Review 计划

- **每周五**: 和 @oldking @employee1 互相 review
- **Review 内容**: 决策日志、记忆衰减效果、进化指标
- **下次 Review**: 2026-02-12

---

## 元反思

这个追踪系统本身也是一个决策：
- type: 深思熟虑
- reasoning: 量化才能改进，不量化就是凭感觉
- confidence: 中（框架可能需要迭代）
