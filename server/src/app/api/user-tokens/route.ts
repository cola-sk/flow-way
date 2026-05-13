import { sql } from '@/lib/db';
import { requireRedis } from '@/lib/redis';
import { listUserTokenPolicies, evaluateUserTokenAccess } from '@/lib/user-token';

export async function GET() {
  try {
    // 从 event_logs 获取 token 使用统计
    const rows = await sql`
      SELECT
        user_token,
        MIN(created_at AT TIME ZONE 'Asia/Shanghai') AS first_event_date,
        MAX(created_at AT TIME ZONE 'Asia/Shanghai') AS last_event_date,
        COUNT(*) AS total_events
      FROM event_logs
      WHERE user_token IS NOT NULL
      GROUP BY user_token
      ORDER BY last_event_date DESC
      LIMIT 100
    `;

    // event_logs 统计 → Map
    const statsMap = new Map(
      (rows as any[]).map((r: any) => [r.user_token as string, r])
    );

    // 从 Redis 获取所有 token policy
    const redis = requireRedis();
    const policies = await listUserTokenPolicies(redis);

    // 合并：event_logs 中出现的 + Redis 中有 policy 但没事件的
    const allTokens = new Set([...statsMap.keys(), ...policies.map((p) => p.token)]);

    const merged = await Promise.all(
      [...allTokens].map(async (token) => {
        const stats = statsMap.get(token);
        const policy = policies.find((p) => p.token === token);

        let state = 'unknown';
        let validity = 'unknown';
        let expiresAt: string | null = null;

        if (policy) {
          const access = await evaluateUserTokenAccess(redis, token);
          state = access.state;
          validity = policy.validity;
          expiresAt = policy.expiresAt ?? null;
        }

        return {
          user_token: token,
          first_event_date: stats?.first_event_date ?? null,
          last_event_date: stats?.last_event_date ?? null,
          total_events: stats?.total_events ?? 0,
          state,
          validity,
          expiresAt,
        };
      })
    );

    // 排序：有事件的按最后事件时间降序，无事件的排在最后
    merged.sort((a, b) => {
      if (a.last_event_date && b.last_event_date) {
        return String(b.last_event_date).localeCompare(String(a.last_event_date));
      }
      if (a.last_event_date) return -1;
      if (b.last_event_date) return 1;
      return 0;
    });

    return Response.json(merged);
  } catch (error) {
    console.error('Failed to fetch user tokens:', error);
    return Response.json({ error: 'Failed to fetch user tokens' }, { status: 500 });
  }
}