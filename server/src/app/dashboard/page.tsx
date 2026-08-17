import { DashboardCharts } from './dashboard-charts';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default function MonitorPage() {
  return (
    <main
      style={{
        maxWidth: 1200,
        margin: '0 auto',
        padding: 'clamp(16px, 4vw, 40px) clamp(12px, 3vw, 24px)',
        fontFamily: 'system-ui, sans-serif',
        background: '#f9fafb',
        minHeight: '100vh',
      }}
    >
      <header style={{ marginBottom: 'clamp(20px, 4vw, 32px)' }}>
        <h1
          style={{
            fontSize: 'clamp(20px, 5vw, 28px)',
            fontWeight: 700,
            color: '#0f766e',
            margin: 0,
            display: 'flex',
            alignItems: 'center',
            gap: 12,
          }}
        >
          <img
            src="/app-icon.png"
            alt=""
            style={{ width: 'clamp(28px, 7vw, 40px)', height: 'clamp(28px, 7vw, 40px)', borderRadius: 8 }}
          />
          绕川 · 用户 Token 管理
        </h1>
        <p style={{ fontSize: 'clamp(12px, 2vw, 14px)', color: '#6b7280', margin: '6px 0 0' }}>
          查看用户 Token 的有效状态、到期时间和行为日志
        </p>
      </header>

      <DashboardCharts />
    </main>
  );
}
