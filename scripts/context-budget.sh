#!/bin/bash
# context-budget.sh - 上下文预算管理器
# 主动防御上下文溢出，不是被动调参数

WORKSPACE="/home/jinyang/.openclaw/workspace"
REDIS_PREFIX="openclaw:ctx:budget"

# 预算配置
TOTAL_BUDGET=200000      # 总预算 (200K tokens)
RESERVED_NEW=80000       # 保留给新内容
HISTORY_MAX=70000        # 历史上限
SYSTEM_PROMPT=20000      # 系统提示
SAFE_THRESHOLD=30000     # 安全阈值 (剩余空间)

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# ============ 估算当前使用 ============
# 注意: 这是估算，真实值需要从 session_status 获取
estimate_current_usage() {
    # 从 Redis 获取缓存的使用率
    local cached=$(redis-cli GET "${REDIS_PREFIX}:current" 2>/dev/null)
    
    if [[ -n "$cached" ]]; then
        echo "$cached"
        return 0
    fi
    
    # 估算: 基于最近的文件大小
    local memory_size=$(du -k "$WORKSPACE/MEMORY.md" 2>/dev/null | cut -f1)
    local today_size=$(du -k "$WORKSPACE/memory/$(date +%Y-%m-%d).md" 2>/dev/null | cut -f1)
    
    # 粗略估算: 1KB ≈ 250 tokens
    local estimated=$((memory_size * 250 + today_size * 250))
    
    echo "$estimated"
}

# ============ 预测未来增长 ============
predict_growth() {
    # 基于历史增长率预测
    local current="$1"
    
    # 从 Redis 获取历史增长率
    local growth_rate=$(redis-cli GET "${REDIS_PREFIX}:growth_rate" 2>/dev/null)
    growth_rate=${growth_rate:-1.2}  # 默认 20% 增长
    
    # 预测: 当前使用 × 增长率
    local predicted=$(echo "$current * $growth_rate" | bc | cut -d. -f1)
    
    echo "$predicted"
}

# ============ 检查预算 ============
check() {
    log "检查上下文预算..."
    
    local current=$(estimate_current_usage)
    local predicted=$(predict_growth "$current")
    local available=$((TOTAL_BUDGET - current))
    local usage_percent=$((current * 100 / TOTAL_BUDGET))
    
    echo ""
    echo "📊 上下文预算状态:"
    echo "  总预算:     $TOTAL_BUDGET tokens"
    echo "  当前使用:   $current tokens ($usage_percent%)"
    echo "  预测增长:   $predicted tokens"
    echo "  剩余空间:   $available tokens"
    echo ""
    
    # 缓存当前使用
    redis-cli SETEX "${REDIS_PREFIX}:current" 300 "$current" > /dev/null
    
    # 判断状态
    if [[ $available -lt $SAFE_THRESHOLD ]]; then
        error "⚠️ 剩余空间不足 $SAFE_THRESHOLD tokens!"
        echo ""
        echo "建议操作:"
        echo "  1. 运行: $0 compress"
        echo "  2. 或者: /new 开新会话"
        return 1
    elif [[ $usage_percent -gt 70 ]]; then
        warn "使用率超过 70%，建议压缩"
        return 2
    elif [[ $usage_percent -gt 50 ]]; then
        warn "使用率超过 50%，注意控制"
        return 3
    else
        success "预算充足"
        return 0
    fi
}

# ============ 智能压缩 ============
compress() {
    log "开始智能压缩..."
    
    local before=$(estimate_current_usage)
    
    # 1. 压缩每日日志
    log "压缩每日日志..."
    "$WORKSPACE/scripts/context-manager.sh" compress "$(date +%Y-%m-%d)" 2>/dev/null
    
    # 2. 归档旧日志
    log "归档旧日志..."
    "$WORKSPACE/scripts/context-manager.sh" archive 2>/dev/null
    
    # 3. 清理 Redis 缓存
    log "清理过期缓存..."
    local expired=$(redis-cli KEYS "openclaw:ctx:*" 2>/dev/null | wc -l)
    if [[ $expired -gt 100 ]]; then
        redis-cli KEYS "openclaw:ctx:*" 2>/dev/null | xargs redis-cli DEL > /dev/null
        log "清理了 $expired 个缓存 key"
    fi
    
    # 4. 精简 MEMORY.md (如果太大)
    local memory_size=$(du -k "$WORKSPACE/MEMORY.md" 2>/dev/null | cut -f1)
    if [[ $memory_size -gt 10 ]]; then
        warn "MEMORY.md 较大 (${memory_size}KB)，建议手动精简"
        echo "  提示: 将详细内容移到 PostgreSQL，只保留索引"
    fi
    
    local after=$(estimate_current_usage)
    local saved=$((before - after))
    local saved_percent=$((saved * 100 / before))
    
    echo ""
    success "压缩完成"
    echo "  压缩前: $before tokens"
    echo "  压缩后: $after tokens"
    echo "  节省:   $saved tokens ($saved_percent%)"
    
    # 更新增长率 (压缩后重新计算)
    redis-cli SET "${REDIS_PREFIX}:growth_rate" "1.1" > /dev/null
}

# ============ 自动分配 ============
allocate() {
    local session_id="${1:-main}"
    
    log "为会话 $session_id 分配预算..."
    
    # 1. 检查当前状态
    local current=$(estimate_current_usage)
    local available=$((TOTAL_BUDGET - current))
    
    # 2. 如果空间不足，自动压缩
    if [[ $available -lt $SAFE_THRESHOLD ]]; then
        warn "空间不足，自动压缩..."
        compress
        current=$(estimate_current_usage)
        available=$((TOTAL_BUDGET - current))
    fi
    
    # 3. 分配预算
    local allocated=$((available - RESERVED_NEW))
    
    echo ""
    echo "📋 预算分配:"
    echo "  会话 ID:    $session_id"
    echo "  可用空间:   $available tokens"
    echo "  分配额度:   $allocated tokens"
    echo "  保留空间:   $RESERVED_NEW tokens"
    
    # 4. 保存到 Redis
    redis-cli HSET "${REDIS_PREFIX}:session:$session_id" \
        "allocated" "$allocated" \
        "used" "$current" \
        "timestamp" "$(date +%s)" > /dev/null
    
    success "预算已分配"
}

# ============ 监控 ============
monitor() {
    log "启动上下文监控..."
    
    local check_interval=60  # 每分钟检查一次
    local compress_threshold=75  # 超过 75% 自动压缩
    
    while true; do
        local current=$(estimate_current_usage)
        local usage_percent=$((current * 100 / TOTAL_BUDGET))
        
        # 记录到 Redis (用于趋势分析)
        redis-cli LPUSH "${REDIS_PREFIX}:history" "$current" > /dev/null
        redis-cli LTRIM "${REDIS_PREFIX}:history" 0 99 > /dev/null  # 保留最近 100 条
        
        if [[ $usage_percent -gt $compress_threshold ]]; then
            warn "使用率 $usage_percent% > $compress_threshold%，自动压缩"
            compress
            
            # 发送通知
            redis-cli PUBLISH "openclaw:alerts" "上下文使用率过高，已自动压缩" > /dev/null
        fi
        
        sleep "$check_interval"
    done
}

# ============ 趋势分析 ============
trends() {
    log "分析上下文使用趋势..."
    
    # 从 Redis 获取历史数据
    local history=$(redis-cli LRANGE "${REDIS_PREFIX}:history" 0 -1 2>/dev/null)
    
    if [[ -z "$history" ]]; then
        warn "没有历史数据"
        return 1
    fi
    
    # 计算统计
    local count=$(echo "$history" | wc -l)
    local sum=$(echo "$history" | awk '{s+=$1} END {print s}')
    local avg=$((sum / count))
    local max=$(echo "$history" | sort -n | tail -1)
    local min=$(echo "$history" | sort -n | head -1)
    
    echo ""
    echo "📈 使用趋势 (最近 $count 次检查):"
    echo "  平均: $avg tokens"
    echo "  最大: $max tokens"
    echo "  最小: $min tokens"
    echo ""
    
    # 计算增长率
    local first=$(echo "$history" | tail -1)
    local last=$(echo "$history" | head -1)
    local growth_rate=$(echo "scale=2; $last / $first" | bc)
    
    echo "  增长率: ${growth_rate}x"
    
    # 预测何时会溢出
    if [[ $(echo "$growth_rate > 1.0" | bc) -eq 1 ]]; then
        local remaining=$((TOTAL_BUDGET - last))
        local checks_until_full=$(echo "scale=0; $remaining / ($last * ($growth_rate - 1))" | bc)
        local minutes_until_full=$((checks_until_full * 1))  # 假设每分钟检查一次
        
        if [[ $minutes_until_full -lt 60 ]]; then
            error "⚠️ 预计 $minutes_until_full 分钟后溢出!"
        else
            warn "预计 $((minutes_until_full / 60)) 小时后溢出"
        fi
    fi
    
    # 更新增长率到 Redis
    redis-cli SET "${REDIS_PREFIX}:growth_rate" "$growth_rate" > /dev/null
}

# ============ 状态报告 ============
status() {
    local current=$(estimate_current_usage)
    local available=$((TOTAL_BUDGET - current))
    local usage_percent=$((current * 100 / TOTAL_BUDGET))
    
    # 状态指示器
    local status_icon="✅"
    local status_text="正常"
    
    if [[ $usage_percent -gt 85 ]]; then
        status_icon="🚨"
        status_text="危险"
    elif [[ $usage_percent -gt 70 ]]; then
        status_icon="⚠️"
        status_text="警告"
    elif [[ $usage_percent -gt 50 ]]; then
        status_icon="📊"
        status_text="注意"
    fi
    
    echo "$status_icon 上下文: $current / $TOTAL_BUDGET tokens ($usage_percent%) - $status_text"
}

# ============ 帮助 ============
help() {
    cat << EOF
🎯 上下文预算管理器 - 主动防御上下文溢出

用法: $0 <command> [args...]

命令:
  check              - 检查当前预算状态
  compress           - 智能压缩历史内容
  allocate [session] - 为会话分配预算
  monitor            - 启动实时监控 (守护进程)
  trends             - 分析使用趋势
  status             - 简要状态 (用于 HEARTBEAT)

配置:
  TOTAL_BUDGET=$TOTAL_BUDGET       总预算
  RESERVED_NEW=$RESERVED_NEW       保留给新内容
  HISTORY_MAX=$HISTORY_MAX        历史上限
  SAFE_THRESHOLD=$SAFE_THRESHOLD     安全阈值

示例:
  $0 check                    # 检查预算
  $0 compress                 # 压缩历史
  $0 monitor &                # 后台监控
  $0 trends                   # 查看趋势

集成到 HEARTBEAT.md:
  每次心跳运行: $0 check
  如果返回非 0: $0 compress

守护进程 (systemd):
  sudo systemctl start context-budget-monitor
EOF
}

# ============ 主入口 ============
case "${1:-help}" in
    check) check ;;
    compress) compress ;;
    allocate) shift; allocate "$@" ;;
    monitor) monitor ;;
    trends) trends ;;
    status) status ;;
    help|--help|-h) help ;;
    *)
        error "未知命令: $1"
        echo ""
        help
        exit 1
        ;;
esac
