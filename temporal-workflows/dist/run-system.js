"use strict";
/**
 * 运行系统监控
 */
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@temporalio/client");
const workflows_1 = require("./workflows");
async function run() {
    const connection = await client_1.Connection.connect({ address: 'localhost:7233' });
    const client = new client_1.Client({ connection });
    console.log('🖥️ 系统健康检查...\n');
    const handle = await client.workflow.start(workflows_1.systemMonitorWorkflow, {
        taskQueue: 'haodaer-brain',
        workflowId: `system-${Date.now()}`,
    });
    const health = await handle.result();
    console.log('📊 系统状态:');
    console.log(`   Redis:      ${health.redis ? '✅' : '❌'}`);
    console.log(`   PostgreSQL: ${health.postgres ? '✅' : '❌'}`);
    console.log(`   Temporal:   ${health.temporal ? '✅' : '❌'}`);
    console.log(`   磁盘使用:   ${health.diskUsage}%`);
    console.log(`   内存使用:   ${health.memoryUsage}%`);
    await connection.close();
}
run().catch(console.error);
