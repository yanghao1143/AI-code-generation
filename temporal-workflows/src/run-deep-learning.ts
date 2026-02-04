/**
 * 运行深度学习
 */

import { Client, Connection } from '@temporalio/client';
import { deepLearningWorkflow } from './workflows';

async function run() {
  const connection = await Connection.connect({ address: 'localhost:7233' });
  const client = new Client({ connection });

  console.log('🧠 运行深度学习...\n');

  const handle = await client.workflow.start(deepLearningWorkflow, {
    taskQueue: 'haodaer-brain',
    workflowId: `deep-learning-${Date.now()}`,
  });

  const result = await handle.result();

  console.log(`📊 结果:`);
  console.log(`   发现模式: ${result.patternsFound}`);
  console.log(`   生成洞察: ${result.insightsGenerated}`);
  console.log(`   保存知识: ${result.knowledgeSaved}`);

  await connection.close();
}

run().catch(console.error);
