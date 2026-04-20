import { NextResponse, NextRequest } from 'next/server';
import { RouteRequest, RouteResponse } from '@/types/route';
import { getCamerasEnhanced } from '@/lib/cache';
import {
  assessCameraRisks,
  willBeDetectedByCamera,
  calculateBearing,
} from '@/lib/camera-parser';
import {
  planRoute,
  planAvoidCamerasRoute,
  createRoute,
  isRoutePlanningAbortedError,
} from '@/lib/route';
import { CameraDirection } from '@/types/camera-enhanced';

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

    // 获取增强的摄像头数据（包含方向信息）
    const { cameras } = await getCamerasEnhanced();

    let polylinePoints;
    let cameraIndices;
    let cameraRisks: any[] = [];

    let routeDistance: number | undefined;
    let routeDuration: number | undefined;

    if (avoidCameras) {
      // 规划避开摄像头的路线（腾讯地图备选路线）
      const result = await planAvoidCamerasRoute(
        start,
        end,
        cameras as any,
        0,
        undefined,
        request.signal
      );
      polylinePoints = result.points;
      routeDistance = result.distance;
      routeDuration = result.duration;

      // 使用增强的风险评估
      const routePoints = result.points.map(p => ({ lat: p.lat, lng: p.lng }));
      cameraRisks = assessCameraRisks(routePoints, cameras);

      // 只显示高风险的摄像头
      cameraIndices = cameraRisks
        .filter(r => r.risk === 'high')
        .map(r => r.cameraIndex);
    } else {
      // 规划普通路线（腾讯地图真实路网）
      const result = await planRoute(start, end, request.signal);
      polylinePoints = result.points;
      routeDistance = result.distance;
      routeDuration = result.duration;

      const routePoints = polylinePoints.map(p => ({ lat: p.lat, lng: p.lng }));
      cameraRisks = assessCameraRisks(routePoints, cameras);
      cameraIndices = cameraRisks.map(r => r.cameraIndex);
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

    // 添加详细的风险分析信息
    const detailedRisks = cameraRisks.map(risk => ({
      cameraIndex: risk.cameraIndex,
      cameraName: risk.camera.name,
      cameraDirection: risk.camera.direction,
      distance: risk.distance.toFixed(0),
      riskLevel: risk.risk,
      reason: risk.reason,
    }));

    const response: RouteResponse = {
      route,
      cameraRisks: detailedRisks,
    };

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
