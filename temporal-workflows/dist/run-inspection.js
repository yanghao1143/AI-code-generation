"use strict";
/**
 * 运行综合巡检
 */
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@temporalio/client");
const workflows_1 = require("./workflows");
async function run() {
    const connection = await client_1.Connection.connect({ address: 'localhost:7233' });
    const client = new client_1.Client({ connection });
    console.log('🔍 启动综合巡检...\n');
    const handle = await client.workflow.start(workflows_1.fullInspectionWorkflow, {
        taskQueue: 'haodaer-brain',
        workflowId: `inspection-${Date.now()}`,
    });
    const result = await handle.result();
    // 健康报告
    console.log('📊 Agent 健康状态:');
    console.log(`   整体: ${result.health.overallHealth}`);
    for (const agent of result.health.agents) {
        const icon = agent.alive ? '✅' : '❌';
        console.log(`   ${icon} ${agent.name}: ${agent.diagnosis}`);
    }
    // 代码审查
    console.log('\n🔧 代码审查:');
    console.log(`   TypeScript: ${result.codeReview.typescript.hasErrors ? '❌ ' + result.codeReview.typescript.errorCount + ' 错误' : '✅ 无错误'}`);
    console.log(`   构建: ${result.codeReview.build.hasErrors ? '❌ 失败' : '✅ 成功'} (${result.codeReview.build.buildTime}ms)`);
    console.log(`   警告: ${result.codeReview.build.warningCount} 个`);
    // Git 状态
    console.log('\n📁 Git 状态:');
    console.log(`   分支: ${result.codeReview.git.branch}`);
    console.log(`   修改: ${result.codeReview.git.modified} 个文件`);
    console.log(`   未跟踪: ${result.codeReview.git.untracked} 个文件`);
    console.log(`   最近提交: ${result.codeReview.git.lastCommit} (${result.codeReview.git.lastCommitTime})`);
    // 问题和建议
    if (result.health.issues.length > 0) {
        console.log('\n⚠️ 问题:');
        result.health.issues.forEach(i => console.log(`   - ${i}`));
    }
    await connection.close();
}
run().catch(console.error);
