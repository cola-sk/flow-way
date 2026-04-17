import { NextResponse, NextRequest } from 'next/server';
import { RouteRequest, RouteResponse } from '@/types/route';
import { getCameras } from '@/lib/cache';
import { planRoute, planAvoidCamerasRoute, findCamerasNearRoute, createRoute } from '@/lib/route';
import { getDismissedSet, coordKey } from '@/lib/dismissed-cameras';

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

    // 获取摄像头数据，过滤掉用户标记废弃的（Redis 持久化，60s 内存缓存）
    let { cameras } = await getCameras();
    const dismissedSet = await getDismissedSet();
    if (dismissedSet.size > 0) {
      cameras = cameras.filter((cam) => !dismissedSet.has(coordKey(cam.lat, cam.lng)));
    }

    let polylinePoints;
    let cameraIndices;

    let routeDistance: number | undefined;
    let routeDuration: number | undefined;

    if (avoidCameras) {
      // 规划避开摄像头的路线（腾讯地图备选路线中选摄像头最少的）
      const result = await planAvoidCamerasRoute(start, end, cameras);
      polylinePoints = result.points;
      cameraIndices = result.cameraIndices;
      routeDistance = result.distance;
      routeDuration = result.duration;
    } else {
      // 规划普通路线（腾讯地图真实路网）
      const result = await planRoute(start, end);
      polylinePoints = result.points;
      cameraIndices = findCamerasNearRoute(polylinePoints, cameras);
      routeDistance = result.distance;
      routeDuration = result.duration;
    }

    // 创建路由对象
    const route = createRoute(
      start,
      end,
      polylinePoints,
      cameraIndices,
      avoidCameras,
      routeDistance,
      routeDuration
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
