/**
 * 运行技术总监日常巡检
 */

import { Client, Connection } from '@temporalio/client';
import { directorDailyReviewWorkflow } from './workflows-director';

async function run() {
  const connection = await Connection.connect({ address: 'localhost:7233' });
  const client = new Client({ connection });

  console.log('👔 技术总监日常巡检...\n');

  const handle = await client.workflow.start(directorDailyReviewWorkflow, {
    taskQueue: 'haodaer-brain',
    workflowId: `director-review-${Date.now()}`,
  });

  const result = await handle.result();

  console.log(result.projectSummary);
  console.log('\n' + result.teamStatus);
  
  if (result.issues.length > 0) {
    console.log('\n⚠️ 发现问题:');
    result.issues.forEach(i => console.log(`   - ${i}`));
  }
  
  if (result.actions.length > 0) {
    console.log('\n✅ 已执行行动:');
    result.actions.forEach(a => console.log(`   - ${a}`));
  }

  await connection.close();
}

run().catch(console.error);
