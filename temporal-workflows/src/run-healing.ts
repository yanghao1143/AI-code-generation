/**
 * 运行自愈
 */

import { Client, Connection } from '@temporalio/client';
import { selfHealingWorkflow } from './workflows';

async function run() {
  const connection = await Connection.connect({ address: 'localhost:7233' });
  const client = new Client({ connection });

  console.log('🔧 运行自愈检查...\n');

  const handle = await client.workflow.start(selfHealingWorkflow, {
    taskQueue: 'haodaer-brain',
    workflowId: `self-healing-${Date.now()}`,
  });

  const result = await handle.result();

  console.log(`📊 结果:`);
  console.log(`   发现问题: ${result.problemsFound}`);
  console.log(`   已修复: ${result.problemsFixed}`);
  console.log(`   已通知: ${result.notified ? '是' : '否'}`);

  await connection.close();
}

run().catch(console.error);
