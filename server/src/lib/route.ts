import { Coordinate, Route, RoutePoint } from '@/types/route';
import { Camera } from '@/types/camera';
import { v4 as uuidv4 } from 'uuid';

/**
 * 计算两点间距离（单位：米）
 * 使用Haversine公式
 */
export function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000; // 地球半径（米）
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * 简单的直线路线生成（用于演示）
 * 实际应该集成高德地图或其他路由服务
 */
export function generateLinearRoute(start: Coordinate, end: Coordinate): RoutePoint[] {
  const points: RoutePoint[] = [];
  const steps = 50; // 路线上的点数

  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    points.push({
      lat: start.lat + (end.lat - start.lat) * t,
      lng: start.lng + (end.lng - start.lng) * t,
    });
  }

  return points;
}

/**
 * 检查摄像头是否在路线附近（距离阈值：100米）
 */
export function findCamerasNearRoute(
  polylinePoints: RoutePoint[],
  cameras: Camera[],
  threshold: number = 100
): number[] {
  const cameraIndices: number[] = [];

  cameras.forEach((camera, index) => {
    const cameraLat = camera.lat;
    const cameraLng = camera.lng;

    const nearRoute = polylinePoints.some((point) => {
      const distance = calculateDistance(
        point.lat,
        point.lng,
        cameraLat,
        cameraLng
      );
      return distance < threshold;
    });

    if (nearRoute) {
      cameraIndices.push(index);
    }
  });

  return cameraIndices;
}

/**
 * 规划避开摄像头的路线
 * 简化实现：生成几条备选路线，选择摄像头最少的
 */
export function planAvoidCamerasRoute(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[]
): { points: RoutePoint[]; cameraIndices: number[] } {
  // 简化实现：生成3条路线并比较
  const routes: { points: RoutePoint[]; cameraIndices: number[] }[] = [];

  // 路线1: 直线（基础路线）
  const directRoute = generateLinearRoute(start, end);
  const directCameras = findCamerasNearRoute(directRoute, cameras);
  routes.push({ points: directRoute, cameraIndices: directCameras });

  // 路线2: 向左偏移
  const northOffset = { lat: start.lat + 0.01, lng: start.lng - 0.01 };
  const northRoute = [
    ...generateLinearRoute(start, northOffset),
    ...generateLinearRoute(northOffset, end),
  ];
  const northCameras = findCamerasNearRoute(northRoute, cameras);
  routes.push({ points: northRoute, cameraIndices: northCameras });

  // 路线3: 向右偏移
  const southOffset = { lat: start.lat - 0.01, lng: start.lng + 0.01 };
  const southRoute = [
    ...generateLinearRoute(start, southOffset),
    ...generateLinearRoute(southOffset, end),
  ];
  const southCameras = findCamerasNearRoute(southRoute, cameras);
  routes.push({ points: southRoute, cameraIndices: southCameras });

  // 选择摄像头最少的路线
  return routes.reduce((best, current) =>
    current.cameraIndices.length < best.cameraIndices.length ? current : best
  );
}

/**
 * 创建路线对象
 */
export function createRoute(
  start: Coordinate,
  end: Coordinate,
  polylinePoints: RoutePoint[],
  cameraIndices: number[],
  avoidCameras: boolean
): Route {
  const distance = calculateDistance(start.lat, start.lng, end.lat, end.lng);
  const duration = Math.round(distance / 13.33); // 假设平均时速48km/h

  return {
    id: uuidv4(),
    startPoint: { lat: start.lat, lng: start.lng },
    endPoint: { lat: end.lat, lng: end.lng },
    polylinePoints,
    distance,
    duration,
    routeType: avoidCameras ? 'avoid_cameras' : 'normal',
    cameraIndicesOnRoute: cameraIndices,
    createdAt: new Date().toISOString(),
  };
}
