import { sql } from '@/lib/db';
import { requireRedis } from '@/lib/redis';
import { listUserTokenPolicies, evaluateUserTokenAccess } from '@/lib/user-token';

export async function GET() {
  try {
    // 从 event_logs 获取 token 使用统计
    const rows = await sql`
      WITH latest_client_metadata AS (
        SELECT DISTINCT ON (user_token)
          user_token,
          data->>'app_version' AS app_version,
          data->>'app_build_number' AS app_build_number,
          CASE WHEN data->>'is_beta' = 'true' THEN true ELSE false END AS is_beta
        FROM event_logs
        WHERE user_token IS NOT NULL AND data ? 'app_version'
        ORDER BY user_token, created_at DESC
      )
      SELECT
        event_logs.user_token,
        TO_CHAR(MIN(event_logs.created_at AT TIME ZONE 'Asia/Shanghai'), 'YYYY-MM-DD HH24:MI:SS') AS first_event_date,
        TO_CHAR(MAX(event_logs.created_at AT TIME ZONE 'Asia/Shanghai'), 'YYYY-MM-DD HH24:MI:SS') AS last_event_date,
        COUNT(*) AS total_events,
        latest_client_metadata.app_version,
        latest_client_metadata.app_build_number,
        latest_client_metadata.is_beta
      FROM event_logs
      LEFT JOIN latest_client_metadata USING (user_token)
      WHERE event_logs.user_token IS NOT NULL
      GROUP BY event_logs.user_token, latest_client_metadata.app_version, latest_client_metadata.app_build_number, latest_client_metadata.is_beta
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
          app_version: stats?.app_version ?? null,
          app_build_number: stats?.app_build_number ?? null,
          is_beta: stats?.is_beta ?? null,
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
