import { Coordinate, Route, RoutePoint } from '@/types/route';
import { Camera } from '@/types/camera';
import { extractDirection } from './camera-parser';
import { CAMERA_DIRECTION_VECTORS, CameraDirection } from '@/types/camera-enhanced';
import { v4 as uuidv4 } from 'uuid';
import { signTencentUrl, getTencentMapKey } from './tencent-sign';

const MIN_TENCENT_REQUEST_INTERVAL_MS = 500;
let lastTencentRequestAt = 0;

async function waitTencentRequestSlot(): Promise<void> {
  const elapsed = Date.now() - lastTencentRequestAt;
  if (elapsed < MIN_TENCENT_REQUEST_INTERVAL_MS) {
    await new Promise((resolve) => setTimeout(resolve, MIN_TENCENT_REQUEST_INTERVAL_MS - elapsed));
  }
  lastTencentRequestAt = Date.now();
}

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

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

/**
 * 计算 from -> to 的方向角（0=北，90=东）
 */
function calculateBearing(from: RoutePoint, to: RoutePoint): number {
  const phi1 = toRad(from.lat);
  const phi2 = toRad(to.lat);
  const dLambda = toRad(to.lng - from.lng);

  const y = Math.sin(dLambda) * Math.cos(phi2);
  const x =
    Math.cos(phi1) * Math.sin(phi2) -
    Math.sin(phi1) * Math.cos(phi2) * Math.cos(dLambda);

  const bearing = (Math.atan2(y, x) * 180) / Math.PI;
  return (bearing + 360) % 360;
}

function angleGapDeg(a: number, b: number): number {
  let diff = Math.abs(a - b);
  if (diff > 180) diff = 360 - diff;
  return diff;
}

function getRouteBearingNearIndex(points: RoutePoint[], centerIdx: number): number | null {
  if (points.length < 2) return null;

  const prevIdx = Math.max(0, centerIdx - 2);
  const nextIdx = Math.min(points.length - 1, centerIdx + 2);
  if (prevIdx === nextIdx) return null;

  return calculateBearing(points[prevIdx], points[nextIdx]);
}

function getCameraBearingFromName(name: string): number | null {
  const direction = extractDirection(name);
  if (direction === CameraDirection.UNKNOWN) return null;
  const bearing = CAMERA_DIRECTION_VECTORS[direction];
  return typeof bearing === 'number' && bearing >= 0 ? bearing : null;
}

/**
 * 检查摄像头是否在路线附近（距离阈值：100 米）
 * 且路线通过方向与摄像头拍摄方向一致（方向未知时保守计入）
 */
export function findCamerasNearRoute(
  polylinePoints: RoutePoint[],
  cameras: Camera[],
  threshold: number = 100
): number[] {
  const cameraIndices: number[] = [];
  const DIRECTION_TOLERANCE_DEG = 60;

  if (polylinePoints.length === 0) return cameraIndices;

  cameras.forEach((camera, index) => {
    // aa=4（待核实）摄像头不计入路线风险，无需躲避
    if (camera.type === 4) return;

    // 找到离摄像头最近的路线点，用于距离和方向判断
    let minDistance = Infinity;
    let nearestIdx = 0;
    for (let i = 0; i < polylinePoints.length; i++) {
      const point = polylinePoints[i];
      const distance = calculateDistance(point.lat, point.lng, camera.lat, camera.lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIdx = i;
      }
    }

    if (minDistance >= threshold) return;

    const cameraBearing = getCameraBearingFromName(camera.name);
    if (cameraBearing === null) {
      // 名称没有可解析方向时，保守认为会拍到
      cameraIndices.push(index);
      return;
    }

    const routeBearing = getRouteBearingNearIndex(polylinePoints, nearestIdx);
    if (routeBearing === null) {
      cameraIndices.push(index);
      return;
    }

    const gap = angleGapDeg(routeBearing, cameraBearing);
    if (gap <= DIRECTION_TOLERANCE_DEG) {
      cameraIndices.push(index);
    }
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

  await waitTencentRequestSlot();
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

  const anchor = routePoints[nearestIdx];
  const anchorLat = anchor.lat;
  const anchorLng = anchor.lng;

  const cosLat = Math.cos((anchorLat * Math.PI) / 180);
  const latPerDeg = 111000;
  const lngPerDeg = 111000 * cosLat;

  if (len < 1e-10) {
    // 无法计算方向时，东西方向偏移
    const latOff = offsetMeters / latPerDeg;
    return {
      left: { lat: anchorLat + latOff, lng: anchorLng },
      right: { lat: anchorLat - latOff, lng: anchorLng },
    };
  }

  // 垂直方向：(dLat, dLng) 旋转 90° -> (-dLng, dLat) 和 (dLng, -dLat)
  const perpLat = -dLng / len;
  const perpLng = dLat / len;

  return {
    left: {
      lat: anchorLat + (perpLat * offsetMeters) / latPerDeg,
      lng: anchorLng + (perpLng * offsetMeters) / lngPerDeg,
    },
    right: {
      lat: anchorLat - (perpLat * offsetMeters) / latPerDeg,
      lng: anchorLng - (perpLng * offsetMeters) / lngPerDeg,
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

type EvaluatedAvoidRoute = {
  points: RoutePoint[];
  distance: number;
  duration: number;
  cameraIndices: number[];
};

export type AvoidRouteStepState = EvaluatedAvoidRoute;

const AVOID_ROUTE_MAX_WAYPOINTS = 1;
const AVOID_ROUTE_OFFSETS = [80, 120, 160, 200, 240, 280];
const AVOID_ROUTE_SIDES: Array<'left' | 'right'> = ['left', 'right'];

const AVOID_ROUTE_MAX_DISTANCE_RATIO = 1.18;
const AVOID_ROUTE_MAX_DISTANCE_RATIO_IF_BIG_IMPROVEMENT = 1.30;

function findNearestRoutePointIndex(points: RoutePoint[], lat: number, lng: number): number {
  let minDistance = Infinity;
  let nearestIdx = 0;

  for (let i = 0; i < points.length; i++) {
    const point = points[i];
    const distance = calculateDistance(point.lat, point.lng, lat, lng);
    if (distance < minDistance) {
      minDistance = distance;
      nearestIdx = i;
    }
  }

  return nearestIdx;
}

function pickBetterAvoidRoute(
  previousBest: AvoidRouteStepState | undefined,
  current: AvoidRouteStepState,
  anchorDistance: number
): AvoidRouteStepState {
  if (!previousBest) return current;

  const previousCount = previousBest.cameraIndices.length;
  const currentCount = current.cameraIndices.length;
  const distanceRatioToAnchor = current.distance / Math.max(anchorDistance, 1);

  if (currentCount < previousCount) {
    const reducedBy = previousCount - currentCount;

    // 以第一条基线路线为锚点做约束，避免逐轮相对比较导致漂移
    if (distanceRatioToAnchor <= AVOID_ROUTE_MAX_DISTANCE_RATIO) {
      return current;
    }

    // 仅当摄像头显著减少时，放宽一点里程上限
    if (
      reducedBy >= 2 &&
      distanceRatioToAnchor <= AVOID_ROUTE_MAX_DISTANCE_RATIO_IF_BIG_IMPROVEMENT
    ) {
      return current;
    }

    return previousBest;
  }

  if (
    currentCount === previousCount &&
    current.distance < previousBest.distance
  ) {
    return current;
  }

  return previousBest;
}

function buildAvoidWaypoints(
  best: AvoidRouteStepState,
  cameras: Camera[],
  iteration: number
): Coordinate[] {
  const camerasOnRoute = best.cameraIndices
    .map((idx) => cameras[idx])
    .filter((cam): cam is Camera => Boolean(cam))
    .map((cam) => ({
      cam,
      routeIdx: findNearestRoutePointIndex(best.points, cam.lat, cam.lng),
    }))
    // 关键：按路线先后顺序排列途径点，避免路径来回折返形成大回环
    .sort((a, b) => a.routeIdx - b.routeIdx)
    .slice(0, AVOID_ROUTE_MAX_WAYPOINTS)
    .map((item) => item.cam);

  const offset = AVOID_ROUTE_OFFSETS[iteration % AVOID_ROUTE_OFFSETS.length];
  const side = AVOID_ROUTE_SIDES[iteration % AVOID_ROUTE_SIDES.length];

  return camerasOnRoute.map((cam) => {
    const { left, right } = computePerpendicularOffsets(best.points, cam.lat, cam.lng, offset);
    return side === 'left' ? left : right;
  });
}

export async function planAvoidCamerasRouteStep(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[],
  iteration: number,
  best?: AvoidRouteStepState,
  anchorDistance?: number
): Promise<{ current: AvoidRouteStepState; best: AvoidRouteStepState; done: boolean; anchorDistance: number }> {
  const waypoints =
    best && best.cameraIndices.length > 0
      ? buildAvoidWaypoints(best, cameras, iteration)
      : undefined;

  const routes = await callTencentDrivingAPI(start, end, false, waypoints);
  if (routes.length === 0) {
    throw new Error('腾讯地图路线规划失败: 未返回可用路线');
  }

  const currentRoute = routes[0];
  const current: AvoidRouteStepState = {
    ...currentRoute,
    cameraIndices: findCamerasNearRoute(currentRoute.points, cameras),
  };

  const nextAnchorDistance = anchorDistance ?? current.distance;
  const nextBest = pickBetterAvoidRoute(best, current, nextAnchorDistance);

  return {
    current,
    best: nextBest,
    done: nextBest.cameraIndices.length === 0,
    anchorDistance: nextAnchorDistance,
  };
}

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
 *
 * 策略：逐步迭代，最多 15 次 API 调用
 *   1. 请求一条路线；
 *   2. 检查路线上是否有摄像头；
 *   3. 如果有，为路线上的摄像头生成绕行途径点，再请求一条新路线；
 *   4. 如此循环，每轮用不同偏移距离/方向，最多 15 次。
 */
export async function planAvoidCamerasRoute(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[]
): Promise<{ points: RoutePoint[]; cameraIndices: number[]; distance: number; duration: number }> {
  const MAX_ITERATIONS = 15;
  let best: AvoidRouteStepState | null = null;
  let anchorDistance: number | undefined;

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    try {
      const step = await planAvoidCamerasRouteStep(
        start,
        end,
        cameras,
        i,
        best ?? undefined,
        anchorDistance
      );
      best = step.best;
      anchorDistance = step.anchorDistance;
      console.log(
        `[route] iteration ${i + 1}: current=${step.current.cameraIndices.length}, best=${step.best.cameraIndices.length}`
      );
      if (step.done) break;
    } catch (err) {
      const message = String(err);
      if (message.includes('每秒请求量已达到上限')) {
        await new Promise((resolve) => setTimeout(resolve, 600));
        try {
          const retryStep = await planAvoidCamerasRouteStep(
            start,
            end,
            cameras,
            i,
            best ?? undefined,
            anchorDistance
          );
          best = retryStep.best;
          anchorDistance = retryStep.anchorDistance;
          console.log(
            `[route] iteration ${i + 1} retry: current=${retryStep.current.cameraIndices.length}, best=${retryStep.best.cameraIndices.length}`
          );
          if (retryStep.done) break;
          continue;
        } catch (retryErr) {
          console.warn(`[route] iteration ${i + 1} failed after retry:`, retryErr);
          break;
        }
      }
      console.warn(`[route] iteration ${i + 1} failed:`, err);
      break;
    }
  }

  if (!best) {
    const points = generateFallbackRoute(start, end);
    const distance = calculateDistance(start.lat, start.lng, end.lat, end.lng);
    best = {
      points,
      distance,
      duration: Math.round(distance / 13.33),
      cameraIndices: findCamerasNearRoute(points, cameras),
    };
  }

  console.log(`[route] final: ${best.cameraIndices.length} cameras`);
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

