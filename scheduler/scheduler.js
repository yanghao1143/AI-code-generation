#!/usr/bin/env node
/**
 * Redis 任务队列调度器
 * 支持并发控制、优先级、任务去重
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// 配置
const CONFIG = {
  concurrency: {
    max_total: 6,
    max_opus: 2,
    max_sonnet: 3,
    max_haiku: 5
  },
  redis: {
    queue_pending: 'openclaw:scheduler:pending',
    queue_running: 'openclaw:scheduler:running',
    task_prefix: 'openclaw:scheduler:task:',
    last_run_prefix: 'openclaw:scheduler:last_run:'
  },
  models: {
    opus: 'anthropic/claude-opus-4-5-20251101',
    sonnet: 'anthropic/claude-sonnet-4-5-20250929',
    haiku: 'anthropic/claude-haiku-4-5-20251001'
  }
};

// 任务定义
const TASKS = [
  {
    id: 'commander_patrol',
    name: '综合巡检',
    model: 'sonnet',
    priority: 100,
    interval_ms: 180000,  // 3分钟
    message: '【综合巡检】检查 tmux 会话 (socket: /tmp/openclaw-agents.sock)，处理确认，派发任务，审查代码。'
  },
  {
    id: 'deadlock_detect',
    name: '死锁检测',
    model: 'haiku',
    priority: 50,  // 高优先级
    interval_ms: 120000,  // 2分钟
    message: '【死锁检测】检查 tmux 会话是否卡死（>5分钟无输出），卡死则 Ctrl+C 并重新派活。'
  },
  {
    id: 'health_monitor',
    name: '健康监控',
    model: 'haiku',
    priority: 150,
    interval_ms: 600000,  // 10分钟
    message: '【健康监控】检查 context 使用率，<20% 警告，<10% 建议换新会话。'
  },
  {
    id: 'code_quality',
    name: '代码质量',
    model: 'haiku',
    priority: 200,
    interval_ms: 1800000,  // 30分钟
    message: '【代码质量】扫描 cc_switch 和 multi_model_dispatch，检查 unused imports、TODO、复杂度。'
  },
  {
    id: 'progress_report',
    name: '进度汇报',
    model: 'sonnet',
    priority: 150,
    interval_ms: 900000,  // 15分钟
    message: '【进度汇报】汇报三个 agent 的工作进度，用表格和 emoji。'
  },
  {
    id: 'build_test',
    name: '编译测试',
    model: 'sonnet',
    priority: 100,
    interval_ms: 1800000,  // 30分钟
    message: '【编译测试】运行 cargo check 和 cargo test，失败则派修复任务。'
  },
  {
    id: 'git_docs',
    name: 'Git文档',
    model: 'haiku',
    priority: 300,
    interval_ms: 1800000,  // 30分钟
    message: '【Git文档】检查未提交改动，更新文档，git commit+push。'
  },
  {
    id: 'security_scan',
    name: '安全扫描',
    model: 'haiku',
    priority: 300,
    interval_ms: 7200000,  // 2小时
    message: '【安全扫描】检查依赖安全、注释质量、性能热点。'
  }
];

// Redis 命令执行
function redis(cmd) {
  try {
    return execSync(`redis-cli ${cmd}`, { encoding: 'utf8' }).trim();
  } catch (e) {
    console.error(`Redis error: ${e.message}`);
    return '';
  }
}

// 获取运行中任务数
function getRunningCount(model = null) {
  const running = redis(`SMEMBERS ${CONFIG.redis.queue_running}`).split('\n').filter(Boolean);
  if (!model) return running.length;
  
  return running.filter(taskId => {
    const taskModel = redis(`HGET ${CONFIG.redis.task_prefix}${taskId} model`);
    return taskModel === model;
  }).length;
}

// 检查是否可以执行
function canExecute(model) {
  const total = getRunningCount();
  const modelCount = getRunningCount(model);
  
  if (total >= CONFIG.concurrency.max_total) return false;
  
  switch (model) {
    case 'opus': return modelCount < CONFIG.concurrency.max_opus;
    case 'sonnet': return modelCount < CONFIG.concurrency.max_sonnet;
    case 'haiku': return modelCount < CONFIG.concurrency.max_haiku;
    default: return true;
  }
}

// 检查任务是否到期
function isTaskDue(taskId, intervalMs) {
  const lastRun = redis(`GET ${CONFIG.redis.last_run_prefix}${taskId}`);
  if (!lastRun) return true;
  
  const elapsed = Date.now() - parseInt(lastRun);
  return elapsed >= intervalMs;
}

// 检查任务是否已在队列
function isTaskQueued(taskId) {
  const inPending = redis(`ZSCORE ${CONFIG.redis.queue_pending} ${taskId}`);
  const inRunning = redis(`SISMEMBER ${CONFIG.redis.queue_running} ${taskId}`);
  return inPending !== '' || inRunning === '1';
}

// 入队任务
function enqueueTask(task) {
  const { id, model, priority, message } = task;
  
  // 存储任务详情
  redis(`HSET ${CONFIG.redis.task_prefix}${id} model ${model} status pending enqueued_at ${Date.now()}`);
  redis(`HSET ${CONFIG.redis.task_prefix}${id} message "${message.replace(/"/g, '\\"')}"`);
  
  // 添加到待执行队列
  redis(`ZADD ${CONFIG.redis.queue_pending} ${priority} ${id}`);
  
  console.log(`📥 入队: ${id} (优先级: ${priority}, 模型: ${model})`);
}

// 执行任务
async function executeTask(taskId) {
  const model = redis(`HGET ${CONFIG.redis.task_prefix}${taskId} model`);
  const message = redis(`HGET ${CONFIG.redis.task_prefix}${taskId} message`);
  
  if (!canExecute(model)) {
    console.log(`⏸️ 跳过 ${taskId}: ${model} 并发已满`);
    return false;
  }
  
  // 移动到运行队列
  redis(`ZREM ${CONFIG.redis.queue_pending} ${taskId}`);
  redis(`SADD ${CONFIG.redis.queue_running} ${taskId}`);
  redis(`HSET ${CONFIG.redis.task_prefix}${taskId} status running started_at ${Date.now()}`);
  
  console.log(`🚀 执行: ${taskId} (模型: ${model})`);
  
  // 输出 spawn 命令供外部执行
  const fullModel = CONFIG.models[model] || model;
  console.log(`SPAWN|${taskId}|${fullModel}|${message}`);
  
  return true;
}

// 完成任务
function completeTask(taskId, status = 'ok') {
  redis(`SREM ${CONFIG.redis.queue_running} ${taskId}`);
  redis(`HSET ${CONFIG.redis.task_prefix}${taskId} status ${status} completed_at ${Date.now()}`);
  redis(`SET ${CONFIG.redis.last_run_prefix}${taskId} ${Date.now()}`);
  
  console.log(`✅ 完成: ${taskId} (${status})`);
}

// 调度
function schedule() {
  console.log(`\n=== 调度器运行 ${new Date().toLocaleString()} ===`);
  console.log(`并发限制: 总计=${CONFIG.concurrency.max_total}, opus=${CONFIG.concurrency.max_opus}, sonnet=${CONFIG.concurrency.max_sonnet}, haiku=${CONFIG.concurrency.max_haiku}`);
  
  // 检查到期任务并入队
  for (const task of TASKS) {
    if (isTaskDue(task.id, task.interval_ms) && !isTaskQueued(task.id)) {
      enqueueTask(task);
    }
  }
  
  // 获取待执行任务
  const pendingCount = parseInt(redis(`ZCARD ${CONFIG.redis.queue_pending}`) || '0');
  const runningCount = getRunningCount();
  
  console.log(`\n📋 队列状态: 运行中=${runningCount}, 待执行=${pendingCount}`);
  
  // 按优先级取任务执行
  const slotsAvailable = CONFIG.concurrency.max_total - runningCount;
  if (slotsAvailable > 0 && pendingCount > 0) {
    const tasksToRun = redis(`ZRANGE ${CONFIG.redis.queue_pending} 0 ${slotsAvailable - 1}`).split('\n').filter(Boolean);
    
    for (const taskId of tasksToRun) {
      executeTask(taskId);
    }
  }
  
  // 显示状态
  showStatus();
}

// 显示状态
function showStatus() {
  const running = redis(`SMEMBERS ${CONFIG.redis.queue_running}`).split('\n').filter(Boolean);
  const pending = redis(`ZRANGE ${CONFIG.redis.queue_pending} 0 -1 WITHSCORES`).split('\n').filter(Boolean);
  
  console.log(`\n📊 当前状态:`);
  console.log(`  运行中 (${running.length}):`);
  for (const taskId of running) {
    const model = redis(`HGET ${CONFIG.redis.task_prefix}${taskId} model`);
    const started = redis(`HGET ${CONFIG.redis.task_prefix}${taskId} started_at`);
    const elapsed = started ? Math.round((Date.now() - parseInt(started)) / 1000) : 0;
    console.log(`    - ${taskId} (${model}, ${elapsed}s)`);
  }
  
  console.log(`  待执行 (${pending.length / 2}):`);
  for (let i = 0; i < pending.length; i += 2) {
    const taskId = pending[i];
    const priority = pending[i + 1];
    const model = redis(`HGET ${CONFIG.redis.task_prefix}${taskId} model`);
    console.log(`    - ${taskId} (优先级: ${priority}, ${model})`);
  }
}

// 清理
function cleanup() {
  console.log('🧹 清理队列...');
  redis(`DEL ${CONFIG.redis.queue_pending} ${CONFIG.redis.queue_running}`);
  
  // 清理任务详情
  const taskKeys = redis(`KEYS ${CONFIG.redis.task_prefix}*`).split('\n').filter(Boolean);
  for (const key of taskKeys) {
    redis(`DEL ${key}`);
  }
  
  // 清理 last_run
  const lastRunKeys = redis(`KEYS ${CONFIG.redis.last_run_prefix}*`).split('\n').filter(Boolean);
  for (const key of lastRunKeys) {
    redis(`DEL ${key}`);
  }
  
  console.log('✅ 清理完成');
}

// 主入口
const command = process.argv[2] || 'schedule';

switch (command) {
  case 'schedule':
    schedule();
    break;
  case 'status':
    showStatus();
    break;
  case 'cleanup':
    cleanup();
    break;
  case 'complete':
    completeTask(process.argv[3], process.argv[4] || 'ok');
    break;
  default:
    console.log('用法: node scheduler.js {schedule|status|cleanup|complete <task_id> [status]}');
}
