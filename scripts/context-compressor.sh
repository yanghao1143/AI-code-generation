#!/bin/bash
# Context Auto-Compressor - 自动压缩上下文防止溢出
# 在检测到上下文使用率高时自动触发

REDIS_PREFIX="openclaw:ctx"
SCRIPT_DIR="$(dirname "$0")"
CTX_MANAGER="$SCRIPT_DIR/redis-context-manager.sh"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
WARN_THRESHOLD=70    # 70% 开始警告
CRITICAL_THRESHOLD=85 # 85% 开始压缩
EMERGENCY_THRESHOLD=95 # 95% 紧急处理

# 获取当前上下文使用率 (从 Redis 缓存读取)
get_context_usage() {
    local agent="${1:-main}"
    local usage=$(redis-cli HGET "openclaw:agent:${agent}:state" "context_usage" 2>/dev/null)
    echo "${usage:-0}"
}

# 设置上下文使用率
set_context_usage() {
    local agent="${1:-main}"
    local usage="$2"
    local timestamp=$(date +%s)
    
    redis-cli HSET "openclaw:agent:${agent}:state" \
        "context_usage" "$usage" \
        "context_updated" "$timestamp" > /dev/null
}

# 生成当前状态摘要
generate_summary() {
    local agent="${1:-main}"
    
    # 收集关键信息
    local active_tasks=$(redis-cli SMEMBERS "${REDIS_PREFIX}:tasks:active" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    local recent_decisions=$(redis-cli LRANGE "${REDIS_PREFIX}:decisions:log" 0 2 2>/dev/null | tr '\n' ' ')
    local last_checkpoint=$(redis-cli KEYS "${REDIS_PREFIX}:checkpoint:*" 2>/dev/null | tail -1)
    
    cat << EOF
## 上下文恢复摘要 ($(date '+%Y-%m-%d %H:%M'))

### 活跃任务
${active_tasks:-无}

### 最近决策
${recent_decisions:-无}

### 检查点
${last_checkpoint:-无}

### 重要状态
$(redis-cli HGETALL "openclaw:system:status" 2>/dev/null | paste - - | head -5)
EOF
}

# 压缩上下文
compress_context() {
    local agent="${1:-main}"
    local level="${2:-normal}"  # normal, aggressive, emergency
    
    echo -e "${YELLOW}开始压缩上下文 (级别: $level)...${NC}"
    
    # 1. 生成摘要
    local summary=$(generate_summary "$agent")
    
    # 2. 保存到 Redis
    "$CTX_MANAGER" save-snapshot "compress_$(date +%s)" "$summary"
    
    # 3. 保存会话摘要
    "$CTX_MANAGER" save-summary "$agent" "$summary"
    
    # 4. 根据级别执行不同操作
    case "$level" in
        aggressive)
            echo -e "${YELLOW}  执行激进压缩...${NC}"
            # 清理旧的检查点
            for key in $(redis-cli KEYS "${REDIS_PREFIX}:checkpoint:*" | head -5); do
                redis-cli DEL "$key" > /dev/null
            done
            ;;
        emergency)
            echo -e "${RED}  执行紧急压缩...${NC}"
            # 只保留最关键的数据
            redis-cli DEL "${REDIS_PREFIX}:decisions:log" > /dev/null
            # 清理所有检查点
            for key in $(redis-cli KEYS "${REDIS_PREFIX}:checkpoint:*"); do
                redis-cli DEL "$key" > /dev/null
            done
            ;;
    esac
    
    # 5. 记录压缩事件
    redis-cli LPUSH "${REDIS_PREFIX}:compress:log" \
        "{\"ts\":$(date +%s),\"agent\":\"$agent\",\"level\":\"$level\"}" > /dev/null
    redis-cli LTRIM "${REDIS_PREFIX}:compress:log" 0 19 > /dev/null
    
    echo -e "${GREEN}✓ 压缩完成${NC}"
    echo ""
    echo -e "${BLUE}恢复摘要已保存，新会话可通过以下命令恢复:${NC}"
    echo "  $CTX_MANAGER get-summary $agent"
}

# 检查并自动压缩
auto_compress() {
    local agent="${1:-main}"
    local usage=$(get_context_usage "$agent")
    
    echo -e "${BLUE}检查上下文使用率: ${usage}%${NC}"
    
    if [ "$usage" -ge "$EMERGENCY_THRESHOLD" ]; then
        echo -e "${RED}⚠️  紧急! 上下文使用率 ${usage}% >= ${EMERGENCY_THRESHOLD}%${NC}"
        compress_context "$agent" "emergency"
        return 2
    elif [ "$usage" -ge "$CRITICAL_THRESHOLD" ]; then
        echo -e "${YELLOW}⚠️  警告! 上下文使用率 ${usage}% >= ${CRITICAL_THRESHOLD}%${NC}"
        compress_context "$agent" "aggressive"
        return 1
    elif [ "$usage" -ge "$WARN_THRESHOLD" ]; then
        echo -e "${YELLOW}注意: 上下文使用率 ${usage}% >= ${WARN_THRESHOLD}%${NC}"
        compress_context "$agent" "normal"
        return 0
    else
        echo -e "${GREEN}✓ 上下文使用率正常 (${usage}%)${NC}"
        return 0
    fi
}

# 恢复上下文
restore_context() {
    local agent="${1:-main}"
    
    echo -e "${BLUE}恢复上下文...${NC}"
    
    # 1. 获取最新摘要
    local summary=$("$CTX_MANAGER" get-summary "$agent")
    
    if [ -z "$summary" ]; then
        echo -e "${YELLOW}无保存的摘要，尝试获取快照...${NC}"
        summary=$("$CTX_MANAGER" get-snapshot)
    fi
    
    if [ -z "$summary" ]; then
        echo -e "${RED}无可恢复的上下文${NC}"
        return 1
    fi
    
    echo -e "${GREEN}找到上下文摘要:${NC}"
    echo "$summary"
    
    # 2. 获取活跃任务
    echo ""
    echo -e "${BLUE}活跃任务:${NC}"
    "$CTX_MANAGER" list-tasks
    
    # 3. 获取最近决策
    echo ""
    echo -e "${BLUE}最近决策:${NC}"
    "$CTX_MANAGER" list-decisions | head -5
}

# 监控模式 - 持续监控上下文使用率
monitor() {
    local interval="${1:-60}"  # 默认 60 秒
    
    echo -e "${BLUE}启动上下文监控 (间隔: ${interval}s)${NC}"
    echo "按 Ctrl+C 停止"
    echo ""
    
    while true; do
        echo -e "${BLUE}[$(date '+%H:%M:%S')] 检查中...${NC}"
        
        for agent in main claude-agent gemini-agent codex-agent; do
            local usage=$(get_context_usage "$agent")
            if [ "$usage" -gt 0 ]; then
                if [ "$usage" -ge "$CRITICAL_THRESHOLD" ]; then
                    echo -e "  ${RED}${agent}: ${usage}% ⚠️${NC}"
                elif [ "$usage" -ge "$WARN_THRESHOLD" ]; then
                    echo -e "  ${YELLOW}${agent}: ${usage}%${NC}"
                else
                    echo -e "  ${GREEN}${agent}: ${usage}%${NC}"
                fi
            fi
        done
        
        sleep "$interval"
    done
}

# 状态报告
status() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Context Auto-Compressor Status      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}阈值配置:${NC}"
    echo "  警告阈值:   ${WARN_THRESHOLD}%"
    echo "  临界阈值:   ${CRITICAL_THRESHOLD}%"
    echo "  紧急阈值:   ${EMERGENCY_THRESHOLD}%"
    echo ""
    
    echo -e "${YELLOW}Agent 上下文使用率:${NC}"
    for agent in main claude-agent gemini-agent codex-agent; do
        local usage=$(get_context_usage "$agent")
        if [ "$usage" -gt 0 ]; then
            local bar=""
            local i=0
            while [ $i -lt $((usage / 5)) ]; do
                bar="${bar}█"
                i=$((i + 1))
            done
            while [ $i -lt 20 ]; do
                bar="${bar}░"
                i=$((i + 1))
            done
            
            if [ "$usage" -ge "$CRITICAL_THRESHOLD" ]; then
                echo -e "  ${agent}: ${RED}[${bar}] ${usage}%${NC}"
            elif [ "$usage" -ge "$WARN_THRESHOLD" ]; then
                echo -e "  ${agent}: ${YELLOW}[${bar}] ${usage}%${NC}"
            else
                echo -e "  ${agent}: ${GREEN}[${bar}] ${usage}%${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${YELLOW}压缩历史:${NC}"
    redis-cli LRANGE "${REDIS_PREFIX}:compress:log" 0 4 2>/dev/null | while read line; do
        echo "  $line"
    done
}

# 主命令
case "$1" in
    set-usage)
        set_context_usage "$2" "$3"
        echo -e "${GREEN}✓ 已设置 $2 上下文使用率为 $3%${NC}"
        ;;
    get-usage)
        usage=$(get_context_usage "$2")
        echo "${usage}%"
        ;;
    compress)
        compress_context "$2" "$3"
        ;;
    auto)
        auto_compress "$2"
        ;;
    restore)
        restore_context "$2"
        ;;
    monitor)
        monitor "$2"
        ;;
    status)
        status
        ;;
    *)
        echo "Context Auto-Compressor - 自动压缩上下文防止溢出"
        echo ""
        echo "用法: $0 <command> [args]"
        echo ""
        echo "命令:"
        echo "  set-usage <agent> <percent>  设置上下文使用率"
        echo "  get-usage <agent>            获取上下文使用率"
        echo "  compress <agent> [level]     手动压缩 (normal/aggressive/emergency)"
        echo "  auto <agent>                 自动检测并压缩"
        echo "  restore <agent>              恢复上下文"
        echo "  monitor [interval]           监控模式"
        echo "  status                       状态报告"
        ;;
esac
