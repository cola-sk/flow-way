'use client';

import React, { useEffect, useMemo, useState } from 'react';

interface EventItem {
  id: number;
  event: string;
  user_token: string;
  data: Record<string, any>;
  created_at: string;
}

interface EventTimelineModalProps {
  token: string;
  onClose: () => void;
}

interface EventDetail {
  key: string;
  label: string;
  value: string;
}

const eventLabels: Record<string, string> = {
  first_install: '首次安装',
  app_open: 'App 打开',
  token_change: 'Token 切换',
  route_plan_click: '路线规划',
  route_plan_result: '路线规划结果',
  route_retry_click: '路线重试',
  route_result_sheet_show: '结果页展示',
  route_result_click_navigate: '结果页点导航',
  route_result_click_replan: '结果页点重试',
  route_result_click_save: '结果页点保存',
  route_result_sheet_dismiss: '结果页关闭',
  navigation_start: '导航开始',
  navigation_end: '导航结束',
  cruise_start: '巡航开始',
  cruise_end: '巡航结束',
};

const eventColors: Record<string, string> = {
  first_install: '#6366f1',
  app_open: '#14b8a6',
  token_change: '#f59e0b',
  route_plan_click: '#3b82f6',
  route_plan_result: '#8b5cf6',
  route_retry_click: '#2563eb',
  route_result_sheet_show: '#0ea5e9',
  route_result_click_navigate: '#16a34a',
  route_result_click_replan: '#d97706',
  route_result_click_save: '#7c3aed',
  route_result_sheet_dismiss: '#6b7280',
  navigation_start: '#10b981',
  navigation_end: '#6b7280',
  cruise_start: '#ec4899',
  cruise_end: '#9ca3af',
};

const hiddenDataKeys = new Set(['userToken', 'ip', 'userAgent', 'platform']);

const fieldLabels: Record<string, string> = {
  success: '是否成功',
  error: '错误信息',
  avoid_cameras: '避让摄像头',
  planning_failed: '是否规划失败',
  camera_count: '路上摄像头',
  distance: '路线距离',
  duration: '路线时长',
  route_distance: '路线距离',
  route_duration: '路线时长',
  duration_seconds: '导航时长',
  has_waypoints: '有途径点',
  waypoint_count: '途径点数',
  previous_attempt_count: '历史尝试次数',
  is_retry: '是否重试轮次',
  source: '操作来源',
  dismiss_reason: '关闭原因',
  start_time: '开始时间',
  end_time: '结束时间',
  timestamp: '时间戳',
  oldToken: '旧 Token',
  newToken: '新 Token',
};

const detailOrder = [
  'success',
  'error',
  'planning_failed',
  'avoid_cameras',
  'camera_count',
  'distance',
  'duration',
  'route_distance',
  'route_duration',
  'duration_seconds',
  'waypoint_count',
  'has_waypoints',
  'is_retry',
  'previous_attempt_count',
  'source',
  'dismiss_reason',
  'start_time',
  'end_time',
  'timestamp',
  'oldToken',
  'newToken',
];

const dismissReasonLabels: Record<string, string> = {
  click_navigate: '点击导航',
  click_replan_footer: '点击重试（底部按钮）',
  click_replan_failure_banner: '点击重试（失败提示）',
  tap_outside_or_system: '手势/系统关闭',
};

function toBool(value: unknown): boolean | undefined {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    if (value === 'true') return true;
    if (value === 'false') return false;
  }
  return undefined;
}

function formatDistanceMeters(value: number): string {
  if (value >= 1000) return `${(value / 1000).toFixed(1)} km`;
  return `${Math.round(value)} m`;
}

function formatDurationSeconds(value: number): string {
  if (value >= 60) return `${Math.round(value / 60)} min`;
  return `${Math.round(value)} s`;
}

function formatDetailValue(key: string, value: unknown): string {
  if (value == null) return '-';

  if (key === 'dismiss_reason' && typeof value === 'string') {
    return dismissReasonLabels[value] ?? value;
  }

  if (typeof value === 'boolean') {
    return value ? '是' : '否';
  }

  if (typeof value === 'number') {
    if (key === 'distance' || key === 'route_distance') {
      return formatDistanceMeters(value);
    }
    if (key === 'duration' || key === 'route_duration' || key === 'duration_seconds') {
      return formatDurationSeconds(value);
    }
    return String(value);
  }

  if (typeof value === 'string') {
    if (key === 'distance' || key === 'route_distance') {
      const n = Number(value);
      if (!Number.isNaN(n)) return formatDistanceMeters(n);
    }
    if (key === 'duration' || key === 'route_duration' || key === 'duration_seconds') {
      const n = Number(value);
      if (!Number.isNaN(n)) return formatDurationSeconds(n);
    }
    if (key === 'dismiss_reason') {
      return dismissReasonLabels[value] ?? value;
    }
    return value;
  }

  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

function buildEventDetails(event: EventItem): EventDetail[] {
  const data = event.data;
  if (!data || typeof data !== 'object') return [];

  const details: EventDetail[] = Object.entries(data)
    .filter(([key, value]) => !hiddenDataKeys.has(key) && value !== null && value !== '')
    .map(([key, value]) => ({
      key,
      label: fieldLabels[key] ?? key,
      value: formatDetailValue(key, value),
    }));

  details.sort((a, b) => {
    const ai = detailOrder.indexOf(a.key);
    const bi = detailOrder.indexOf(b.key);
    if (ai === -1 && bi === -1) return a.key.localeCompare(b.key);
    if (ai === -1) return 1;
    if (bi === -1) return -1;
    return ai - bi;
  });

  return details;
}

function getEventLabel(event: string): string {
  return eventLabels[event] || event;
}

function getEventColor(event: string): string {
  return eventColors[event] || '#6b7280';
}

export function EventTimelineModal({ token, onClose }: EventTimelineModalProps) {
  const [events, setEvents] = useState<EventItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);

  useEffect(() => {
    const fetchEvents = async () => {
      setLoading(true);
      try {
        const res = await fetch(`/api/user-tokens/${encodeURIComponent(token)}/events?limit=200`);
        const data = await res.json();
        setEvents(data.events || []);
        setTotal(data.total || 0);
      } catch (err) {
        console.error('Failed to fetch events:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchEvents();
  }, [token]);

  const summary = useMemo(() => {
    const count = (name: string, predicate?: (e: EventItem) => boolean) =>
      events.filter(e => e.event === name && (!predicate || predicate(e))).length;
    const routePlanSuccess = count('route_plan_result', e => toBool(e.data?.success) === true);
    const routePlanFailed = count('route_plan_result', e => toBool(e.data?.success) === false);
    const sheetDismisses = events.filter(e => e.event === 'route_result_sheet_dismiss');
    const dismissReasonCount = sheetDismisses.reduce<Record<string, number>>((acc, event) => {
      const reason = String(event.data?.dismiss_reason || 'unknown');
      acc[reason] = (acc[reason] || 0) + 1;
      return acc;
    }, {});
    const dismissSummary = Object.entries(dismissReasonCount)
      .sort((a, b) => b[1] - a[1])
      .map(([reason, c]) => `${dismissReasonLabels[reason] ?? reason}: ${c}`)
      .join(' / ');

    const resultSheetShows = count('route_result_sheet_show');
    const resultNavigateClicks = count('route_result_click_navigate');
    const resultNavigateRate = resultSheetShows > 0
      ? `${Math.round((resultNavigateClicks / resultSheetShows) * 100)}%`
      : '—';

    return {
      routePlanClick: count('route_plan_click'),
      routePlanSuccess,
      routePlanFailed,
      resultSheetShows,
      resultNavigateClicks,
      resultNavigateRate,
      resultReplanClicks: count('route_result_click_replan'),
      resultSaveClicks: count('route_result_click_save'),
      navigationStarts: count('navigation_start'),
      dismissSummary: dismissSummary || '—',
    };
  }, [events]);

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 1000,
        background: 'rgba(0,0,0,0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 16,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          background: '#fff',
          borderRadius: 12,
          width: '100%',
          maxWidth: 760,
          maxHeight: '86vh',
          overflow: 'hidden',
          display: 'flex',
          flexDirection: 'column',
          boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '16px 20px',
            borderBottom: '1px solid #e5e7eb',
          }}
        >
          <div>
            <div
              style={{
                fontSize: 14,
                fontWeight: 600,
                color: '#0f766e',
              }}
            >
              事件时间线
            </div>
            <div
              style={{
                fontSize: 11,
                color: '#9ca3af',
                fontFamily: 'monospace',
                marginTop: 2,
              }}
            >
              {token} · 共 {total} 条
            </div>
          </div>
          <button
            onClick={onClose}
            style={{
              background: '#f3f4f6',
              border: 'none',
              borderRadius: 6,
              width: 32,
              height: 32,
              fontSize: 16,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#6b7280',
            }}
          >
            ✕
          </button>
        </div>

        <div
          style={{
            overflowY: 'auto',
            flex: 1,
            padding: '12px 20px',
          }}
        >
          {loading ? (
            <div
              style={{
                textAlign: 'center',
                color: '#9ca3af',
                padding: 40,
                fontSize: 14,
              }}
            >
              加载中...
            </div>
          ) : events.length === 0 ? (
            <div
              style={{
                textAlign: 'center',
                color: '#9ca3af',
                padding: 40,
                fontSize: 14,
              }}
            >
              暂无事件记录
            </div>
          ) : (
            <>
              <div
                style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: 10,
                  padding: 12,
                  marginBottom: 12,
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
                  gap: 8,
                }}
              >
                <div>
                  <div style={{ fontSize: 11, color: '#64748b' }}>路线点击</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>{summary.routePlanClick}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, color: '#64748b' }}>规划成功/失败</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>
                    {summary.routePlanSuccess}/{summary.routePlanFailed}
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: 11, color: '#64748b' }}>结果页展示</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>{summary.resultSheetShows}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, color: '#64748b' }}>点导航</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>
                    {summary.resultNavigateClicks} ({summary.resultNavigateRate})
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: 11, color: '#64748b' }}>点重试</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>{summary.resultReplanClicks}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, color: '#64748b' }}>点保存</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>{summary.resultSaveClicks}</div>
                </div>
                <div>
                  <div style={{ fontSize: 11, color: '#64748b' }}>导航开始</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#0f172a' }}>{summary.navigationStarts}</div>
                </div>
                <div style={{ gridColumn: '1 / -1' }}>
                  <div style={{ fontSize: 11, color: '#64748b' }}>结果页关闭原因</div>
                  <div style={{ fontSize: 13, color: '#0f172a', lineHeight: 1.5 }}>{summary.dismissSummary}</div>
                </div>
              </div>

              <div
                style={{
                  position: 'relative',
                  paddingLeft: 24,
                }}
              >
                <div
                  style={{
                    position: 'absolute',
                    left: 7,
                    top: 8,
                    bottom: 8,
                    width: 2,
                    background: '#e5e7eb',
                    borderRadius: 1,
                  }}
                />

                {events.map((event) => {
                  const details = buildEventDetails(event);
                  return (
                    <div
                      key={event.id}
                      style={{
                        position: 'relative',
                        paddingBottom: 16,
                        paddingLeft: 16,
                      }}
                    >
                      <div
                        style={{
                          position: 'absolute',
                          left: -18,
                          top: 5,
                          width: 10,
                          height: 10,
                          borderRadius: '50%',
                          background: getEventColor(event.event),
                          border: '2px solid #fff',
                          boxShadow: '0 0 0 1px #e5e7eb',
                          zIndex: 1,
                        }}
                      />
                      <div
                        style={{
                          background: '#f9fafb',
                          borderRadius: 8,
                          padding: '8px 10px',
                        }}
                      >
                        <div
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            marginBottom: details.length > 0 ? 8 : 0,
                            gap: 8,
                          }}
                        >
                          <span
                            style={{
                              display: 'inline-block',
                              padding: '1px 6px',
                              borderRadius: 3,
                              fontSize: 11,
                              fontWeight: 600,
                              color: '#fff',
                              background: getEventColor(event.event),
                              whiteSpace: 'nowrap',
                            }}
                          >
                            {getEventLabel(event.event)}
                          </span>
                          <span
                            style={{
                              fontSize: 11,
                              color: '#9ca3af',
                              whiteSpace: 'nowrap',
                            }}
                          >
                            {event.created_at}
                          </span>
                        </div>
                        {details.length > 0 && (
                          <div
                            style={{
                              display: 'grid',
                              gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
                              gap: 6,
                            }}
                          >
                            {details.map(detail => (
                              <div
                                key={`${event.id}-${detail.key}`}
                                style={{
                                  border: '1px solid #e5e7eb',
                                  borderRadius: 6,
                                  background: '#fff',
                                  padding: '6px 8px',
                                }}
                              >
                                <div style={{ fontSize: 10, color: '#9ca3af', marginBottom: 2 }}>{detail.label}</div>
                                <div style={{ fontSize: 12, color: '#374151', lineHeight: 1.4, wordBreak: 'break-all' }}>
                                  {detail.value}
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </div>

        {total > 200 && (
          <div
            style={{
              padding: '10px 20px',
              borderTop: '1px solid #e5e7eb',
              textAlign: 'center',
              fontSize: 12,
              color: '#9ca3af',
            }}
          >
            仅显示最近 200 条事件，共 {total} 条
          </div>
        )}
      </div>
    </div>
  );
}
