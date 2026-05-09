import { NextResponse } from 'next/server';
import { sql } from '@/lib/db';

/**
 * Vercel Cron Job：每天凌晨3点清理7天前的事件日志
 * 配置见 vercel.json 中的 crons
 */
export async function GET(request: Request) {
  const authHeader = request.headers.get('authorization');
  if (
    process.env.CRON_SECRET &&
    authHeader !== `Bearer ${process.env.CRON_SECRET}`
  ) {
    console.warn('[cleanup-logs] unauthorized request rejected');
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const result = await sql`
      DELETE FROM event_logs
      WHERE created_at < NOW() - INTERVAL '7 days'
    `;
    const deleted = result.length ?? 0;
    console.info(`[cleanup-logs] deleted ${deleted} rows older than 7 days`);
    return NextResponse.json({ ok: true, deleted });
  } catch (error) {
    console.error('[cleanup-logs] failed:', error);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
