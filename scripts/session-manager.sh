#!/bin/bash
# Session Manager - PostgreSQL + Redis 会话管理系统
# 用途: 归档、清理、修复 OpenClaw 会话

set -e

SESSIONS_DIR="$HOME/.openclaw/agents/main/sessions"
BACKUP_DIR="$SESSIONS_DIR/archive"
PG_DB="openclaw"
PG_USER="openclaw"
PG_PASS="openclaw123"
REDIS_PREFIX="openclaw:session"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] WARN:${NC} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ERROR:${NC} $1"; }

# 初始化 PostgreSQL 表
init_db() {
    log "初始化 PostgreSQL 会话表..."
    PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB << 'SQL'
-- 会话归档表
CREATE TABLE IF NOT EXISTS session_archive (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(64) NOT NULL,
    session_key VARCHAR(256),
    session_type VARCHAR(32),  -- main, cron, spawn
    created_at TIMESTAMP DEFAULT NOW(),
    archived_at TIMESTAMP DEFAULT NOW(),
    message_count INT DEFAULT 0,
    total_tokens INT DEFAULT 0,
    file_size_bytes INT DEFAULT 0,
    content JSONB,  -- 压缩后的会话内容
    raw_file TEXT,  -- 原始 jsonl 内容 (可选)
    metadata JSONB,
    UNIQUE(session_id)
);

-- 会话健康状态表
CREATE TABLE IF NOT EXISTS session_health (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(64) NOT NULL,
    checked_at TIMESTAMP DEFAULT NOW(),
    is_valid BOOLEAN DEFAULT true,
    error_type VARCHAR(64),
    error_message TEXT,
    auto_fixed BOOLEAN DEFAULT false,
    UNIQUE(session_id, checked_at)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_session_archive_key ON session_archive(session_key);
CREATE INDEX IF NOT EXISTS idx_session_archive_type ON session_archive(session_type);
CREATE INDEX IF NOT EXISTS idx_session_archive_created ON session_archive(created_at);
CREATE INDEX IF NOT EXISTS idx_session_health_valid ON session_health(is_valid);

SELECT 'Tables created successfully' as status;
SQL
    log "数据库初始化完成"
}

# 检查会话文件是否有效
validate_session() {
    local file="$1"
    local session_id=$(basename "$file" .jsonl)
    
    # 基本 JSON 验证
    if ! head -1 "$file" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        echo "invalid_json"
        return
    fi
    
    # 检查消息格式 (简化检查)
    local has_invalid=$(python3 << PYEOF
import json
import sys

try:
    with open("$file", 'r') as f:
        for line in f:
            if not line.strip():
                continue
            data = json.loads(line)
            # 检查 assistant 消息的 content 格式
            if data.get('type') == 'message' and data.get('role') == 'assistant':
                content = data.get('content', [])
                if isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict):
                            # 检查是否缺少必需字段
                            if 'type' not in item:
                                print('missing_type')
                                sys.exit(0)
    print('valid')
except Exception as e:
    print(f'error:{e}')
PYEOF
)
    echo "$has_invalid"
}

# 归档会话到 PostgreSQL
archive_session() {
    local file="$1"
    local session_id=$(basename "$file" .jsonl)
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
    local msg_count=$(wc -l < "$file")
    
    log "归档会话: $session_id"
    
    # 提取会话元数据
    local metadata=$(head -1 "$file" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(json.dumps({
    'version': data.get('version'),
    'cwd': data.get('cwd'),
    'timestamp': data.get('timestamp')
}))
" 2>/dev/null || echo '{}')
    
    # 压缩内容存入数据库
    local content=$(cat "$file" | gzip | base64 -w0)
    
    PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -c "
INSERT INTO session_archive (session_id, message_count, file_size_bytes, metadata, raw_file)
VALUES ('$session_id', $msg_count, $file_size, '$metadata'::jsonb, '$content')
ON CONFLICT (session_id) DO UPDATE SET
    archived_at = NOW(),
    message_count = $msg_count,
    file_size_bytes = $file_size;
" 2>/dev/null
    
    echo "$session_id"
}

# 清理旧的 cron 会话
cleanup_cron_sessions() {
    local days_old=${1:-3}
    log "清理 ${days_old} 天前的 cron 会话..."
    
    mkdir -p "$BACKUP_DIR"
    
    local count=0
    cd "$SESSIONS_DIR"
    
    # 找到旧的 cron 会话
    for file in *.jsonl; do
        [[ -f "$file" ]] || continue
        
        # 检查文件年龄
        local file_age=$(( ($(date +%s) - $(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file")) / 86400 ))
        
        if [[ $file_age -ge $days_old ]]; then
            local session_id=$(basename "$file" .jsonl)
            
            # 检查是否是 cron 会话 (不是 main)
            if grep -q "cron" "$SESSIONS_DIR/../sessions.json" 2>/dev/null | grep -q "$session_id"; then
                # 归档到数据库
                archive_session "$file"
                
                # 移动到备份目录
                mv "$file" "$BACKUP_DIR/"
                ((count++))
            fi
        fi
    done
    
    log "清理完成: 归档了 $count 个会话"
}

# 修复损坏的会话
fix_corrupted_sessions() {
    log "扫描并修复损坏的会话..."
    
    mkdir -p "$BACKUP_DIR/corrupted"
    
    local fixed=0
    local removed=0
    
    cd "$SESSIONS_DIR"
    for file in *.jsonl; do
        [[ -f "$file" ]] || continue
        
        local status=$(validate_session "$file")
        local session_id=$(basename "$file" .jsonl)
        
        if [[ "$status" != "valid" ]]; then
            warn "发现损坏会话: $session_id ($status)"
            
            # 记录到数据库
            PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -c "
INSERT INTO session_health (session_id, is_valid, error_type, error_message)
VALUES ('$session_id', false, '$status', 'Auto-detected corruption')
ON CONFLICT DO NOTHING;
" 2>/dev/null
            
            # 归档后删除
            archive_session "$file"
            mv "$file" "$BACKUP_DIR/corrupted/"
            ((removed++))
        fi
    done
    
    log "修复完成: 移除了 $removed 个损坏会话"
    
    # 更新 Redis 状态
    redis-cli SET "${REDIS_PREFIX}:last_cleanup" "$(date +%s)" > /dev/null
    redis-cli SET "${REDIS_PREFIX}:corrupted_count" "$removed" > /dev/null
}

# 从 sessions.json 中移除无效会话
sync_sessions_json() {
    log "同步 sessions.json..."
    
    cd "$SESSIONS_DIR"
    
    python3 << 'PYEOF'
import json
import os

sessions_file = 'sessions.json'
backup_file = 'sessions.json.bak'

# 备份
import shutil
shutil.copy(sessions_file, backup_file)

with open(sessions_file, 'r') as f:
    data = json.load(f)

# 获取所有存在的 session 文件
existing_files = set(f.replace('.jsonl', '') for f in os.listdir('.') if f.endswith('.jsonl'))

# 过滤掉不存在的会话
removed = []
for key in list(data.keys()):
    if isinstance(data[key], dict):
        session_id = data[key].get('sessionId')
        if session_id and session_id not in existing_files:
            removed.append(key)
            del data[key]

if removed:
    with open(sessions_file, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"移除了 {len(removed)} 个无效会话引用")
else:
    print("sessions.json 已同步")
PYEOF
}

# 状态报告
status() {
    echo "=== Session Manager 状态 ==="
    echo ""
    
    # 文件统计
    local total_files=$(ls -1 "$SESSIONS_DIR"/*.jsonl 2>/dev/null | wc -l)
    local total_size=$(du -sh "$SESSIONS_DIR" 2>/dev/null | cut -f1)
    local archived=$(ls -1 "$BACKUP_DIR"/*.jsonl 2>/dev/null | wc -l)
    
    echo "📁 会话文件: $total_files 个 ($total_size)"
    echo "📦 已归档: $archived 个"
    
    # 数据库统计
    local db_count=$(PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -t -c "SELECT COUNT(*) FROM session_archive;" 2>/dev/null | tr -d ' ')
    local corrupted=$(PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -t -c "SELECT COUNT(*) FROM session_health WHERE is_valid = false;" 2>/dev/null | tr -d ' ')
    
    echo "🗄️  数据库归档: ${db_count:-0} 个"
    echo "⚠️  历史损坏: ${corrupted:-0} 个"
    
    # Redis 状态
    local last_cleanup=$(redis-cli GET "${REDIS_PREFIX}:last_cleanup" 2>/dev/null)
    if [[ -n "$last_cleanup" ]]; then
        local cleanup_date=$(date -d "@$last_cleanup" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$last_cleanup" "+%Y-%m-%d %H:%M")
        echo "🕐 上次清理: $cleanup_date"
    fi
    
    echo ""
}

# 主命令
case "${1:-status}" in
    init)
        init_db
        ;;
    cleanup)
        cleanup_cron_sessions "${2:-3}"
        sync_sessions_json
        ;;
    fix)
        fix_corrupted_sessions
        sync_sessions_json
        ;;
    archive)
        if [[ -n "$2" ]]; then
            archive_session "$SESSIONS_DIR/$2.jsonl"
        else
            error "请指定 session_id"
        fi
        ;;
    sync)
        sync_sessions_json
        ;;
    status)
        status
        ;;
    *)
        echo "用法: $0 {init|cleanup|fix|archive|sync|status}"
        echo ""
        echo "命令:"
        echo "  init     - 初始化数据库表"
        echo "  cleanup  - 清理旧的 cron 会话 (默认3天)"
        echo "  fix      - 修复损坏的会话"
        echo "  archive  - 归档指定会话"
        echo "  sync     - 同步 sessions.json"
        echo "  status   - 显示状态"
        ;;
esac
