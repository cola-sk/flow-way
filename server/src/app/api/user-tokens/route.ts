import { sql } from '@/lib/db';
import { requireRedis } from '@/lib/redis';
import { listUserTokenPolicies, evaluateUserTokenAccess } from '@/lib/user-token';

export async function GET() {
  try {
    // 从 event_logs 获取 token 使用统计
    const tokens = await sql`
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

    // 从 Redis 获取 token policy 信息
    const redis = requireRedis();
    const policies = await listUserTokenPolicies(redis);
    const policyMap = new Map(policies.map((p) => [p.token, p]));

    // 合并：统计 + policy
    const merged = await Promise.all(
      tokens.map(async (row: any) => {
        const token = row.user_token as string;
        const policy = policyMap.get(token);
        let state = 'unknown';
        let expiresAt: string | null = null;
        let validity = 'unknown';

        if (policy) {
          const access = await evaluateUserTokenAccess(redis, token);
          state = access.state;
          validity = policy.validity;
          expiresAt = policy.expiresAt ?? null;
        }

        return {
          ...row,
          state,
          validity,
          expiresAt,
        };
      })
    );

    return Response.json(merged);
  } catch (error) {
    console.error('Failed to fetch user tokens:', error);
    return Response.json({ error: 'Failed to fetch user tokens' }, { status: 500 });
  }
}