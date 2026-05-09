import { sql } from '@/lib/db';

export async function GET() {
  try {
    const result = await sql`
      SELECT
        user_token,
        MIN(created_at) AS first_event_date,
        MAX(created_at) AS last_event_date,
        COUNT(*) AS total_events
      FROM event_logs
      WHERE user_token IS NOT NULL
      GROUP BY user_token
      ORDER BY last_event_date DESC
      LIMIT 100
    `;

    return Response.json(result);
  } catch (error) {
    console.error('Failed to fetch user tokens:', error);
    return Response.json({ error: 'Failed to fetch user tokens' }, { status: 500 });
  }
}
