import { NextResponse, NextRequest } from 'next/server';
import { WayPoint, WayPointsResponse } from '@/types/route';
import { v4 as uuidv4 } from 'uuid';
import { listWayPoints, saveWayPoint } from '@/lib/waypoints-storage';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const tokenGuard = await requireActiveUserTokenFromRequest(request);
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    const waypoints = await listWayPoints(tokenGuard.userToken!);

    const response: WayPointsResponse = { waypoints };
    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to fetch waypoints:', error);
    return NextResponse.json(
      { error: 'Failed to fetch waypoints' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, lat, lng } = body;

    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as Record<string, unknown>
    );
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    // 验证输入
    if (!name || typeof lat !== 'number' || typeof lng !== 'number') {
      return NextResponse.json(
        { error: '无效的输入参数' },
        { status: 400 }
      );
    }

    const wayPoint: WayPoint = {
      id: uuidv4(),
      name,
      lat,
      lng,
      createdAt: new Date().toISOString(),
    };

    await saveWayPoint(tokenGuard.userToken!, wayPoint);

    return NextResponse.json(wayPoint);
  } catch (error) {
    console.error('Failed to create waypoint:', error);
    return NextResponse.json(
      { error: 'Failed to create waypoint' },
      { status: 500 }
    );
  }
}
