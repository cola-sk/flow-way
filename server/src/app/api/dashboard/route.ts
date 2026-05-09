import { NextResponse } from 'next/server';
import { sql } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  // 简单鉴权：若设置了 MONITOR_SECRET，需要带 ?secret=xxx
  const secret = process.env.MONITOR_SECRET;
  if (secret) {
    const { searchParams } = new URL(request.url);
    if (searchParams.get('secret') !== secret) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
  }

  const [
    overview,
    installs,
    routePlan,
    navigation,
    cruise,
    daily,
  ] = await Promise.all([
    // 总览
    sql`
      SELECT
        COUNT(DISTINCT user_token) FILTER (WHERE user_token IS NOT NULL) AS total_users,
        COUNT(DISTINCT user_token) FILTER (WHERE user_token IS NOT NULL AND created_at >= (NOW() AT TIME ZONE 'Asia/Shanghai' - INTERVAL '7 days') AT TIME ZONE 'Asia/Shanghai') AS active_users_7d,
        COUNT(*) AS total_events
      FROM event_logs
    `,
    // 安装
    sql`
      SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE data->>'platform' = 'native') AS native,
        COUNT(*) FILTER (WHERE data->>'platform' = 'web') AS web
      FROM event_logs
      WHERE event = 'first_install'
    `,
    // 路线规划
    sql`
      SELECT
        (SELECT COUNT(*) FROM event_logs WHERE event = 'route_plan_click') AS clicks,
        COUNT(*) FILTER (WHERE (data->>'success')::boolean = true) AS success,
        COUNT(*) FILTER (WHERE (data->>'success')::boolean = false) AS failed,
        COUNT(*) FILTER (WHERE (data->>'avoid_cameras')::boolean = true) AS avoid_cameras_count,
        ROUND(AVG((data->>'distance')::numeric) FILTER (WHERE (data->>'success')::boolean = true) / 1000, 1) AS avg_distance_km,
        ROUND(AVG((data->>'duration')::numeric) FILTER (WHERE (data->>'success')::boolean = true) / 60, 1) AS avg_duration_min
      FROM event_logs
      WHERE event = 'route_plan_result'
    `,
    // 导航
    sql`
      SELECT
        (SELECT COUNT(*) FROM event_logs WHERE event = 'navigation_start') AS starts,
        (SELECT COUNT(DISTINCT user_token) FROM event_logs WHERE event = 'navigation_start' AND user_token IS NOT NULL) AS unique_users,
        ROUND(AVG((data->>'duration_seconds')::numeric) / 60, 1) AS avg_duration_min,
        ROUND(MAX((data->>'duration_seconds')::numeric) / 60, 1) AS max_duration_min
      FROM event_logs
      WHERE event = 'navigation_end'
    `,
    // 巡航模式
    sql`
      SELECT
        (SELECT COUNT(*) FROM event_logs WHERE event = 'cruise_start') AS starts,
        ROUND(AVG((data->>'duration_seconds')::numeric) / 60, 1) AS avg_duration_min
      FROM event_logs
      WHERE event = 'cruise_end'
    `,
    // 近7天每日趋势
    sql`
      SELECT
        DATE(created_at AT TIME ZONE 'Asia/Shanghai') AS date,
        COUNT(*) FILTER (WHERE event = 'route_plan_click') AS route_plans,
        COUNT(*) FILTER (WHERE event = 'navigation_start') AS navigations,
        COUNT(*) FILTER (WHERE event = 'cruise_start') AS cruises,
        COUNT(DISTINCT user_token) FILTER (WHERE user_token IS NOT NULL) AS active_users
      FROM event_logs
      WHERE created_at >= (NOW() AT TIME ZONE 'Asia/Shanghai' - INTERVAL '7 days') AT TIME ZONE 'Asia/Shanghai'
      GROUP BY DATE(created_at AT TIME ZONE 'Asia/Shanghai')
      ORDER BY date DESC
    `,
  ]);

  return NextResponse.json({
    overview: overview[0],
    installs: installs[0],
    routePlan: routePlan[0],
    navigation: navigation[0],
    cruise: cruise[0],
    daily,
  });
}
