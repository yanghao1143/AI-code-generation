/**
 * 运行学习进化
 */

import { Client, Connection } from '@temporalio/client';
import { learningEvolutionWorkflow } from './workflows';

async function run() {
  const connection = await Connection.connect({ address: 'localhost:7233' });
  const client = new Client({ connection });

  console.log('🧬 启动学习进化...\n');

  const handle = await client.workflow.start(learningEvolutionWorkflow, {
    taskQueue: 'haodaer-brain',
    workflowId: `learning-${Date.now()}`,
  });

  const result = await handle.result();

  console.log('📊 学习结果:');
  console.log(`   发现模式: ${result.insights.length} 个`);
  
  if (result.insights.length > 0) {
    console.log('\n🔍 模式详情:');
    for (const insight of result.insights) {
      console.log(`   - ${insight.pattern}`);
      console.log(`     频率: ${insight.frequency}, 置信度: ${(insight.confidence * 100).toFixed(0)}%`);
      console.log(`     建议: ${insight.suggestion}`);
    }
  }

  console.log(`\n📚 历史学习: ${result.learnings.length} 条`);
  if (result.learnings.length > 0) {
    result.learnings.slice(0, 5).forEach(l => console.log(`   - ${l.slice(0, 80)}...`));
  }

  await connection.close();
}

run().catch(console.error);
