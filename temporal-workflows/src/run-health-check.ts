/**
 * 启动健康检查 Workflow
 */

import { Client, Connection } from '@temporalio/client';
import { singleHealthCheckWorkflow, healthMonitorWorkflow } from './workflows';

async function run() {
  const connection = await Connection.connect({ address: 'localhost:7233' });
  const client = new Client({ connection });

  const args = process.argv.slice(2);
  const mode = args[0] || 'single';

  if (mode === 'monitor') {
    // 启动持续监控
    const handle = await client.workflow.start(healthMonitorWorkflow, {
      taskQueue: 'haodaer-brain',
      workflowId: 'health-monitor',
      args: [5], // 每5分钟检查一次
    });
    console.log(`🔄 持续监控已启动: ${handle.workflowId}`);
    console.log(`   查看: http://localhost:8233/namespaces/default/workflows/${handle.workflowId}`);
  } else {
    // 单次检查
    const handle = await client.workflow.start(singleHealthCheckWorkflow, {
      taskQueue: 'haodaer-brain',
      workflowId: `health-check-${Date.now()}`,
    });
    
    console.log(`🏥 健康检查已启动: ${handle.workflowId}`);
    const result = await handle.result();
    
    console.log('\n📊 健康报告:');
    console.log(`   状态: ${result.overallHealth}`);
    console.log(`   Agent 数量: ${result.agents.length}`);
    
    for (const agent of result.agents) {
      const icon = agent.alive ? '✅' : '❌';
      console.log(`   ${icon} ${agent.name}: ${agent.diagnosis}`);
    }
    
    if (result.issues.length > 0) {
      console.log('\n⚠️ 问题:');
      result.issues.forEach(i => console.log(`   - ${i}`));
    }
    
    if (result.recommendations.length > 0) {
      console.log('\n💡 建议:');
      result.recommendations.forEach(r => console.log(`   - ${r}`));
    }
  }

  await connection.close();
}

run().catch(console.error);
