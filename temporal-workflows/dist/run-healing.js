"use strict";
/**
 * 运行自愈
 */
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@temporalio/client");
const workflows_1 = require("./workflows");
async function run() {
    const connection = await client_1.Connection.connect({ address: 'localhost:7233' });
    const client = new client_1.Client({ connection });
    console.log('🔧 运行自愈检查...\n');
    const handle = await client.workflow.start(workflows_1.selfHealingWorkflow, {
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
