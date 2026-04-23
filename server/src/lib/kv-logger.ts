import { NextRequest } from 'next/server';

export interface LogData extends Record<string, any> {
  userToken?: string;
  ip?: string;
  userAgent?: string;
}

/**
 * 记录 KV 格式的日志
 * 格式示例: [KV_LOG] timestamp=2024-04-23T03:00:00Z event=first_install userToken="abc" ...
 */
export function kvLog(event: string, data: LogData) {
  const timestamp = new Date().toISOString();
  
  // 基础字段
  const baseFields = {
    timestamp,
    event,
  };

  const allFields = { ...baseFields, ...data };

  const kvString = Object.entries(allFields)
    .map(([k, v]) => {
      let val = v;
      if (typeof v === 'object' && v !== null) {
        val = JSON.stringify(v);
      } else if (typeof v === 'string') {
        // 如果包含空格，则加引号
        if (v.includes(' ') || v.includes('"') || v.includes('=')) {
          val = `"${v.replace(/"/g, '\\"')}"`;
        }
      }
      return `${k}=${val}`;
    })
    .join(' ');

  // 这里的 console.log 会输出到 Vercel/Node.js 日志中，方便后续数据统计
  console.log(`[KV_LOG] ${kvString}`);
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
