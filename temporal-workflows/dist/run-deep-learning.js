"use strict";
/**
 * 运行深度学习
 */
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@temporalio/client");
const workflows_1 = require("./workflows");
async function run() {
    const connection = await client_1.Connection.connect({ address: 'localhost:7233' });
    const client = new client_1.Client({ connection });
    console.log('🧠 运行深度学习...\n');
    const handle = await client.workflow.start(workflows_1.deepLearningWorkflow, {
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
