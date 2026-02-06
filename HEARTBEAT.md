# HEARTBEAT.md

## 每次心跳

1. `session_status` - 检查上下文使用率
   - **>60%**: 生成摘要并保存 `./scripts/session-compress.sh compress main "摘要" <ctx%>`
   - **>70%**: 警告用户，建议 /new
   - **>85%**: 强烈建议 /new，主动压缩
2. `redis-cli ping` + `./scripts/pg-memory.sh status`
3. 推进一个任务或学习一个东西
4. 更新 memory/heartbeat-state.json

## 每周任务

- 运行 `./scripts/archive-old-memories.sh` 归档旧日志

## 夜间 (02:00-06:00)

做 1-2 件维护任务，写报告到 memory/nightly-build/
