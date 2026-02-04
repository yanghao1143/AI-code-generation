/**
 * 设置定时任务
 */

import { Client, Connection, ScheduleOverlapPolicy } from '@temporalio/client';

async function setupSchedules() {
  const connection = await Connection.connect({ address: 'localhost:7233' });
  const client = new Client({ connection });

  console.log('⏰ 设置定时任务...\n');

  const schedules = [
    { id: 'daily-summary', cron: '55 23 * * *', workflow: 'dailySummaryWorkflow', desc: '每日总结: 每天 23:55' },
    { id: 'full-inspection', cron: '0 */2 * * *', workflow: 'fullInspectionWorkflow', desc: '综合巡检: 每 2 小时' },
    { id: 'system-monitor', cron: '*/30 * * * *', workflow: 'systemMonitorWorkflow', desc: '系统监控: 每 30 分钟' },
    { id: 'learning-evolution', cron: '0 22 * * *', workflow: 'learningEvolutionWorkflow', desc: '学习进化: 每天 22:00' },
    { id: 'proactive-report', cron: '0 10,15,20 * * *', workflow: 'proactiveReportWorkflow', desc: '主动汇报: 每天 10:00, 15:00, 20:00' },
    { id: 'director-review', cron: '0 9,14,18 * * *', workflow: 'directorDailyReviewWorkflow', desc: '技术总监巡检: 每天 9:00, 14:00, 18:00' },
    { id: 'self-healing', cron: '*/15 * * * *', workflow: 'selfHealingWorkflow', desc: '自愈检查: 每 15 分钟' },
  ];

  for (const s of schedules) {
    try {
      await client.schedule.create({
        scheduleId: s.id,
        spec: { cronExpressions: [s.cron] },
        action: {
          type: 'startWorkflow',
          workflowType: s.workflow,
          taskQueue: 'haodaer-brain',
          workflowId: `${s.id}-{{.ScheduledTime.Format "2006-01-02-15-04"}}`,
        },
        policies: { overlap: ScheduleOverlapPolicy.SKIP },
      });
      console.log(`✅ ${s.desc}`);
    } catch (e: any) {
      if (e.message?.includes('already exists')) console.log(`⏭️ ${s.desc.split(':')[0]}: 已存在`);
      else console.log(`❌ ${s.desc.split(':')[0]}:`, e.message);
    }
  }

  console.log('\n📋 当前定时任务:');
  for await (const schedule of client.schedule.list()) {
    console.log(`   - ${schedule.scheduleId}`);
  }

  await connection.close();
}

setupSchedules().catch(console.error);
