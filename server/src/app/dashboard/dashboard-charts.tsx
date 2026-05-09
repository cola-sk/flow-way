'use client';

import React, { useEffect, useRef, useState } from 'react';
import * as echarts from 'echarts';

interface DashboardChartsProps {
  daily: Array<{
    date: string;
    route_plans: number;
    navigations: number;
    cruises: number;
    active_users: number;
  }>;
  routePlanSuccess: number;
  routePlanTotal: number;
}

interface UserToken {
  user_token: string;
  first_event_date: string;
  last_event_date: string;
  total_events: number;
}

const cardStyle: React.CSSProperties = {
  background: '#fff',
  border: '1px solid #e5e7eb',
  borderRadius: 12,
  padding: '20px 24px',
};

const h2Style: React.CSSProperties = {
  fontSize: 16,
  fontWeight: 600,
  color: '#374151',
  marginBottom: 12,
  borderLeft: '3px solid #6366f1',
  paddingLeft: 10,
};

export function DashboardCharts({ daily, routePlanSuccess, routePlanTotal }: DashboardChartsProps) {
  const dailyChartRef = useRef<HTMLDivElement>(null);
  const successChartRef = useRef<HTMLDivElement>(null);
  const [userTokens, setUserTokens] = useState<UserToken[]>([]);
  const [loading, setLoading] = useState(true);

  // 获取用户 token 列表
  useEffect(() => {
    const fetchUserTokens = async () => {
      try {
        const res = await fetch('/api/user-tokens');
        const data = await res.json();
        setUserTokens(data);
      } catch (error) {
        console.error('Failed to fetch user tokens:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchUserTokens();
  }, []);

  // 初始化日趋势图
  useEffect(() => {
    if (!dailyChartRef.current || daily.length === 0) return;

    const chartInstance = echarts.init(dailyChartRef.current);

    const dates = daily
      .slice()
      .reverse()
      .map((d: any) => String(d.date).slice(0, 10));
    const routePlans = daily
      .slice()
      .reverse()
      .map((d: any) => d.route_plans);
    const navigations = daily
      .slice()
      .reverse()
      .map((d: any) => d.navigations);
    const cruises = daily
      .slice()
      .reverse()
      .map((d: any) => d.cruises);
    const activeUsers = daily
      .slice()
      .reverse()
      .map((d: any) => d.active_users);

    const option = {
      tooltip: {
        trigger: 'axis',
      },
      legend: {
        data: ['路线规划', '导航次数', '巡航次数', '活跃用户'],
        top: 10,
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        top: 50,
        containLabel: true,
      },
      xAxis: {
        type: 'category',
        data: dates,
      },
      yAxis: [
        {
          type: 'value',
          name: '次数',
        },
        {
          type: 'value',
          name: '用户数',
          position: 'right',
        },
      ],
      series: [
        {
          name: '路线规划',
          data: routePlans,
          type: 'line',
          smooth: true,
          yAxisIndex: 0,
          itemStyle: { color: '#6366f1' },
        },
        {
          name: '导航次数',
          data: navigations,
          type: 'line',
          smooth: true,
          yAxisIndex: 0,
          itemStyle: { color: '#10b981' },
        },
        {
          name: '巡航次数',
          data: cruises,
          type: 'line',
          smooth: true,
          yAxisIndex: 0,
          itemStyle: { color: '#f59e0b' },
        },
        {
          name: '活跃用户',
          data: activeUsers,
          type: 'bar',
          yAxisIndex: 1,
          itemStyle: { color: '#ec4899', opacity: 0.6 },
        },
      ],
    };

    chartInstance.setOption(option);

    const handleResize = () => {
      chartInstance.resize();
    };
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      chartInstance.dispose();
    };
  }, [daily]);

  // 初始化成功率饼图
  useEffect(() => {
    if (!successChartRef.current) return;

    const chartInstance = echarts.init(successChartRef.current);

    const successCount = routePlanSuccess;
    const failCount = routePlanTotal - routePlanSuccess;

    const option = {
      tooltip: {
        trigger: 'item',
      },
      legend: {
        top: 'center',
        left: 'right',
      },
      series: [
        {
          type: 'pie',
          radius: ['40%', '70%'],
          avoidLabelOverlap: false,
          itemStyle: {
            borderRadius: 10,
            borderColor: '#fff',
            borderWidth: 2,
          },
          label: {
            show: false,
          },
          emphasis: {
            label: {
              show: true,
            },
          },
          labelLine: {
            show: false,
          },
          data: [
            {
              value: successCount,
              name: `成功 ${successCount}`,
              itemStyle: { color: '#10b981' },
            },
            {
              value: failCount,
              name: `失败 ${failCount}`,
              itemStyle: { color: '#ef4444' },
            },
          ],
        },
      ],
    };

    chartInstance.setOption(option);

    const handleResize = () => {
      chartInstance.resize();
    };
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      chartInstance.dispose();
    };
  }, [routePlanSuccess, routePlanTotal]);

  return (
    <div>
      {/* 近7天趋势图 */}
      <div style={{ marginBottom: 32 }}>
        <div style={h2Style}>近7天每日趋势</div>
        <div style={{ ...cardStyle, height: 400 }}>
          <div ref={dailyChartRef} style={{ width: '100%', height: '100%' }} />
        </div>
      </div>

      {/* 路线规划成功率 */}
      <div style={{ marginBottom: 32 }}>
        <div style={h2Style}>路线规划成功率</div>
        <div style={{ ...cardStyle, height: 300 }}>
          <div ref={successChartRef} style={{ width: '100%', height: '100%' }} />
        </div>
      </div>

      {/* 用户 Token 列表 */}
      <div style={{ marginBottom: 32 }}>
        <div style={h2Style}>用户 Token 列表</div>
        <div style={{ ...cardStyle, overflowX: 'auto' }}>
          {loading ? (
            <div style={{ textAlign: 'center', color: '#9ca3af', padding: '20px' }}>
              加载中...
            </div>
          ) : userTokens.length === 0 ? (
            <div style={{ textAlign: 'center', color: '#9ca3af', padding: '20px' }}>
              暂无数据
            </div>
          ) : (
            <table
              style={{
                width: '100%',
                borderCollapse: 'collapse',
                fontSize: 14,
              }}
            >
              <thead>
                <tr style={{ background: '#f9fafb' }}>
                  <th
                    style={{
                      textAlign: 'left',
                      padding: '8px 12px',
                      borderBottom: '1px solid #e5e7eb',
                      fontWeight: 600,
                      color: '#374151',
                    }}
                  >
                    User Token
                  </th>
                  <th
                    style={{
                      textAlign: 'left',
                      padding: '8px 12px',
                      borderBottom: '1px solid #e5e7eb',
                      fontWeight: 600,
                      color: '#374151',
                    }}
                  >
                    首次事件
                  </th>
                  <th
                    style={{
                      textAlign: 'left',
                      padding: '8px 12px',
                      borderBottom: '1px solid #e5e7eb',
                      fontWeight: 600,
                      color: '#374151',
                    }}
                  >
                    最后事件
                  </th>
                  <th
                    style={{
                      textAlign: 'left',
                      padding: '8px 12px',
                      borderBottom: '1px solid #e5e7eb',
                      fontWeight: 600,
                      color: '#374151',
                    }}
                  >
                    事件数
                  </th>
                </tr>
              </thead>
              <tbody>
                {userTokens.map((token) => (
                  <tr key={token.user_token}>
                    <td
                      style={{
                        padding: '8px 12px',
                        borderBottom: '1px solid #f3f4f6',
                        color: '#4b5563',
                        fontFamily: 'monospace',
                        fontSize: 12,
                      }}
                    >
                      {token.user_token}
                    </td>
                    <td
                      style={{
                        padding: '8px 12px',
                        borderBottom: '1px solid #f3f4f6',
                        color: '#4b5563',
                      }}
                    >
                      {String(token.first_event_date).slice(0, 10)}
                    </td>
                    <td
                      style={{
                        padding: '8px 12px',
                        borderBottom: '1px solid #f3f4f6',
                        color: '#4b5563',
                      }}
                    >
                      {String(token.last_event_date).slice(0, 10)}
                    </td>
                    <td
                      style={{
                        padding: '8px 12px',
                        borderBottom: '1px solid #f3f4f6',
                        color: '#4b5563',
                      }}
                    >
                      {token.total_events}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
