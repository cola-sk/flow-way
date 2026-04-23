import { NextRequest, NextResponse } from 'next/server';
import { kvLog, getLogMetadata } from '@/lib/kv-logger';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { event, data } = body;
    const userToken = request.headers.get('x-user-token') || body.userToken;

    if (!event) {
      return NextResponse.json({ error: 'Missing event name' }, { status: 400 });
    }

    const metadata = getLogMetadata(request, userToken);
    
    // 合并元数据和上报的数据
    kvLog(event, {
      ...metadata,
      ...data,
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to log event:', error);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
