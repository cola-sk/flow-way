import { NextRequest } from 'next/server';
import { sql } from './db';

export interface LogData extends Record<string, any> {
  userToken?: string;
  ip?: string;
  userAgent?: string;
}

/**
 * 记录事件日志，持久化到 Postgres，同时保留 console.log 兜底
 */
export function kvLog(event: string, data: LogData) {
  const timestamp = new Date().toISOString();

  // console.log 兜底，便于本地开发调试
  console.log(`[KV_LOG] timestamp=${timestamp} event=${event}`, data);

  // 异步写入 Postgres，不阻塞响应
  sql`
    INSERT INTO event_logs (event, user_token, ip, user_agent, data, created_at)
    VALUES (
      ${event},
      ${data.userToken ?? null},
      ${data.ip ?? null},
      ${data.userAgent ?? null},
      ${JSON.stringify(data)},
      ${timestamp}
    )
  `.catch((err: unknown) => {
    console.error('[KV_LOG] Failed to persist log to Postgres:', err);
  });
}

/**
 * 从请求中提取元数据用于日志
 */
export function getLogMetadata(request: NextRequest, userToken?: string): LogData {
  const ip = request.headers.get('x-forwarded-for') || request.headers.get('x-real-ip') || 'unknown';
  const userAgent = request.headers.get('user-agent') || 'unknown';
  
  return {
    userToken,
    ip,
    userAgent,
  };
}
