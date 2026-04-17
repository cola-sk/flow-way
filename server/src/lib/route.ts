import { Coordinate, Route, RoutePoint } from '@/types/route';
import { Camera } from '@/types/camera';
import { v4 as uuidv4 } from 'uuid';
import { signTencentUrl, getTencentMapKey } from './tencent-sign';

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
    // aa=4（待核实）摄像头不计入路线风险，无需躲避
    if (camera.type === 4) return;
    const nearRoute = polylinePoints.some((point) => {
      const distance = calculateDistance(point.lat, point.lng, camera.lat, camera.lng);
      return distance < threshold;
    });
    if (nearRoute) cameraIndices.push(index);
  });

  return cameraIndices;
}

/**
 * 将腾讯路线规划 API 返回的 polyline 解码为坐标点
 * 腾讯格式：第一对为绝对坐标（十进制度），后续每对为增量（单位 1e-6 度）
 */
function decodeTencentPolyline(polyline: number[]): RoutePoint[] {
  if (polyline.length < 2) return [];
  const points: RoutePoint[] = [];
  let lat = polyline[0];
  let lng = polyline[1];
  points.push({ lat, lng });
  for (let i = 2; i + 1 < polyline.length; i += 2) {
    lat += polyline[i] / 1e6;
    lng += polyline[i + 1] / 1e6;
    points.push({ lat, lng });
  }
  return points;
}

/**
 * 调用腾讯地图驾车路线规划 WebService API
 * 注意：腾讯 API 坐标格式为 lat,lng（纬度在前，经度在后）
 * @param alternatives 是否请求备选路线（alternatives=1 最多返回 3 条）
 * @param waypoints 途径点，用于绕行绕开障碍点（最多 16 个）
 */
async function callTencentDrivingAPI(
  start: Coordinate,
  end: Coordinate,
  alternatives = false,
  waypoints?: Coordinate[]
): Promise<Array<{ points: RoutePoint[]; distance: number; duration: number }>> {
  if (!getTencentMapKey()) {
    throw new Error('未配置 TENCENT_MAP_KEY 环境变量');
  }

  const baseUrl = new URL('https://apis.map.qq.com/ws/direction/v1/driving/');
  baseUrl.searchParams.set('from', `${start.lat},${start.lng}`);
  baseUrl.searchParams.set('to', `${end.lat},${end.lng}`);
  if (alternatives) baseUrl.searchParams.set('alternatives', '1');
  if (waypoints && waypoints.length > 0) {
    baseUrl.searchParams.set('waypoints', waypoints.map((w) => `${w.lat},${w.lng}`).join(';'));
  }

  const url = signTencentUrl(baseUrl);
  const res = await fetch(url);
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
 * 计算路线上某点的垂直偏移绕行点（左右各一个）
 * 用于强制路线绕过摄像头
 */
function computePerpendicularOffsets(
  routePoints: RoutePoint[],
  cameraLat: number,
  cameraLng: number,
  offsetMeters: number = 350
): { left: Coordinate; right: Coordinate } {
  // 找到路线上距摄像头最近的点
  let minDist = Infinity;
  let nearestIdx = 0;
  for (let i = 0; i < routePoints.length; i++) {
    const d = calculateDistance(routePoints[i].lat, routePoints[i].lng, cameraLat, cameraLng);
    if (d < minDist) {
      minDist = d;
      nearestIdx = i;
    }
  }

  // 获取该点附近的路线方向向量
  const prevIdx = Math.max(0, nearestIdx - 5);
  const nextIdx = Math.min(routePoints.length - 1, nearestIdx + 5);
  const p1 = routePoints[prevIdx];
  const p2 = routePoints[nextIdx];

  const dLat = p2.lat - p1.lat;
  const dLng = p2.lng - p1.lng;
  const len = Math.sqrt(dLat * dLat + dLng * dLng);

  const cosLat = Math.cos((cameraLat * Math.PI) / 180);
  const latPerDeg = 111000;
  const lngPerDeg = 111000 * cosLat;

  if (len < 1e-10) {
    // 无法计算方向时，东西方向偏移
    const latOff = offsetMeters / latPerDeg;
    return {
      left: { lat: cameraLat + latOff, lng: cameraLng },
      right: { lat: cameraLat - latOff, lng: cameraLng },
    };
  }

  // 垂直方向：(dLat, dLng) 旋转 90° -> (-dLng, dLat) 和 (dLng, -dLat)
  const perpLat = -dLng / len;
  const perpLng = dLat / len;

  return {
    left: {
      lat: cameraLat + (perpLat * offsetMeters) / latPerDeg,
      lng: cameraLng + (perpLng * offsetMeters) / lngPerDeg,
    },
    right: {
      lat: cameraLat - (perpLat * offsetMeters) / latPerDeg,
      lng: cameraLng - (perpLng * offsetMeters) / lngPerDeg,
    },
  };
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
 * 策略：
 *   1. 腾讯 API 最多返回 3 条备选路线，选摄像头最少的；
 *   2. 若仍有摄像头残留，对路线上所有摄像头（最多 16 个，API 限制）分别以
 *      300m / 500m 偏移距离，按左侧全绕、右侧全绕、左右交替三种方向
 *      各生成一组途径点，并行发起 6 次 API 请求，取摄像头最少的结果；
 *   3. 若第二步后仍有摄像头，以新的最优路线为基准再执行一轮（共最多 2 轮）。
 *
 * 总 API 调用次数：1（备选）+ 最多 6×2（2 轮策略）= 13 次，并行执行，
 * 实际耗时约 1-2 秒。
 */
export async function planAvoidCamerasRoute(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[]
): Promise<{ points: RoutePoint[]; cameraIndices: number[]; distance: number; duration: number }> {
  type EvaluatedRoute = { points: RoutePoint[]; distance: number; duration: number; cameraIndices: number[] };

  async function fetchAndEvaluate(
    wps?: Coordinate[],
    alts = false
  ): Promise<EvaluatedRoute[]> {
    try {
      const routes = await callTencentDrivingAPI(start, end, alts, wps);
      return routes.map((r) => ({ ...r, cameraIndices: findCamerasNearRoute(r.points, cameras) }));
    } catch (err) {
      console.warn('腾讯路线规划失败:', err);
      return [];
    }
  }

  // Step 1：获取 3 条备选路线
  let candidates: EvaluatedRoute[] = await fetchAndEvaluate(undefined, true);

  if (candidates.length === 0) {
    // 回退直线
    const points = generateFallbackRoute(start, end);
    const distance = calculateDistance(start.lat, start.lng, end.lat, end.lng);
    candidates = [{ points, distance, duration: Math.round(distance / 13.33), cameraIndices: findCamerasNearRoute(points, cameras) }];
  }

  let best = candidates.reduce((a, b) => b.cameraIndices.length < a.cameraIndices.length ? b : a);

  // Step 2 & 3：多策略、多轮迭代绕行（最多 2 轮）
  const MAX_WAYPOINTS = 16; // 腾讯地图途径点上限
  const OFFSET_DISTANCES = [300, 500]; // 偏移距离（米）

  for (let round = 0; round < 2 && best.cameraIndices.length > 0; round++) {
    const camerasOnRoute = best.cameraIndices.slice(0, MAX_WAYPOINTS).map((i) => cameras[i]);

    // 为每种偏移距离生成三组途径点：左侧全绕 / 右侧全绕 / 左右交替
    const strategyWaypoints: Coordinate[][] = [];

    for (const offsetMeters of OFFSET_DISTANCES) {
      const leftWps: Coordinate[] = [];
      const rightWps: Coordinate[] = [];
      const altWps: Coordinate[] = [];

      for (let i = 0; i < camerasOnRoute.length; i++) {
        const { left, right } = computePerpendicularOffsets(
          best.points,
          camerasOnRoute[i].lat,
          camerasOnRoute[i].lng,
          offsetMeters
        );
        leftWps.push(left);
        rightWps.push(right);
        altWps.push(i % 2 === 0 ? left : right);
      }

      strategyWaypoints.push(leftWps, rightWps);
      if (camerasOnRoute.length > 1) strategyWaypoints.push(altWps);
    }

    // 并行发起所有策略请求
    const results = await Promise.allSettled(
      strategyWaypoints.map((wps) => fetchAndEvaluate(wps))
    );

    for (const result of results) {
      if (result.status === 'fulfilled') {
        for (const route of result.value) {
          if (route.cameraIndices.length < best.cameraIndices.length) {
            best = route;
          }
        }
      }
    }
  }

  return best;
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

