/**
 * 好大儿的神经系统 - Worker
 * 运行 Activities 和 Workflows
 */

import { Worker } from '@temporalio/worker';
import * as activities from './activities';
import * as extActivities from './activities-extended';
import * as capabilities from './capabilities';

async function run() {
  const worker = await Worker.create({
    workflowsPath: require.resolve('./workflows'),
    activities: { ...activities, ...extActivities, ...capabilities },
    taskQueue: 'haodaer-brain',
  });

  console.log('🧠 好大儿的神经系统启动...');
  console.log('📡 Task Queue: haodaer-brain');
  console.log('🎯 能力: 健康监控 | 项目管理 | 团队协调 | 技术决策');
  
  await worker.run();
}

run().catch((err) => {
  console.error('❌ Worker 启动失败:', err);
  process.exit(1);
});
