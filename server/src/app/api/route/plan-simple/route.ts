import { NextResponse, NextRequest } from 'next/server';
import { RouteRequest, RouteResponse } from '@/types/route';
import { getCamerasEnhanced } from '@/lib/cache';
import { isRouteDetected, calculateBearing } from '@/lib/camera-detection-simple';
import {
  planAvoidCamerasRoute,
  generateLinearRoute,
  createRoute,
} from '@/lib/route';

export const dynamic = 'force-dynamic';

/**
 * 简化的路线规划 API
 * 核心算法：根据路线方向和摄像头拍摄方向的夹角来判断是否会被拍到
 */
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

    // 获取增强的摄像头数据
    const { cameras } = await getCamerasEnhanced();

    let polylinePoints;
    let cameraIndices = [];
    let detectionDetails: any[] = [];

    if (avoidCameras) {
      // 规划避开摄像头的路线
      const result = planAvoidCamerasRoute(start, end, cameras as any);
      polylinePoints = result.points;
    } else {
      // 规划普通路线
      polylinePoints = generateLinearRoute(start, end);
    }

    // 计算整个路线的方向
    const routeBearing = calculateBearing(
      polylinePoints[0].lat,
      polylinePoints[0].lng,
      polylinePoints[polylinePoints.length - 1].lat,
      polylinePoints[polylinePoints.length - 1].lng
    );

    // 遍历所有摄像头，检测是否会被拍到
    cameras.forEach((camera, index) => {
      // 使用简化的检测算法
      const detected = isRouteDetected(
        polylinePoints,
        camera.lat,
        camera.lng,
        camera.direction as any,
        100 // 距离阈值100米
      );

      if (detected) {
        cameraIndices.push(index);

        // 记录详细信息
        const cameraBearing = camera.direction === 'east_west' ? 270 : 
                             camera.direction === 'west_east' ? 90 :
                             camera.direction === 'south_north' ? 0 :
                             camera.direction === 'north_south' ? 180 :
                             camera.direction === 'east' ? 90 :
                             camera.direction === 'west' ? 270 :
                             camera.direction === 'south' ? 180 :
                             camera.direction === 'north' ? 0 : -1;

        if (cameraBearing !== -1) {
          // 计算夹角
          let angle = Math.abs(routeBearing - cameraBearing);
          if (angle > 180) angle = 360 - angle;

          detectionDetails.push({
            cameraIndex: index,
            cameraName: camera.name,
            cameraDirection: camera.direction,
            routeBearing: Math.round(routeBearing * 10) / 10,
            cameraBearing,
            angleGap: Math.round(angle * 10) / 10,
            detected: true,
          });
        }
      }
    });

    // 创建路由对象
    const route = createRoute(
      start,
      end,
      polylinePoints,
      cameraIndices,
      avoidCameras
    );

    const response: RouteResponse = {
      route,
      cameraDetections: detectionDetails, // 返回检测详情
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to plan route:', error);
    return NextResponse.json(
      { errorMessage: '路线规划失败: ' + String(error) },
      { status: 500 }
    );
  }
}
