import { NextRequest, NextResponse } from 'next/server';
import { Route } from '@/types/route';
import {
  listRouteRecords,
  NamedCoordinate,
  saveRouteRecord,
} from '@/lib/saved-navigation';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const routes = await listRouteRecords();
    return NextResponse.json({ routes });
  } catch (error) {
    console.error('Failed to fetch saved routes:', error);
    return NextResponse.json({ error: 'Failed to fetch saved routes' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const route = body?.route as Route | undefined;
    const name = body?.name as string | undefined;
    const stops = body?.stops as NamedCoordinate[] | undefined;

    if (
      !route ||
      !route.startPoint ||
      !route.endPoint ||
      !Array.isArray(route.polylinePoints) ||
      route.polylinePoints.length === 0
    ) {
      return NextResponse.json({ error: '无效的线路数据' }, { status: 400 });
    }

    const saved = await saveRouteRecord({ name, route, stops });
    return NextResponse.json(saved);
  } catch (error) {
    console.error('Failed to save route:', error);
    return NextResponse.json({ error: 'Failed to save route' }, { status: 500 });
  }
}
