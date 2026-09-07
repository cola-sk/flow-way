import { NextResponse, NextRequest } from 'next/server';
import {
  deleteRiskPoint,
  getRiskPoint,
  normalizeRiskPointDirection,
  normalizeRiskPointType,
  saveRiskPoint,
} from '@/lib/risk-points-storage';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';

export const dynamic = 'force-dynamic';

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const body = await request.json();
    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as Record<string, unknown>
    );
    if (!tokenGuard.ok) return tokenGuard.response!;
    const { id } = await params;
    const current = await getRiskPoint(tokenGuard.userToken!, id);
    if (!current) return NextResponse.json({ error: '风险点不存在' }, { status: 404 });

    const { name, note, type, direction } = body;
    if ((name !== undefined && (typeof name !== 'string' || !name.trim())) ||
        (note !== undefined && typeof note !== 'string') ||
        (type !== undefined && !['risk', 'low_risk', 'low_risk_access_road'].includes(type)) ||
        (direction !== undefined && !['both', 'east_west', 'west_east', 'south_north', 'north_south'].includes(direction))) {
      return NextResponse.json({ error: '参数无效' }, { status: 400 });
    }
    const updated = {
      ...current,
      name: typeof name === 'string' ? name.trim() : current.name,
      note: typeof note === 'string' ? note.trim() : current.note,
      type: type === undefined ? current.type : normalizeRiskPointType(type),
      direction: direction === undefined
        ? normalizeRiskPointDirection(current.direction)
        : normalizeRiskPointDirection(direction),
    };
    await saveRiskPoint(tokenGuard.userToken!, updated);
    return NextResponse.json(updated);
  } catch (error) {
    console.error('Failed to update risk point:', error);
    return NextResponse.json({ error: '更新风险点失败' }, { status: 500 });
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const tokenGuard = await requireActiveUserTokenFromRequest(request);
    if (!tokenGuard.ok) return tokenGuard.response!;
    const { id } = await params;
    const deleted = await deleteRiskPoint(tokenGuard.userToken!, id);
    if (!deleted) return NextResponse.json({ error: '风险点不存在' }, { status: 404 });
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to delete risk point:', error);
    return NextResponse.json({ error: '删除风险点失败' }, { status: 500 });
  }
}
