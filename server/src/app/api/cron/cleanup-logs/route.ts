import { NextResponse } from 'next/server';
import { sql } from '@/lib/db';

const LOG_RETENTION_DAYS = 7;

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
      WITH deleted AS (
        DELETE FROM event_logs
        WHERE created_at < NOW() - INTERVAL '7 days'
        RETURNING 1
      )
      SELECT COUNT(*)::int AS deleted FROM deleted
    `;
    const deleted = Number(result[0]?.deleted ?? 0);
    console.info(
      `[cleanup-logs] deleted ${deleted} rows older than ${LOG_RETENTION_DAYS} days`
    );
    return NextResponse.json({ ok: true, deleted, retentionDays: LOG_RETENTION_DAYS });
  } catch (error) {
    console.error('[cleanup-logs] failed:', error);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
