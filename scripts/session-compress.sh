#!/bin/bash
# session-compress.sh - 会话压缩和摘要管理（v2 - 支持频道分离）
# 用法:
#   ./session-compress.sh compress <session> <summary> [context_pct] [tokens]
#   ./session-compress.sh get <session>
#   ./session-compress.sh get-all <session>    # 获取 shared + channel 摘要
#   ./session-compress.sh history <session>
#   ./session-compress.sh set-shared <summary>  # 设置共享知识
#   ./session-compress.sh get-shared            # 获取共享知识
#
# session 格式:
#   main           → 私聊
#   channel:<id>   → 特定频道
#   mattermost:<channel_id> → Mattermost 频道（别名）

set -e

ACTION="${1:-help}"
SESSION="${2:-main}"
SUMMARY="$3"
CONTEXT_PCT="${4:-0}"
TOKENS="${5:-0}"

# 解析 session 为 Redis key
parse_session_key() {
    local session="$1"
    case "$session" in
        main)
            echo "openclaw:session:main:summary"
            ;;
        channel:*)
            echo "openclaw:session:${session}:summary"
            ;;
        mattermost:*)
            local id="${session#mattermost:}"
            echo "openclaw:session:channel:${id}:summary"
            ;;
        *)
            echo "openclaw:session:${session}:summary"
            ;;
    esac
}

REDIS_KEY=$(parse_session_key "$SESSION")
REDIS_SHARED_KEY="openclaw:session:shared:summary"
PG_TABLE="session_summaries"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[compress]${NC} $1"; }
warn() { echo -e "${YELLOW}[compress]${NC} $1"; }

case "$ACTION" in
    compress)
        if [ -z "$SUMMARY" ]; then
            echo "用法: $0 compress <session> <summary> [context_pct] [tokens]"
            exit 1
        fi
        
        TIMESTAMP=$(date -Iseconds)
        
        if command -v redis-cli &> /dev/null; then
            redis-cli SET "$REDIS_KEY" "$SUMMARY" EX 604800 > /dev/null 2>&1 || true
            log "已存储到 Redis: $REDIS_KEY"
        fi
        
        if command -v psql &> /dev/null; then
            psql -h localhost -U openclaw -d openclaw -c "
                INSERT INTO $PG_TABLE (session_id, summary, context_pct, tokens, created_at)
                VALUES ('$SESSION', '$SUMMARY', $CONTEXT_PCT, $TOKENS, '$TIMESTAMP')
                ON CONFLICT DO NOTHING;
            " > /dev/null 2>&1 || warn "PostgreSQL 存储失败"
        fi
        
        log "✅ 压缩完成: $SESSION"
        ;;
        
    get)
        if command -v redis-cli &> /dev/null; then
            SUMMARY=$(redis-cli GET "$REDIS_KEY" 2>/dev/null || echo "")
            if [ -n "$SUMMARY" ]; then echo "$SUMMARY"; exit 0; fi
        fi
        echo "无上次摘要"
        ;;
        
    get-all)
        echo "=== 共享知识 ==="
        if command -v redis-cli &> /dev/null; then
            SHARED=$(redis-cli GET "$REDIS_SHARED_KEY" 2>/dev/null || echo "")
            [ -n "$SHARED" ] && echo "$SHARED" || echo "(无)"
        fi
        echo -e "\n=== 频道上下文: $SESSION ==="
        if command -v redis-cli &> /dev/null; then
            CHANNEL=$(redis-cli GET "$REDIS_KEY" 2>/dev/null || echo "")
            [ -n "$CHANNEL" ] && echo "$CHANNEL" || echo "(无)"
        fi
        ;;
        
    set-shared)
        if [ -z "$SESSION" ] || [ "$SESSION" = "main" ]; then
            echo "用法: $0 set-shared <summary>"; exit 1
        fi
        if command -v redis-cli &> /dev/null; then
            redis-cli SET "$REDIS_SHARED_KEY" "$SESSION" EX 2592000 > /dev/null 2>&1 || true
            log "已存储共享知识 (30天过期)"
        fi
        ;;
        
    get-shared)
        if command -v redis-cli &> /dev/null; then
            SHARED=$(redis-cli GET "$REDIS_SHARED_KEY" 2>/dev/null || echo "")
            [ -n "$SHARED" ] && echo "$SHARED" && exit 0
        fi
        echo "无共享知识"
        ;;
        
    help|*)
        echo "用法:"
        echo "  $0 compress <session> <summary> [context_pct] [tokens]"
        echo "  $0 get <session>"
        echo "  $0 get-all <session>    # shared + channel"
        echo "  $0 set-shared <summary>"
        echo "  $0 get-shared"
        ;;
esac
