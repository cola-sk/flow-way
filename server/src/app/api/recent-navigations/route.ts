import { NextRequest, NextResponse } from 'next/server';
import {
  listRecentNavigationRecords,
  NamedCoordinate,
  saveRecentNavigationRecord,
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
    const records = await listRecentNavigationRecords();
    return NextResponse.json({ records });
  } catch (error) {
    console.error('Failed to fetch recent navigations:', error);
    return NextResponse.json({ error: 'Failed to fetch recent navigations' }, { status: 500 });
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
    const source = body?.source as string | undefined;

    if (!isValidPoint(start) || !isValidPoint(end)) {
      return NextResponse.json({ error: '无效的起终点数据' }, { status: 400 });
    }

    const saved = await saveRecentNavigationRecord({
      name,
      start,
      end,
      waypoints: waypoints.filter(isValidPoint),
      avoidCameras,
      source,
    });

    return NextResponse.json(saved);
  } catch (error) {
    console.error('Failed to save recent navigation:', error);
    return NextResponse.json({ error: 'Failed to save recent navigation' }, { status: 500 });
  }
}
