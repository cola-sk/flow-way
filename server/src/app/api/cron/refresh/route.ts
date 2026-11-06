import { NextResponse } from 'next/server';
import { refreshCameras } from '@/lib/cache';
import { getLatestCameraDiffReport } from '@/lib/camera-changes';

/**
 * Vercel Cron Job 端点：定时刷新摄像头数据
 * 配置见 vercel.json 中的 crons
 */
export async function GET(request: Request) {
  // 验证 Vercel Cron 密钥
  const authHeader = request.headers.get('authorization');
  if (
    process.env.CRON_SECRET &&
    authHeader !== `Bearer ${process.env.CRON_SECRET}`
  ) {
    console.warn('[camera-cron] unauthorized request rejected');
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    console.info('[camera-cron] refresh job started');
    const { cameras, updatedAt } = await refreshCameras();
    console.info(
      `[camera-cron] refresh job succeeded: total=${cameras.length}, sourceUpdatedAt=${updatedAt}`
    );

    let diffSummary = null;
    try {
      const report = await getLatestCameraDiffReport();
      if (report) {
        diffSummary = {
          totalChanges: report.totalChanges,
          added: report.addedCount,
          removed: report.removedCount,
          typeChanged: report.typeChangedCount,
          infoChanged: report.infoChangedCount,
        };
      }
    } catch (_) {
      // 容错兜底：变动读取异常绝不影响定时任务正常返回
    }

    return NextResponse.json({
      ok: true,
      total: cameras.length,
      updatedAt,
      diffSummary,
    });
  } catch (error) {
    console.error('[camera-cron] refresh job failed', error);
    return NextResponse.json(
      { error: 'Refresh failed' },
      { status: 500 }
    );
  }
}
