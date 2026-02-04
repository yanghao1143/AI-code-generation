#!/bin/bash
# scripts/auto-recover.sh - 自动恢复服务
# 尝试恢复挂掉的服务

SERVICE=$1

case $SERVICE in
    redis)
        echo "尝试重启 Redis..."
        sudo systemctl restart redis
        sleep 2
        redis-cli ping && echo "Redis 恢复成功" || echo "Redis 恢复失败"
        ;;
    postgres)
        echo "尝试重启 PostgreSQL..."
        sudo systemctl restart postgresql
        sleep 3
        PGPASSWORD="openclaw123" psql -h localhost -U openclaw -d openclaw -c "SELECT 1" && echo "PostgreSQL 恢复成功" || echo "PostgreSQL 恢复失败"
        ;;
    claude-agent)
        echo "尝试重启 Claude agent..."
        tmux -S /tmp/openclaw-agents.sock kill-session -t claude-agent 2>/dev/null
        sleep 1
        tmux -S /tmp/openclaw-agents.sock new-session -d -s claude-agent -c "/mnt/d/ai软件/zed"
        tmux -S /tmp/openclaw-agents.sock send-keys -t claude-agent "claude --dangerously-skip-permissions" Enter
        echo "Claude agent 重启完成"
        ;;
    gemini-agent)
        echo "尝试重启 Gemini agent..."
        tmux -S /tmp/openclaw-agents.sock kill-session -t gemini-agent 2>/dev/null
        sleep 1
        tmux -S /tmp/openclaw-agents.sock new-session -d -s gemini-agent -c "/mnt/d/ai软件/zed"
        tmux -S /tmp/openclaw-agents.sock send-keys -t gemini-agent "gemini" Enter
        echo "Gemini agent 重启完成"
        ;;
    codex-agent)
        echo "Codex 在 Windows 上运行，无法从 WSL 重启"
        echo "降级方案：将任务路由到 Gemini"
        ;;
    *)
        echo "未知服务: $SERVICE"
        echo "可用服务: redis, postgres, claude-agent, gemini-agent, codex-agent"
        exit 1
        ;;
esac
