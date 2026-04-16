import { Coordinate, Route, RoutePoint } from '@/types/route';
import { Camera } from '@/types/camera';
import { v4 as uuidv4 } from 'uuid';

const TENCENT_MAP_KEY = process.env.TENCENT_MAP_KEY ?? '';

/**
 * 计算两点间距离（单位：米）
 * 使用 Haversine 公式
 */
export function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
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
 * 检查摄像头是否在路线附近（距离阈值：100 米）
 */
export function findCamerasNearRoute(
  polylinePoints: RoutePoint[],
  cameras: Camera[],
  threshold: number = 100
): number[] {
  const cameraIndices: number[] = [];

  cameras.forEach((camera, index) => {
    const nearRoute = polylinePoints.some((point) => {
      const distance = calculateDistance(point.lat, point.lng, camera.lat, camera.lng);
      return distance < threshold;
    });
    if (nearRoute) cameraIndices.push(index);
  });

  return cameraIndices;
}

/**
 * 将腾讯路线规划 API 返回的 polyline 平铺数组解码为坐标点
 * API 格式：[lat0, lng0, lat1, lng1, ...]
 */
function decodeTencentPolyline(polyline: number[]): RoutePoint[] {
  const points: RoutePoint[] = [];
  for (let i = 0; i + 1 < polyline.length; i += 2) {
    points.push({ lat: polyline[i], lng: polyline[i + 1] });
  }
  return points;
}

/**
 * 调用腾讯地图驾车路线规划 WebService API
 * 注意：腾讯 API 坐标格式为 lat,lng（纬度在前，经度在后）
 * @param alternatives 是否请求备选路线（alternatives=1 最多返回 3 条）
 */
async function callTencentDrivingAPI(
  start: Coordinate,
  end: Coordinate,
  alternatives = false
): Promise<Array<{ points: RoutePoint[]; distance: number; duration: number }>> {
  if (!TENCENT_MAP_KEY) {
    throw new Error('未配置 TENCENT_MAP_KEY 环境变量');
  }

  const params = new URLSearchParams({
    from: `${start.lat},${start.lng}`,
    to: `${end.lat},${end.lng}`,
    key: TENCENT_MAP_KEY,
  });
  if (alternatives) params.set('alternatives', '1');

  const url = `https://apis.map.qq.com/ws/direction/v1/driving/?${params}`;
  const res = await fetch(url, {
    headers: { Referer: 'https://flow-way.tz0618.uk' },
  });
  if (!res.ok) throw new Error(`腾讯地图 HTTP 错误: ${res.status}`);

  const data = await res.json();
  if (data.status !== 0) throw new Error(`腾讯地图路线规划失败: ${data.message}`);

  return (data.result.routes as any[]).map((route) => ({
    points: decodeTencentPolyline(route.polyline as number[]),
    distance: route.distance as number,
    duration: route.duration as number,
  }));
}

/**
 * 直线备用路线（腾讯 API 不可用时回退使用）
 */
function generateFallbackRoute(start: Coordinate, end: Coordinate): RoutePoint[] {
  const points: RoutePoint[] = [];
  const steps = 50;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    points.push({
      lat: start.lat + (end.lat - start.lat) * t,
      lng: start.lng + (end.lng - start.lng) * t,
    });
  }
  return points;
}

/** @deprecated 仅作回退用直线路线，优先使用 planRoute() */
export const generateLinearRoute = generateFallbackRoute;

/**
 * 规划普通路线（腾讯地图真实路网，API 不可用时回退直线）
 */
export async function planRoute(
  start: Coordinate,
  end: Coordinate
): Promise<{ points: RoutePoint[]; distance: number; duration: number }> {
  try {
    const routes = await callTencentDrivingAPI(start, end);
    return routes[0];
  } catch (err) {
    console.warn('腾讯路线规划失败，回退到直线:', err);
    const points = generateFallbackRoute(start, end);
    const distance = calculateDistance(start.lat, start.lng, end.lat, end.lng);
    return { points, distance, duration: Math.round(distance / 13.33) };
  }
}

/**
 * 规划避开摄像头路线
 * 腾讯 API 返回最多 3 条备选路线，选择途经摄像头最少的一条
 */
export async function planAvoidCamerasRoute(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[]
): Promise<{ points: RoutePoint[]; cameraIndices: number[]; distance: number; duration: number }> {
  let allRoutes: Array<{ points: RoutePoint[]; distance: number; duration: number }>;

  try {
    allRoutes = await callTencentDrivingAPI(start, end, true);
  } catch (err) {
    console.warn('腾讯路线规划失败，回退到直线:', err);
    const points = generateFallbackRoute(start, end);
    const distance = calculateDistance(start.lat, start.lng, end.lat, end.lng);
    allRoutes = [{ points, distance, duration: Math.round(distance / 13.33) }];
  }

  // 对每条备选路线计算途经摄像头，选择摄像头最少的一条
  const evaluated = allRoutes.map((route) => ({
    ...route,
    cameraIndices: findCamerasNearRoute(route.points, cameras),
  }));

  return evaluated.reduce((best, cur) =>
    cur.cameraIndices.length < best.cameraIndices.length ? cur : best
  );
}

/**
 * 创建路线对象
 * distanceMeters / durationSeconds 优先使用腾讯 API 返回的实际值
 */
export function createRoute(
  start: Coordinate,
  end: Coordinate,
  polylinePoints: RoutePoint[],
  cameraIndices: number[],
  avoidCameras: boolean,
  distanceMeters?: number,
  durationSeconds?: number
): Route {
  const distance = distanceMeters ?? calculateDistance(start.lat, start.lng, end.lat, end.lng);
  const duration = durationSeconds ?? Math.round(distance / 13.33);

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

