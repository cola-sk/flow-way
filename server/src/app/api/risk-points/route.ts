import { NextResponse, NextRequest } from 'next/server';
import { v4 as uuidv4 } from 'uuid';
import {
  listRiskPoints,
  normalizeRiskPointDirection,
  normalizeRiskPointType,
  saveRiskPoint,
  type RiskPoint,
} from '@/lib/risk-points-storage';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const tokenGuard = await requireActiveUserTokenFromRequest(request);
    if (!tokenGuard.ok) return tokenGuard.response!;
    const riskPoints = await listRiskPoints(tokenGuard.userToken!);
    return NextResponse.json({ riskPoints });
  } catch (error) {
    console.error('Failed to fetch risk points:', error);
    return NextResponse.json({ error: '获取风险点失败' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, lat, lng, type, direction, note } = body;
    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as Record<string, unknown>
    );
    if (!tokenGuard.ok) return tokenGuard.response!;
    if (typeof name !== 'string' || !name.trim() || typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json({ error: '参数无效，需要 name/lat/lng' }, { status: 400 });
    }
    if (!Number.isFinite(lat) || !Number.isFinite(lng) ||
        (type !== undefined && !['risk', 'low_risk', 'low_risk_access_road'].includes(type)) ||
        (direction !== undefined && !['both', 'east_west', 'west_east', 'south_north', 'north_south'].includes(direction)) ||
        (note !== undefined && typeof note !== 'string')) {
      return NextResponse.json({ error: '参数无效' }, { status: 400 });
    }

    const riskPoint: RiskPoint = {
      id: uuidv4(),
      name: name.trim(),
      lat,
      lng,
      type: normalizeRiskPointType(type),
      direction: normalizeRiskPointDirection(direction),
      note: typeof note === 'string' ? note.trim() : '',
      createdAt: new Date().toISOString(),
    };
    await saveRiskPoint(tokenGuard.userToken!, riskPoint);
    return NextResponse.json(riskPoint);
  } catch (error) {
    console.error('Failed to create risk point:', error);
    return NextResponse.json({ error: '创建风险点失败' }, { status: 500 });
  }
}
