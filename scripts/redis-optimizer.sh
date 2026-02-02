#!/bin/bash
# Redis 优化脚本 - 清理冗余数据，统一命名，设置 TTL

REDIS_PREFIX="openclaw"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. 统一命名规范 (下划线 → 连字符)
normalize_keys() {
    echo -e "${BLUE}=== 统一命名规范 ===${NC}"
    
    # code_review → code-review
    for key in $(redis-cli KEYS "*code_review*"); do
        new_key=$(echo "$key" | sed 's/code_review/code-review/g')
        if [ "$key" != "$new_key" ]; then
            echo "  $key → $new_key"
            redis-cli RENAME "$key" "$new_key" 2>/dev/null || redis-cli DEL "$key"
        fi
    done
    
    echo -e "${GREEN}✓ 命名规范化完成${NC}"
}

# 2. 清理历史数据 (保留最近 N 条)
cleanup_history() {
    echo -e "${BLUE}=== 清理历史数据 ===${NC}"
    
    # 死锁恢复记录 - 保留最近 3 条
    echo "  清理死锁恢复记录..."
    keys=$(redis-cli KEYS "openclaw:deadlock:recovery:*" | sort -r)
    count=0
    for key in $keys; do
        count=$((count + 1))
        if [ $count -gt 3 ]; then
            redis-cli DEL "$key" > /dev/null
            echo "    删除: $key"
        fi
    done
    
    # 上下文监控记录 - 保留最近 5 条
    echo "  清理上下文监控记录..."
    keys=$(redis-cli KEYS "openclaw:context:monitor:*" | sort -r)
    count=0
    for key in $keys; do
        count=$((count + 1))
        if [ $count -gt 5 ]; then
            redis-cli DEL "$key" > /dev/null
            echo "    删除: $key"
        fi
    done
    
    # 代码审查记录 - 保留最近 5 条
    echo "  清理代码审查记录..."
    keys=$(redis-cli KEYS "openclaw:code-review:2*" | sort -r)
    count=0
    for key in $keys; do
        count=$((count + 1))
        if [ $count -gt 5 ]; then
            redis-cli DEL "$key" > /dev/null
            echo "    删除: $key"
        fi
    done
    
    echo -e "${GREEN}✓ 历史数据清理完成${NC}"
}

# 3. 设置 TTL (防止数据无限增长)
set_ttls() {
    echo -e "${BLUE}=== 设置 TTL ===${NC}"
    
    # 临时数据 - 1 小时
    for pattern in "openclaw:scheduler:running" "openclaw:scheduler:pending"; do
        for key in $(redis-cli KEYS "$pattern"); do
            redis-cli EXPIRE "$key" 3600 > /dev/null
            echo "  $key: 1h"
        done
    done
    
    # 状态数据 - 24 小时
    for pattern in "openclaw:agent:*:state" "openclaw:context:current" "openclaw:pipeline:status"; do
        for key in $(redis-cli KEYS "$pattern"); do
            redis-cli EXPIRE "$key" 86400 > /dev/null
            echo "  $key: 24h"
        done
    done
    
    # 历史记录 - 7 天
    for pattern in "openclaw:deadlock:recovery:*" "openclaw:context:monitor:*" "openclaw:code-review:2*"; do
        for key in $(redis-cli KEYS "$pattern"); do
            redis-cli EXPIRE "$key" 604800 > /dev/null
            echo "  $key: 7d"
        done
    done
    
    # 学习数据 - 30 天
    for pattern in "openclaw:learning:*" "openclaw:learn:*"; do
        for key in $(redis-cli KEYS "$pattern"); do
            redis-cli EXPIRE "$key" 2592000 > /dev/null
            echo "  $key: 30d"
        done
    done
    
    echo -e "${GREEN}✓ TTL 设置完成${NC}"
}

# 4. 合并冗余 key
merge_redundant() {
    echo -e "${BLUE}=== 合并冗余 Key ===${NC}"
    
    # learn → learning
    for key in $(redis-cli KEYS "openclaw:learn:*"); do
        new_key=$(echo "$key" | sed 's/:learn:/:learning:/g')
        if [ "$key" != "$new_key" ]; then
            # 检查目标是否存在
            exists=$(redis-cli EXISTS "$new_key")
            if [ "$exists" -eq 0 ]; then
                echo "  $key → $new_key"
                redis-cli RENAME "$key" "$new_key" 2>/dev/null
            else
                echo "  删除重复: $key"
                redis-cli DEL "$key" > /dev/null
            fi
        fi
    done
    
    echo -e "${GREEN}✓ 合并完成${NC}"
}

# 5. 删除无用 key
cleanup_unused() {
    echo -e "${BLUE}=== 清理无用 Key ===${NC}"
    
    # 测试 key
    for key in $(redis-cli KEYS "openclaw:test:key*"); do
        redis-cli DEL "$key" > /dev/null
        echo "  删除: $key"
    done
    
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 6. 状态报告
report() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       Redis 优化状态报告               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    # 内存
    memory=$(redis-cli INFO memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
    echo -e "  ${YELLOW}内存使用:${NC} $memory"
    
    # Key 数量
    total=$(redis-cli KEYS "openclaw:*" | wc -l)
    echo -e "  ${YELLOW}总 Key 数:${NC} $total"
    
    # TTL 统计
    with_ttl=0
    without_ttl=0
    for key in $(redis-cli KEYS "openclaw:*"); do
        ttl=$(redis-cli TTL "$key")
        if [ "$ttl" -gt 0 ]; then
            with_ttl=$((with_ttl + 1))
        else
            without_ttl=$((without_ttl + 1))
        fi
    done
    echo -e "  ${YELLOW}有 TTL:${NC} $with_ttl"
    echo -e "  ${YELLOW}无 TTL:${NC} $without_ttl"
    
    echo ""
    echo -e "${BLUE}命名空间分布:${NC}"
    redis-cli KEYS "openclaw:*" | cut -d: -f2 | sort | uniq -c | sort -rn | head -10 | while read count ns; do
        printf "  %-20s %d\n" "$ns" "$count"
    done
}

# 主命令
case "$1" in
    all)
        normalize_keys
        echo ""
        cleanup_history
        echo ""
        merge_redundant
        echo ""
        cleanup_unused
        echo ""
        set_ttls
        echo ""
        report
        ;;
    normalize)
        normalize_keys
        ;;
    cleanup)
        cleanup_history
        cleanup_unused
        ;;
    ttl)
        set_ttls
        ;;
    merge)
        merge_redundant
        ;;
    report)
        report
        ;;
    *)
        echo "Redis 优化脚本"
        echo ""
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  all       执行所有优化"
        echo "  normalize 统一命名规范"
        echo "  cleanup   清理历史数据"
        echo "  ttl       设置过期时间"
        echo "  merge     合并冗余 key"
        echo "  report    状态报告"
        ;;
esac
