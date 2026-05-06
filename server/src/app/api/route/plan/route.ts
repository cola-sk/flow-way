import { NextResponse, NextRequest } from 'next/server';
import { RouteRequest, RouteResponse } from '@/types/route';
import { getCameras } from '@/lib/cache';
import {
  planRoute,
  planAvoidCamerasRoute,
  findCamerasNearRoute,
  createRoute,
  isRoutePlanningAbortedError,
} from '@/lib/route';
import { getDismissedMap, coordKey } from '@/lib/dismissed-cameras';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const body: RouteRequest = await request.json();
    const { start, end, avoidCameras, ignoreOutsideSixthRing, ignoreLowRiskCameras } = body;

    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as unknown as Record<string, unknown>
    );
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }
    const userToken = tokenGuard.userToken!;

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
    const { cameras: originalCameras } = await getCameras();
    const dismissedMap = await getDismissedMap(userToken);
    const shouldIgnoreOutsideSixth =
      avoidCameras && ignoreOutsideSixthRing === true;
    const shouldIgnoreLowRisk =
      avoidCameras && ignoreLowRiskCameras === true;

    // 解析出客户端传过来的除当前正在规划以外的历史路线（用于再试一次）
    const excludePolylines = (body as any).excludePolylines as RoutePoint[][] | undefined;

    const cameras: typeof originalCameras = [];
    const indexMapping: Record<number, number> = {};

    let filteredIdx = 0;
    for (let i = 0; i < originalCameras.length; i++) {
      const cam = originalCameras[i];
      const markType = dismissedMap.get(coordKey(cam.lat, cam.lng));

      if (markType !== undefined) {
        if (markType === 12 && !shouldIgnoreLowRisk) {
          // 不忽略低风险，作为有效摄像头保留
        } else {
          continue;
        }
      }

      if (shouldIgnoreOutsideSixth && cam.type === 6) {
        continue;
      }
      cameras.push(cam);
      indexMapping[filteredIdx++] = i;
    }

    let polylinePoints;
    let cameraIndices;

    let routeDistance: number | undefined;
    let routeDuration: number | undefined;

    let routeSteps;
    if (avoidCameras) {
      // 规划避开摄像头的路线（腾讯地图备选路线中选摄像头最少的）
      const result = await planAvoidCamerasRoute(
        start,
        end,
        cameras,
        0,
        undefined,
        request.signal,
        excludePolylines
      );
      polylinePoints = result.points;
      cameraIndices = result.cameraIndices.map((i) => indexMapping[i]);
      routeDistance = result.distance;
      routeDuration = result.duration;
      routeSteps = result.steps;
    } else {
      // 规划普通路线（腾讯地图真实路网）
      const result = await planRoute(start, end, request.signal);
      polylinePoints = result.points;
      const rawIndices = findCamerasNearRoute(polylinePoints, cameras);
      cameraIndices = rawIndices.map((i) => indexMapping[i]);
      routeDistance = result.distance;
      routeDuration = result.duration;
      routeSteps = result.steps;
    }

    // 创建路由对象
    const route = createRoute(
      start,
      end,
      polylinePoints,
      cameraIndices,
      avoidCameras,
      routeDistance,
      routeDuration,
      undefined,
      routeSteps
    );

    const response: RouteResponse = { route };
    return NextResponse.json(response);
  } catch (error) {
    if (request.signal.aborted || isRoutePlanningAbortedError(error)) {
      return NextResponse.json(
        { errorMessage: '客户端已取消路线规划' },
        { status: 499 }
      );
    }

    console.error('Failed to plan route:', error);
    return NextResponse.json(
      { errorMessage: '路线规划失败: ' + String(error) },
      { status: 500 }
    );
  }
}
