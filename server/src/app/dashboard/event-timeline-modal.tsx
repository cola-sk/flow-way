'use client';

import React, { useEffect, useState } from 'react';

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

const eventLabels: Record<string, string> = {
  first_install: '首次安装',
  app_open: 'App 打开',
  token_change: 'Token 切换',
  route_plan_click: '路线规划',
  route_plan_result: '路线规划结果',
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
  navigation_start: '#10b981',
  navigation_end: '#6b7280',
  cruise_start: '#ec4899',
  cruise_end: '#9ca3af',
};

function formatEventData(data: Record<string, any> | null | undefined): string {
  if (!data || typeof data !== 'object') return '';
  const keys = Object.keys(data).filter(k => !['userToken', 'ip', 'userAgent', 'platform'].includes(k));
  return keys.map(k => {
    const v = data[k];
    if (typeof v === 'boolean') return `${k}: ${v ? '是' : '否'}`;
    if (typeof v === 'number') {
      if (k === 'distance') return `${k}: ${Math.round(v / 1000)}km`;
      if (k === 'duration') return `${k}: ${Math.round(v / 60)}min`;
      if (k === 'duration_seconds') return `${k}: ${Math.round(v / 60)}min`;
      return `${k}: ${v}`;
    }
    return `${k}: ${v}`;
  }).join(' · ') || '';
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
          maxWidth: 640,
          maxHeight: '80vh',
          overflow: 'hidden',
          display: 'flex',
          flexDirection: 'column',
          boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
        }}
      >
        {/* 弹窗头部 */}
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

        {/* 事件列表 */}
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
            <div
              style={{
                position: 'relative',
                paddingLeft: 24,
              }}
            >
              {/* 左侧时间线 */}
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

              {events.map((event) => (
                <div
                  key={event.id}
                  style={{
                    position: 'relative',
                    paddingBottom: 16,
                    paddingLeft: 16,
                  }}
                >
                  {/* 时间点圆点 */}
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
                  {/* 事件卡片 */}
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
                        marginBottom: 4,
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
                    {event.data && (
                      <div
                        style={{
                          fontSize: 11,
                          color: '#6b7280',
                          lineHeight: 1.5,
                          wordBreak: 'break-all',
                        }}
                      >
                        {formatEventData(event.data)}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* 弹窗底部 */}
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
