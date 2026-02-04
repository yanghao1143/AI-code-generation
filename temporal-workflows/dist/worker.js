"use strict";
/**
 * 好大儿的神经系统 - Worker
 * 运行 Activities 和 Workflows
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const worker_1 = require("@temporalio/worker");
const activities = __importStar(require("./activities"));
const extActivities = __importStar(require("./activities-extended"));
const capabilities = __importStar(require("./capabilities"));
async function run() {
    const worker = await worker_1.Worker.create({
        workflowsPath: require.resolve('./workflows'),
        activities: { ...activities, ...extActivities, ...capabilities },
        taskQueue: 'haodaer-brain',
    });
    console.log('🧠 好大儿的神经系统启动...');
    console.log('📡 Task Queue: haodaer-brain');
    console.log('🎯 能力: 健康监控 | 项目管理 | 团队协调 | 技术决策');
    await worker.run();
}
run().catch((err) => {
    console.error('❌ Worker 启动失败:', err);
    process.exit(1);
});
