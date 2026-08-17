'use client';

import React, { useEffect, useMemo, useState } from 'react';
import { EventTimelineModal } from './event-timeline-modal';

interface UserToken {
  user_token: string;
  first_event_date: string | null;
  last_event_date: string | null;
  total_events: number;
  state: string;
  validity: string;
  expiresAt: string | null;
}

type TokenFilter = 'all' | 'active' | 'expiring' | 'expired' | 'invalid';

const cardStyle: React.CSSProperties = {
  background: '#fff',
  borderRadius: 12,
  boxShadow: '0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06)',
};

function formatDate(value: string | null, options?: Intl.DateTimeFormatOptions) {
  if (!value) return '暂无记录';
  // Token API 返回的无时区时间已在服务端固定转换为北京时间，不能再按浏览器时区解析。
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(value)) return value;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '暂无记录';
  return date.toLocaleString('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    ...(options ?? {}),
  });
}

function getExpiryInfo(token: UserToken) {
  if (token.validity === 'permanent') {
    return { label: '永久有效', tone: 'neutral', isExpiring: false };
  }
  if (!token.expiresAt) {
    return { label: '未设置', tone: 'muted', isExpiring: false };
  }

  const remainingMs = new Date(token.expiresAt).getTime() - Date.now();
  if (remainingMs <= 0) return { label: '已到期', tone: 'danger', isExpiring: false };

  const days = Math.ceil(remainingMs / 86_400_000);
  if (days <= 7) return { label: `${days} 天后到期`, tone: 'warning', isExpiring: true };
  return { label: `${days} 天后到期`, tone: 'success', isExpiring: false };
}

function getStateInfo(token: UserToken) {
  if (token.state === 'active') return { label: '有效', tone: 'success' };
  if (token.state === 'expired') return { label: '已过期', tone: 'danger' };
  if (token.state === 'invalid') return { label: '无效', tone: 'muted' };
  return { label: '未配置', tone: 'muted' };
}

function Badge({ children, tone }: { children: React.ReactNode; tone: string }) {
  const colors: Record<string, { color: string; background: string }> = {
    success: { color: '#15803d', background: '#f0fdf4' },
    warning: { color: '#b45309', background: '#fffbeb' },
    danger: { color: '#dc2626', background: '#fef2f2' },
    muted: { color: '#6b7280', background: '#f3f4f6' },
    neutral: { color: '#0369a1', background: '#f0f9ff' },
  };
  const color = colors[tone] ?? colors.muted;
  return (
    <span style={{ display: 'inline-block', padding: '3px 8px', borderRadius: 999, fontSize: 12, fontWeight: 600, ...color }}>
      {children}
    </span>
  );
}

function SummaryCard({ label, value, tone = '#0f766e' }: { label: string; value: number; tone?: string }) {
  return (
    <div style={{ ...cardStyle, padding: '16px 18px', flex: '1 1 150px', borderTop: `3px solid ${tone}` }}>
      <div style={{ color: '#6b7280', fontSize: 13 }}>{label}</div>
      <div style={{ color: '#111827', fontSize: 30, lineHeight: 1.2, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

export function DashboardCharts() {
  const [userTokens, setUserTokens] = useState<UserToken[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedToken, setSelectedToken] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<TokenFilter>('all');

  const fetchUserTokens = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch('/api/user-tokens');
      if (!response.ok) throw new Error('无法获取 Token 数据');
      setUserTokens(await response.json());
    } catch (fetchError) {
      console.error('Failed to fetch user tokens:', fetchError);
      setError('加载 Token 数据失败，请稍后重试。');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchUserTokens();
  }, []);

  const summary = useMemo(() => ({
    total: userTokens.length,
    active: userTokens.filter((token) => token.state === 'active').length,
    expiring: userTokens.filter((token) => getExpiryInfo(token).isExpiring).length,
    expired: userTokens.filter((token) => token.state === 'expired').length,
  }), [userTokens]);

  const displayedTokens = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    return userTokens.filter((token) => {
      const expiry = getExpiryInfo(token);
      const matchesQuery = !normalizedQuery || token.user_token.toLowerCase().includes(normalizedQuery);
      const matchesFilter = filter === 'all'
        || (filter === 'expiring' ? expiry.isExpiring : token.state === filter);
      return matchesQuery && matchesFilter;
    });
  }, [filter, query, userTokens]);

  return (
    <div>
      <section style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginBottom: 24 }} aria-label="Token 状态概览">
        <SummaryCard label="全部 Token" value={summary.total} />
        <SummaryCard label="当前有效" value={summary.active} tone="#16a34a" />
        <SummaryCard label="7 天内到期" value={summary.expiring} tone="#f59e0b" />
        <SummaryCard label="已过期" value={summary.expired} tone="#dc2626" />
      </section>

      <section style={cardStyle}>
        <div style={{ padding: '18px 20px 14px', borderBottom: '1px solid #e5e7eb' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
            <div>
              <h2 style={{ margin: 0, color: '#1f2937', fontSize: 18 }}>用户 Token</h2>
              <p style={{ margin: '4px 0 0', color: '#6b7280', fontSize: 13 }}>点击“查看日志”即可查看该用户的完整行为记录。</p>
            </div>
            <button
              type="button"
              onClick={() => void fetchUserTokens()}
              disabled={loading}
              style={{ border: '1px solid #99f6e4', borderRadius: 8, padding: '7px 12px', background: '#f0fdfa', color: '#0f766e', fontWeight: 600, cursor: loading ? 'wait' : 'pointer' }}
            >
              {loading ? '刷新中…' : '刷新数据'}
            </button>
          </div>

          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 16 }}>
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜索 Token"
              aria-label="搜索 Token"
              style={{ minWidth: 180, flex: '1 1 220px', border: '1px solid #d1d5db', borderRadius: 8, padding: '8px 10px', fontSize: 14 }}
            />
            <select
              value={filter}
              onChange={(event) => setFilter(event.target.value as TokenFilter)}
              aria-label="按状态筛选"
              style={{ border: '1px solid #d1d5db', borderRadius: 8, padding: '8px 10px', color: '#374151', background: '#fff', fontSize: 14 }}
            >
              <option value="all">全部状态</option>
              <option value="active">有效</option>
              <option value="expiring">7 天内到期</option>
              <option value="expired">已过期</option>
              <option value="invalid">无效 / 未配置</option>
            </select>
          </div>
        </div>

        {loading ? (
          <div style={{ textAlign: 'center', color: '#6b7280', padding: 40 }}>正在加载 Token 数据…</div>
        ) : error ? (
          <div style={{ textAlign: 'center', color: '#dc2626', padding: 40 }}>{error}</div>
        ) : displayedTokens.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#6b7280', padding: 40 }}>没有匹配的 Token。</div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', minWidth: 830, borderCollapse: 'collapse', fontSize: 14 }}>
              <thead>
                <tr style={{ background: '#f9fafb', color: '#374151', textAlign: 'left' }}>
                  <th style={{ padding: '11px 20px', fontWeight: 600 }}>用户 Token</th>
                  <th style={{ padding: '11px 12px', fontWeight: 600 }}>状态</th>
                  <th style={{ padding: '11px 12px', fontWeight: 600 }}>到期时间</th>
                  <th style={{ padding: '11px 12px', fontWeight: 600 }}>最近活跃</th>
                  <th style={{ padding: '11px 12px', fontWeight: 600 }}>行为日志</th>
                </tr>
              </thead>
              <tbody>
                {displayedTokens.map((token) => {
                  const state = getStateInfo(token);
                  const expiry = getExpiryInfo(token);
                  return (
                    <tr key={token.user_token} style={{ borderTop: '1px solid #f3f4f6' }}>
                      <td style={{ padding: '14px 20px', color: '#111827', fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontSize: 13 }}>{token.user_token}</td>
                      <td style={{ padding: '14px 12px' }}><Badge tone={state.tone}>{state.label}</Badge></td>
                      <td style={{ padding: '14px 12px', color: '#374151' }}>
                        <div>{token.expiresAt ? formatDate(token.expiresAt, { hour: '2-digit', minute: '2-digit' }) : '—'}</div>
                        <div style={{ marginTop: 4 }}><Badge tone={expiry.tone}>{expiry.label}</Badge></div>
                      </td>
                      <td style={{ padding: '14px 12px', color: '#4b5563' }}>{formatDate(token.last_event_date, { hour: '2-digit', minute: '2-digit' })}</td>
                      <td style={{ padding: '14px 12px' }}>
                        <button
                          type="button"
                          onClick={() => setSelectedToken(token.user_token)}
                          style={{ border: 0, borderRadius: 7, padding: '7px 10px', background: '#eff6ff', color: '#1d4ed8', cursor: 'pointer', fontWeight: 600 }}
                        >
                          查看日志 ({token.total_events})
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {selectedToken && <EventTimelineModal token={selectedToken} onClose={() => setSelectedToken(null)} />}
    </div>
  );
}
