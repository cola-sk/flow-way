import { NextRequest, NextResponse } from 'next/server';
import {
  listRoutePlanRecords,
  NamedCoordinate,
  saveRoutePlanRecord,
} from '@/lib/saved-navigation';

export const dynamic = 'force-dynamic';

function isValidPoint(point: NamedCoordinate | undefined): point is NamedCoordinate {
  return Boolean(
    point &&
      typeof point.name === 'string' &&
      typeof point.lat === 'number' &&
      typeof point.lng === 'number'
  );
}

export async function GET() {
  try {
    const plans = await listRoutePlanRecords();
    return NextResponse.json({ plans });
  } catch (error) {
    console.error('Failed to fetch saved route plans:', error);
    return NextResponse.json({ error: 'Failed to fetch saved route plans' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const start = body?.start as NamedCoordinate | undefined;
    const end = body?.end as NamedCoordinate | undefined;
    const waypoints = (body?.waypoints as NamedCoordinate[] | undefined) ?? [];
    const name = body?.name as string | undefined;
    const avoidCameras = body?.avoidCameras as boolean | undefined;

    if (!isValidPoint(start) || !isValidPoint(end)) {
      return NextResponse.json({ error: '无效的起终点数据' }, { status: 400 });
    }

    const normalizedWaypoints = waypoints.filter(isValidPoint);
    const saved = await saveRoutePlanRecord({
      name,
      start,
      end,
      waypoints: normalizedWaypoints,
      avoidCameras,
    });

    return NextResponse.json(saved);
  } catch (error) {
    console.error('Failed to save route plan:', error);
    return NextResponse.json({ error: 'Failed to save route plan' }, { status: 500 });
  }
}
