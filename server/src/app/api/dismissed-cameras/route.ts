import { NextResponse, NextRequest } from 'next/server';
import {
  getDismissedList,
  markDismissed,
  unmarkDismissed,
  updateDismissedNote,
  invalidateDismissedCache,
} from '@/lib/dismissed-cameras';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';

export const dynamic = 'force-dynamic';

/** GET /api/dismissed-cameras — 获取所有废弃摄像头列表 */
export async function GET(request: NextRequest) {
  try {
    const tokenGuard = await requireActiveUserTokenFromRequest(request);
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    const userToken = tokenGuard.userToken!;
    const list = await getDismissedList(userToken);
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
    const { lat, lng, name, type, note } = body;

    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as Record<string, unknown>
    );
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    const userToken = tokenGuard.userToken!;

    if (typeof lat !== 'number' || typeof lng !== 'number' || !name) {
      return NextResponse.json({ error: '参数无效，需要 lat/lng/name' }, { status: 400 });
    }

    const markType = type === 12 ? 12 : 6;
    if (type !== undefined && type !== 6 && type !== 12) {
      return NextResponse.json({ error: '参数无效，type 仅支持 6 或 12' }, { status: 400 });
    }

    if (note !== undefined && typeof note !== 'string') {
      return NextResponse.json({ error: '参数无效，note 必须是字符串' }, { status: 400 });
    }

    const entry = await markDismissed(
      userToken,
      lat,
      lng,
      name as string,
      markType,
      typeof note === 'string' ? note : undefined
    );
    invalidateDismissedCache(userToken);
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

    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as Record<string, unknown>
    );
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    const userToken = tokenGuard.userToken!;

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json({ error: '参数无效，需要 lat/lng' }, { status: 400 });
    }

    const removed = await unmarkDismissed(userToken, lat, lng);
    invalidateDismissedCache(userToken);
    return NextResponse.json({ removed });
  } catch (error) {
    console.error('Failed to unmark dismissed camera:', error);
    return NextResponse.json({ error: '取消标记失败' }, { status: 500 });
  }
}

/** PATCH /api/dismissed-cameras — 编辑/删除摄像头标记备注 */
export async function PATCH(request: NextRequest) {
  try {
    const body = await request.json();
    const { lat, lng, note } = body;

    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as Record<string, unknown>
    );
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    const userToken = tokenGuard.userToken!;

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json({ error: '参数无效，需要 lat/lng' }, { status: 400 });
    }
    if (note !== undefined && note !== null && typeof note !== 'string') {
      return NextResponse.json({ error: '参数无效，note 必须是字符串或 null' }, { status: 400 });
    }

    const updated = await updateDismissedNote(
      userToken,
      lat,
      lng,
      typeof note === 'string' ? note : ''
    );
    if (!updated) {
      return NextResponse.json({ error: '未找到该标记摄像头' }, { status: 404 });
    }

    invalidateDismissedCache(userToken);
    return NextResponse.json(updated);
  } catch (error) {
    console.error('Failed to update dismissed camera note:', error);
    return NextResponse.json({ error: '更新备注失败' }, { status: 500 });
  }
}
