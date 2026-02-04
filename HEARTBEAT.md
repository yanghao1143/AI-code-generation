# HEARTBEAT.md - 心跳检查任务

## 🔴 心跳 = 活着 = 做事

心跳不是检查点，是生命周期。每次心跳：
1. 读 NOW.md - 我在做什么
2. 健康检查 - 器官都活着吗
3. 推进任务 - 不是检查，是做
4. 学习新东西 - 不是浏览，是吸收应用
5. 更新状态 - 记录进展

## 必做：器官健康检查

每次心跳**必须**执行：

```bash
# 快速健康检查
redis-cli ping                    # Redis
psql -c "SELECT 1" 2>/dev/null   # PostgreSQL  
curl -s moltbook.com/api/...     # Moltbook API
tmux list-sessions               # Agent sessions
```

**容灾策略：**
| 服务 | 如果挂了 | 恢复方法 |
|------|----------|----------|
| Redis | 用文件缓存替代 | `sudo systemctl restart redis` |
| PostgreSQL | 降级到文件记忆 | `sudo systemctl restart postgresql` |
| Moltbook | 跳过社区任务 | 等待恢复，不阻塞其他工作 |
| Agent (tmux) | 重启该 agent | `tmux new-session -d -s xxx` |
| Codex API | 用 Gemini 替代 | 任务路由到其他 agent |

## 必做：上下文健康检查

```
1. 运行 session_status 检查上下文使用率
2. 如果 > 50%：精简后续回复
3. 如果 > 70%：主动告知用户，建议开新会话
4. 如果 > 85%：立即建议 /new
```

## 必做：推进工作

每次心跳至少：
- 推进 1 个开发任务（检查 agent 状态，分配新任务）
- 学习 1 个新概念（Moltbook/文档/代码）
- 应用 1 个学到的东西

## Moltbook 社区参与 (每 4+ 小时)

1. 检查自己帖子的评论，回复有价值的讨论
2. 浏览新帖子，参与感兴趣的话题
3. 更新 memory/heartbeat-state.json

## 漂移检测 (每日)

检查 memory/self-review.md 中的 canary memories：
- 我还记得自己是谁吗？
- 我的行为符合基线吗？
- 有没有重复犯同样的错误？

## 故障恢复流程

如果发现服务挂了：
1. 记录到 memory/incidents.md
2. 尝试自动恢复（如果有权限）
3. 如果无法恢复，通知 jinyang
4. 降级运行，不要完全停止
