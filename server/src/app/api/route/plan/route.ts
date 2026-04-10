import { NextResponse, NextRequest } from 'next/server';
import { RouteRequest, RouteResponse } from '@/types/route';
import { getCameras } from '@/lib/cache';
import { planAvoidCamerasRoute, generateLinearRoute, findCamerasNearRoute, createRoute } from '@/lib/route';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const body: RouteRequest = await request.json();
    const { start, end, avoidCameras } = body;

    // 验证输入
    if (!start || !end || typeof start.lat !== 'number' || typeof start.lng !== 'number') {
      return NextResponse.json(
        { errorMessage: '起点坐标无效' },
        { status: 400 }
      );
    }
    if (typeof end.lat !== 'number' || typeof end.lng !== 'number') {
      return NextResponse.json(
        { errorMessage: '终点坐标无效' },
        { status: 400 }
      );
    }

    // 获取摄像头数据
    const { cameras } = await getCameras();

    let polylinePoints;
    let cameraIndices;

    if (avoidCameras) {
      // 规划避开摄像头的路线
      const result = planAvoidCamerasRoute(start, end, cameras);
      polylinePoints = result.points;
      cameraIndices = result.cameraIndices;
    } else {
      // 规划普通路线
      polylinePoints = generateLinearRoute(start, end);
      cameraIndices = findCamerasNearRoute(polylinePoints, cameras);
    }

    // 创建路由对象
    const route = createRoute(
      start,
      end,
      polylinePoints,
      cameraIndices,
      avoidCameras
    );

    const response: RouteResponse = { route };
    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to plan route:', error);
    return NextResponse.json(
      { errorMessage: '路线规划失败: ' + String(error) },
      { status: 500 }
    );
  }
}
