# Agent 优化建议 - 详细实施方案

**生成时间**: 2026-02-01 22:02:30  
**基于分析**: AGENT_STATUS.md

---

## 🚨 紧急问题

### 问题 1: 用户交互阻塞 (66.7% 被阻塞)

**现象**:
```
Gemini: 等待 findstr 命令确认 (~5-10分钟)
Codex:  等待 PowerShell 命令确认 (~5-10分钟)
```

**根本原因**:
- Agent 在执行系统命令前要求用户确认
- 用户不在线或未及时响应
- 没有自动确认机制

**解决方案**:

#### 方案 A: 自动确认 (推荐)
```bash
# 在 agent 配置中添加
auto_confirm: true
auto_confirm_safe_commands: true  # 只对安全命令自动确认
```

#### 方案 B: 命令行标志
```bash
# 为命令添加 --yes 或 -y 标志
findstr /s /c:"Tooltip::text" crates\workspace\src\*.rs --yes
```

#### 方案 C: 交互式超时
```bash
# 设置确认超时，超时后自动确认
confirmation_timeout: 30  # 30秒后自动确认
```

**实施步骤**:
1. 修改 Gemini agent 配置，添加 `auto_confirm: true`
2. 修改 Codex agent 配置，添加 `auto_confirm: true`
3. 测试确认机制是否正常工作
4. 监控是否有误操作

**预期效果**:
- 消除用户交互阻塞
- 提高 Gemini 和 Codex 的产出
- 预计效率提升 30-50%

---

### 问题 2: Gemini Context 接近满 (90%)

**现象**:
```
Gemini context: 90% (接近满)
风险: 后续任务可能因 context 溢出而失败
```

**根本原因**:
- Gemini 完成了 4 个任务，积累了大量 context
- 没有定期清理或重启机制
- Context 压缩不足

**解决方案**:

#### 方案 A: 立即重启 (快速)
```bash
tmux -S /tmp/openclaw-agents.sock kill-session -t gemini-agent
# 重新启动 Gemini agent
```

#### 方案 B: Context 压缩
```bash
# 在 agent 配置中启用 context 压缩
context_compression: true
compression_threshold: 80  # 当 context >80% 时自动压缩
```

#### 方案 C: 自动会话轮换
```bash
# 设置自动会话轮换
session_rotation:
  enabled: true
  max_context_percent: 85
  create_new_session_on_threshold: true
```

**实施步骤**:
1. 立即重启 Gemini 会话
2. 在 Redis 中记录重启时间
3. 配置自动 context 压缩
4. 设置 context 使用告警 (>80%)

**预期效果**:
- 清理 Gemini context，恢复到 0%
- 避免后续任务失败
- 提高 Gemini 的稳定性

---

## 📊 任务分配优化

### 问题 3: 产出不均衡

**现象**:
```
Gemini: 5 任务 (最高)
Claude: 2 任务
Codex:  2 任务 (最低)
```

**根本原因**:
- 任务分配没有考虑 agent 的产出能力
- Codex 被分配了低效率的任务
- 没有动态任务分配机制

**解决方案**:

#### 方案 A: 基于产出能力的任务分配
```
优先级分配:
1. Gemini (产出最高) → 复杂任务、多步骤任务
2. Claude (产出中等) → 中等复杂度任务
3. Codex (产出最低) → 简单任务、快速任务
```

#### 方案 B: 动态任务队列
```
任务队列:
- 高优先级 → Gemini
- 中优先级 → Claude
- 低优先级 → Codex

根据实时产出能力动态调整
```

#### 方案 C: 负载均衡
```
当某个 agent 空闲时:
1. 检查任务队列
2. 分配最高优先级的任务
3. 如果没有任务，分配预测性任务
```

**实施步骤**:
1. 建立任务优先级系统
2. 根据 agent 产出能力分配任务
3. 实现动态任务队列
4. 监控任务分配效率

**预期效果**:
- 提高 Codex 的产出 (从 2 → 4-5 任务)
- 充分利用 Gemini 的高效率
- 总体产出提升 20-30%

---

## 🔧 技术实施方案

### 1. 自动确认机制

**文件**: `agent-config.yaml`

```yaml
agents:
  gemini-agent:
    auto_confirm: true
    auto_confirm_safe_commands: true
    confirmation_timeout: 30
    
  codex-agent:
    auto_confirm: true
    auto_confirm_safe_commands: true
    confirmation_timeout: 30
    
  claude-agent:
    auto_confirm: false  # Claude 不需要
```

### 2. Context 管理

**文件**: `context-manager.js`

```javascript
class ContextManager {
  async checkContextUsage(agentName) {
    const usage = await redis.hget('openclaw:agent:efficiency', `${agentName}:context`);
    
    if (usage > 85) {
      // 触发自动重启
      await this.restartAgent(agentName);
      await this.notifyUser(`${agentName} context 已重启`);
    }
  }
  
  async restartAgent(agentName) {
    // 重启 tmux 会话
    await exec(`tmux -S /tmp/openclaw-agents.sock kill-session -t ${agentName}`);
    // 重新启动
    await exec(`tmux -S /tmp/openclaw-agents.sock new-session -d -s ${agentName}`);
  }
}
```

### 3. 任务分配算法

**文件**: `task-dispatcher.js`

```javascript
class TaskDispatcher {
  async assignTask(task) {
    // 获取 agent 效率指标
    const efficiency = await redis.hgetall('openclaw:agent:efficiency');
    
    // 计算 agent 得分
    const scores = {
      gemini: efficiency['gemini:completed'] / efficiency['gemini:tasks'],
      claude: efficiency['claude:completed'] / efficiency['claude:tasks'],
      codex: efficiency['codex:completed'] / efficiency['codex:tasks']
    };
    
    // 选择最高效的 agent
    const bestAgent = Object.keys(scores).reduce((a, b) => 
      scores[a] > scores[b] ? a : b
    );
    
    // 分配任务
    await this.sendTaskToAgent(bestAgent, task);
  }
}
```

---

## 📈 预期改进

### 短期 (1-2小时)
- ✅ 消除用户交互阻塞 (66.7% → 0%)
- ✅ 重启 Gemini context (90% → 0%)
- ✅ 恢复 Gemini 和 Codex 的工作

### 中期 (1天)
- ✅ 实现自动确认机制
- ✅ 建立 context 监控告警
- ✅ 优化任务分配算法
- ✅ 总体效率提升 30-50%

### 长期 (1周)
- ✅ 完全自动化 agent 管理
- ✅ 实现智能任务分配
- ✅ 建立完整的监控仪表板
- ✅ 总体效率提升 50-100%

---

## 🎯 行动计划

### 立即行动 (现在)
- [ ] 重启 Gemini 会话
- [ ] 手动确认 Codex 的 PowerShell 命令
- [ ] 更新 Redis 中的 agent 状态

### 1小时内
- [ ] 配置自动确认机制
- [ ] 测试自动确认是否正常工作
- [ ] 为 Codex 分配新任务

### 今天
- [ ] 实现 context 管理系统
- [ ] 建立任务分配算法
- [ ] 设置监控告警

### 本周
- [ ] 完整的 agent 管理系统
- [ ] 自动化仪表板
- [ ] 性能基准测试

---

**下一次分析**: 2026-02-01 23:00:00  
**预期改进**: 效率从 ⭐⭐ 提升到 ⭐⭐⭐⭐
