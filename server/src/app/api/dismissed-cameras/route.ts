import { NextResponse, NextRequest } from 'next/server';
import {
  getDismissedList,
  markDismissed,
  unmarkDismissed,
  invalidateDismissedCache,
} from '@/lib/dismissed-cameras';

export const dynamic = 'force-dynamic';

/** GET /api/dismissed-cameras — 获取所有废弃摄像头列表 */
export async function GET() {
  try {
    const list = await getDismissedList();
    return NextResponse.json({ dismissed: list, total: list.length });
  } catch (error) {
    console.error('Failed to get dismissed cameras:', error);
    return NextResponse.json({ error: '获取废弃摄像头列表失败' }, { status: 500 });
  }
}

/** POST /api/dismissed-cameras — 标记摄像头为废弃 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { lat, lng, name } = body;

    if (typeof lat !== 'number' || typeof lng !== 'number' || !name) {
      return NextResponse.json({ error: '参数无效，需要 lat/lng/name' }, { status: 400 });
    }

    const entry = await markDismissed(lat, lng, name as string);
    invalidateDismissedCache();
    return NextResponse.json(entry);
  } catch (error) {
    console.error('Failed to mark dismissed camera:', error);
    return NextResponse.json({ error: '标记废弃失败' }, { status: 500 });
  }
}

/** DELETE /api/dismissed-cameras — 取消废弃标记 */
export async function DELETE(request: NextRequest) {
  try {
    const body = await request.json();
    const { lat, lng } = body;

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json({ error: '参数无效，需要 lat/lng' }, { status: 400 });
    }

    const removed = await unmarkDismissed(lat, lng);
    invalidateDismissedCache();
    return NextResponse.json({ removed });
  } catch (error) {
    console.error('Failed to unmark dismissed camera:', error);
    return NextResponse.json({ error: '取消标记失败' }, { status: 500 });
  }
}
