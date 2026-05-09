import { sql } from '@/lib/db';
import { DashboardCharts } from './dashboard-charts';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

// ---- 数据获取 ----
interface DailyMetric {
  date: string;
  route_plans: number;
  navigations: number;
  cruises: number;
  active_users: number;
}

async function getMetrics() {
  const [overview, installs, routePlan, navigation, cruise, daily] =
    await Promise.all([
      sql`
        SELECT
          COUNT(DISTINCT user_token) FILTER (WHERE user_token IS NOT NULL) AS total_users,
          COUNT(DISTINCT user_token) FILTER (WHERE user_token IS NOT NULL AND created_at >= NOW() - INTERVAL '7 days') AS active_users_7d,
          COUNT(*) AS total_events
        FROM event_logs
      `,
      sql`
        SELECT
          COUNT(*) AS total,
          COUNT(*) FILTER (WHERE data->>'platform' = 'native') AS native,
          COUNT(*) FILTER (WHERE data->>'platform' = 'web') AS web
        FROM event_logs WHERE event = 'first_install'
      `,
      sql`
        SELECT
          (SELECT COUNT(*) FROM event_logs WHERE event = 'route_plan_click') AS clicks,
          COUNT(*) FILTER (WHERE (data->>'success')::boolean = true) AS success,
          COUNT(*) FILTER (WHERE (data->>'success')::boolean = false) AS failed,
          COUNT(*) FILTER (WHERE (data->>'avoid_cameras')::boolean = true) AS avoid_cameras_count,
          ROUND(AVG((data->>'distance')::numeric) FILTER (WHERE (data->>'success')::boolean = true) / 1000, 1) AS avg_distance_km,
          ROUND(AVG((data->>'duration')::numeric) FILTER (WHERE (data->>'success')::boolean = true) / 60, 1) AS avg_duration_min
        FROM event_logs WHERE event = 'route_plan_result'
      `,
      sql`
        SELECT
          (SELECT COUNT(*) FROM event_logs WHERE event = 'navigation_start') AS starts,
          (SELECT COUNT(DISTINCT user_token) FROM event_logs WHERE event = 'navigation_start' AND user_token IS NOT NULL) AS unique_users,
          ROUND(AVG((data->>'duration_seconds')::numeric) / 60, 1) AS avg_duration_min,
          ROUND(MAX((data->>'duration_seconds')::numeric) / 60, 1) AS max_duration_min
        FROM event_logs WHERE event = 'navigation_end'
      `,
      sql`
        SELECT
          (SELECT COUNT(*) FROM event_logs WHERE event = 'cruise_start') AS starts,
          ROUND(AVG((data->>'duration_seconds')::numeric) / 60, 1) AS avg_duration_min
        FROM event_logs WHERE event = 'cruise_end'
      `,
      sql`
        SELECT
          DATE(created_at) AS date,
          COUNT(*) FILTER (WHERE event = 'route_plan_click') AS route_plans,
          COUNT(*) FILTER (WHERE event = 'navigation_start') AS navigations,
          COUNT(*) FILTER (WHERE event = 'cruise_start') AS cruises,
          COUNT(DISTINCT user_token) FILTER (WHERE user_token IS NOT NULL) AS active_users
        FROM event_logs
        WHERE created_at >= NOW() - INTERVAL '7 days'
        GROUP BY DATE(created_at)
        ORDER BY date DESC
      `,
    ]);
  return {
    overview: overview[0],
    installs: installs[0],
    routePlan: routePlan[0],
    navigation: navigation[0],
    cruise: cruise[0],
    daily: daily as DailyMetric[],
  };
}

// ---- 样式常量 ----
const card: React.CSSProperties = {
  background: '#fff',
  borderRadius: 12,
  padding: 'clamp(16px, 4vw, 24px)',
  boxShadow: '0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06)',
  flex: '1 1 120px',
  minWidth: 100,
};
const cardGrid: React.CSSProperties = {
  display: 'flex',
  flexWrap: 'wrap',
  gap: 'clamp(8px, 2vw, 16px)',
  marginBottom: 'clamp(16px, 4vw, 32px)',
};
const section: React.CSSProperties = { marginBottom: 'clamp(20px, 5vw, 36px)' };
const h2: React.CSSProperties = {
  fontSize: 'clamp(14px, 3vw, 16px)',
  fontWeight: 600,
  color: '#374151',
  marginBottom: 12,
  borderLeft: '4px solid #14b8a6',
  paddingLeft: 10,
  backgroundColor: '#f0fdfa',
  padding: '4px 8px 4px 10px',
  borderRadius: 4,
};
const label: React.CSSProperties = {
  fontSize: 'clamp(10px, 2vw, 12px)',
  color: '#9ca3af',
  marginBottom: 4,
};
const value: React.CSSProperties = {
  fontSize: 'clamp(20px, 5vw, 28px)',
  fontWeight: 700,
  color: '#0f766e',
  lineHeight: 1.2,
};
const sub: React.CSSProperties = { 
  fontSize: 'clamp(10px, 2vw, 12px)', 
  color: '#6b7280', 
  marginTop: 4 
};
const table: React.CSSProperties = {
  width: '100%',
  borderCollapse: 'collapse',
  fontSize: 14,
};
const th: React.CSSProperties = {
  textAlign: 'left',
  padding: '8px 12px',
  background: '#f0fdfa',
  borderBottom: '1px solid #e5e7eb',
  fontWeight: 600,
  color: '#374151',
};
const td: React.CSSProperties = {
  padding: '8px 12px',
  borderBottom: '1px solid #f3f4f6',
  color: '#4b5563',
};

function StatCard({
  title,
  val,
  hint,
}: {
  title: string;
  val: string | number | null;
  hint?: string;
}) {
  return (
    <div style={card}>
      <div style={label}>{title}</div>
      <div style={value}>{val ?? '—'}</div>
      {hint && <div style={sub}>{hint}</div>}
    </div>
  );
}

// ---- 页面 ----
export default async function MonitorPage() {
  const { overview, installs, routePlan, navigation, cruise, daily } =
    await getMetrics();

  const successRate =
    routePlan.clicks > 0
      ? Math.round((Number(routePlan.success) / Number(routePlan.clicks)) * 100)
      : null;

  const avoidRate =
    routePlan.clicks > 0
      ? Math.round(
          (Number(routePlan.avoid_cameras_count) / Number(routePlan.clicks)) * 100
        )
      : null;

  return (
    <main
      style={{
        maxWidth: 1200,
        margin: '0 auto',
        padding: 'clamp(16px, 4vw, 40px) clamp(12px, 3vw, 24px)',
        fontFamily: 'system-ui, sans-serif',
        background: '#f0fdfa',
        minHeight: '100vh',
      }}
    >
      <div style={{ marginBottom: 'clamp(16px, 4vw, 32px)' }}>
        <h1 style={{ fontSize: 'clamp(20px, 5vw, 28px)', fontWeight: 700, color: '#0f766e', margin: 0, display: 'flex', alignItems: 'center', gap: 12 }}>
          <img src="/app-icon.png" alt="" style={{ width: 'clamp(28px, 7vw, 40px)', height: 'clamp(28px, 7vw, 40px)', borderRadius: 8 }} />
          绕川 · 运营监控
        </h1>
        <p style={{ fontSize: 'clamp(12px, 2vw, 14px)', color: '#9ca3af', marginTop: 6 }}>
          数据来源：event_logs · 实时查询
        </p>
      </div>

      {/* 总览 */}
      <div style={section}>
        <div style={h2}>总览</div>
        <div style={cardGrid}>
          <StatCard title="累计用户数" val={overview.total_users} />
          <StatCard
            title="近7天活跃用户"
            val={overview.active_users_7d}
            hint="by userToken"
          />
          <StatCard title="累计安装" val={installs.total} hint={`Native ${installs.native} / Web ${installs.web}`} />
          <StatCard title="累计事件数" val={overview.total_events} />
        </div>
      </div>

      {/* 路线规划 */}
      <div style={section}>
        <div style={h2}>路线规划</div>
        <div style={cardGrid}>
          <StatCard title="规划次数" val={routePlan.clicks} />
          <StatCard
            title="成功率"
            val={successRate !== null ? `${successRate}%` : null}
            hint={`成功 ${routePlan.success} / 失败 ${routePlan.failed}`}
          />
          <StatCard
            title="选择避让摄像头"
            val={avoidRate !== null ? `${avoidRate}%` : null}
          />
          <StatCard
            title="平均路程"
            val={routePlan.avg_distance_km ? `${routePlan.avg_distance_km} km` : null}
          />
          <StatCard
            title="平均预计时长"
            val={routePlan.avg_duration_min ? `${routePlan.avg_duration_min} min` : null}
          />
        </div>
      </div>

      {/* 导航 */}
      <div style={section}>
        <div style={h2}>实时导航</div>
        <div style={cardGrid}>
          <StatCard title="导航次数" val={navigation.starts} />
          <StatCard title="导航用户数" val={navigation.unique_users} />
          <StatCard
            title="平均导航时长"
            val={navigation.avg_duration_min ? `${navigation.avg_duration_min} min` : null}
          />
          <StatCard
            title="最长导航时长"
            val={navigation.max_duration_min ? `${navigation.max_duration_min} min` : null}
          />
        </div>
      </div>

      {/* 巡航 */}
      <div style={section}>
        <div style={h2}>巡航模式</div>
        <div style={cardGrid}>
          <StatCard title="开启次数" val={cruise.starts} />
          <StatCard
            title="平均巡航时长"
            val={cruise.avg_duration_min ? `${cruise.avg_duration_min} min` : null}
          />
        </div>
      </div>

      {/* 近7天趋势 - 图表看板 */}
      <DashboardCharts
        daily={daily}
        routePlanSuccess={Number(routePlan.success)}
        routePlanTotal={Number(routePlan.clicks)}
      />
    </main>
  );
}
