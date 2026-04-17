import { NextResponse, NextRequest } from 'next/server';
import { WayPoint, WayPointsResponse } from '@/types/route';
import { v4 as uuidv4 } from 'uuid';
import { wayPointsStorage } from '@/lib/waypoints-storage';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const waypoints = Array.from(wayPointsStorage.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );

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

    wayPointsStorage.set(wayPoint.id, wayPoint);

    return NextResponse.json(wayPoint);
  } catch (error) {
    console.error('Failed to create waypoint:', error);
    return NextResponse.json(
      { error: 'Failed to create waypoint' },
      { status: 500 }
    );
  }
}
