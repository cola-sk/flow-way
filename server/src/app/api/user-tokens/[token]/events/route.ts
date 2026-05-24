import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> }
) {
  try {
    const { token } = await params;

    const searchParams = request.nextUrl.searchParams;
    const limit = Math.min(Math.max(Number(searchParams.get('limit') ?? 200), 1), 500);
    const offset = Math.max(Number(searchParams.get('offset') ?? 0), 0);

    const rows = await sql`
      SELECT
        id,
        event,
        user_token,
        data,
        created_at AT TIME ZONE 'Asia/Shanghai' AS created_at
      FROM event_logs
      WHERE user_token = ${token}
      ORDER BY created_at DESC
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    const countResult = await sql`
      SELECT COUNT(*) AS total
      FROM event_logs
      WHERE user_token = ${token}
    `;
    const total = Number((countResult as any[])[0]?.total ?? 0);

    return NextResponse.json({
      token,
      total,
      events: rows,
      limit,
      offset,
    });
  } catch (error) {
    console.error('Failed to fetch token events:', error);
    return NextResponse.json({ error: 'Failed to fetch token events' }, { status: 500 });
  }
}
