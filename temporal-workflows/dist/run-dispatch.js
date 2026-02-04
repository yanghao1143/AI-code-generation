"use strict";
/**
 * 运行智能任务调度
 */
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@temporalio/client");
const workflows_1 = require("./workflows");
async function run() {
    const connection = await client_1.Connection.connect({ address: 'localhost:7233' });
    const client = new client_1.Client({ connection });
    const task = process.argv[2] || '检查项目状态并汇报';
    console.log(`🎯 智能调度任务: "${task}"\n`);
    const handle = await client.workflow.start(workflows_1.smartDispatchWorkflow, {
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
