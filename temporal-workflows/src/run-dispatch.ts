/**
 * 运行智能任务调度
 */

import { Client, Connection } from '@temporalio/client';
import { smartDispatchWorkflow } from './workflows';

async function run() {
  const connection = await Connection.connect({ address: 'localhost:7233' });
  const client = new Client({ connection });

  const task = process.argv[2] || '检查项目状态并汇报';
  
  console.log(`🎯 智能调度任务: "${task}"\n`);

  const handle = await client.workflow.start(smartDispatchWorkflow, {
    taskQueue: 'haodaer-brain',
    workflowId: `dispatch-${Date.now()}`,
    args: [task],
  });

  const result = await handle.result();

  console.log(`✅ 任务已派发给: ${result.agent}`);
  console.log(`   成功: ${result.success ? '是' : '否'}`);

  await connection.close();
}

run().catch(console.error);
