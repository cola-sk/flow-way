import { Coordinate, Route, RoutePoint } from '@/types/route';
import { Camera } from '@/types/camera';
import { extractDirection } from './camera-parser';
import { CAMERA_DIRECTION_VECTORS, CameraDirection } from '@/types/camera-enhanced';
import { v4 as uuidv4 } from 'uuid';
import { signTencentUrl, getTencentMapKey } from './tencent-sign';

const MIN_TENCENT_REQUEST_INTERVAL_MS = 500;
let lastTencentRequestAt = 0;
const AVOID_ROUTE_MAX_TENCENT_API_CALLS = 80;
const AVOID_ROUTE_MAX_RATE_LIMIT_RETRIES = 6;
const ROUTE_PLANNING_ABORTED_ERROR = 'ROUTE_PLANNING_ABORTED';

export const AVOID_ALGORITHM_V1_0 = 'v1.0' as const;
export const AVOID_ALGORITHM_V1_0_BETA_1 = 'v1.0-beta.1' as const;
export const DEFAULT_AVOID_ALGORITHM_VERSION = AVOID_ALGORITHM_V1_0_BETA_1;
export type AvoidAlgorithmVersion =
  | typeof AVOID_ALGORITHM_V1_0
  | typeof AVOID_ALGORITHM_V1_0_BETA_1;

export function normalizeAvoidAlgorithmVersion(
  value: unknown
): AvoidAlgorithmVersion {
  if (value === AVOID_ALGORITHM_V1_0) {
    return AVOID_ALGORITHM_V1_0;
  }
  if (value === AVOID_ALGORITHM_V1_0_BETA_1) {
    return AVOID_ALGORITHM_V1_0_BETA_1;
  }
  return DEFAULT_AVOID_ALGORITHM_VERSION;
}

type TencentApiRequestContext = {
  usedCalls: number;
  maxCalls: number;
  rateLimitRetries: number;
  maxRateLimitRetries: number;
};

function createRoutePlanningAbortedError(): Error {
  const error = new Error(ROUTE_PLANNING_ABORTED_ERROR);
  error.name = 'AbortError';
  return error;
}

export function isRoutePlanningAbortedError(error: unknown): boolean {
  if (error instanceof Error) {
    if (error.name === 'AbortError') {
      return true;
    }
    return error.message.includes(ROUTE_PLANNING_ABORTED_ERROR);
  }
  return String(error).includes(ROUTE_PLANNING_ABORTED_ERROR);
}

function throwIfRoutePlanningAborted(signal?: AbortSignal): void {
  if (signal?.aborted) {
    throw createRoutePlanningAbortedError();
  }
}

async function delayWithAbort(ms: number, signal?: AbortSignal): Promise<void> {
  if (ms <= 0) return;

  if (!signal) {
    await new Promise((resolve) => setTimeout(resolve, ms));
    return;
  }

  throwIfRoutePlanningAborted(signal);

  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => {
      signal.removeEventListener('abort', onAbort);
      resolve();
    }, ms);

    const onAbort = () => {
      clearTimeout(timer);
      signal.removeEventListener('abort', onAbort);
      reject(createRoutePlanningAbortedError());
    };

    signal.addEventListener('abort', onAbort, { once: true });
  });
}

async function waitTencentRequestSlot(signal?: AbortSignal): Promise<void> {
  const elapsed = Date.now() - lastTencentRequestAt;
  if (elapsed < MIN_TENCENT_REQUEST_INTERVAL_MS) {
    await delayWithAbort(MIN_TENCENT_REQUEST_INTERVAL_MS - elapsed, signal);
  }
  throwIfRoutePlanningAborted(signal);
  lastTencentRequestAt = Date.now();
}

function createTencentApiRequestContext(): TencentApiRequestContext {
  return {
    usedCalls: 0,
    maxCalls: AVOID_ROUTE_MAX_TENCENT_API_CALLS,
    rateLimitRetries: 0,
    maxRateLimitRetries: AVOID_ROUTE_MAX_RATE_LIMIT_RETRIES,
  };
}

function consumeTencentApiQuota(context?: TencentApiRequestContext): void {
  if (!context) {
    return;
  }
  if (context.usedCalls >= context.maxCalls) {
    throw new Error(`腾讯地图路线规划达到最大尝试次数(${context.maxCalls})`);
  }
  context.usedCalls += 1;
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

function getCameraBearingsFromName(name: string): number[] | null {
  const bearings: number[] = [];
  if (name.includes('东西双向') || name.includes('东西方向') || name.includes('双向东西')) {
    bearings.push(CAMERA_DIRECTION_VECTORS[CameraDirection.EAST_WEST]);
    bearings.push(CAMERA_DIRECTION_VECTORS[CameraDirection.WEST_EAST]);
  } else if (name.includes('南北双向') || name.includes('南北方向') || name.includes('双向南北')) {
    bearings.push(CAMERA_DIRECTION_VECTORS[CameraDirection.SOUTH_NORTH]);
    bearings.push(CAMERA_DIRECTION_VECTORS[CameraDirection.NORTH_SOUTH]);
  }
  if (bearings.length > 0) return bearings;

  const direction = extractDirection(name);
  if (direction === CameraDirection.UNKNOWN) return null;
  const bearing = CAMERA_DIRECTION_VECTORS[direction];
  if (typeof bearing === 'number' && bearing >= 0) {
    return [bearing];
  }
  return null;
}

/**
 * 检查摄像头是否在路线附近（距离阈值：100 米）
 * 且路线通过方向与摄像头拍摄方向一致（方向未知时保守计入）
 */
function distanceToSegment(pLat: number, pLng: number, aLat: number, aLng: number, bLat: number, bLng: number): number {
  const R = 6371000;
  
  // Convert inputs to radians
  const lat1 = (aLat * Math.PI) / 180;
  const lng1 = (aLng * Math.PI) / 180;
  const lat2 = (bLat * Math.PI) / 180;
  const lng2 = (bLng * Math.PI) / 180;
  const lat3 = (pLat * Math.PI) / 180;
  const lng3 = (pLng * Math.PI) / 180;

  // Haversine formula for distance between points
  const dLat_ab = lat2 - lat1;
  const dLng_ab = lng2 - lng1;
  
  if (dLat_ab === 0 && dLng_ab === 0) {
    return calculateDistance(pLat, pLng, aLat, aLng);
  }

  // Equirectangular approximation for small distances
  const x = (lng2 - lng1) * Math.cos((lat1 + lat2) / 2);
  const y = lat2 - lat1;
  const len2 = x * x + y * y;

  const dx_pa = (lng3 - lng1) * Math.cos((lat1 + lat3) / 2);
  const dy_pa = lat3 - lat1;

  // Projection of p-a onto b-a
  let t = (dx_pa * x + dy_pa * y) / len2;
  t = Math.max(0, Math.min(1, t));

  const projLng = aLng + t * (bLng - aLng);
  const projLat = aLat + t * (bLat - aLat);

  return calculateDistance(pLat, pLng, projLat, projLng);
}

export function findCamerasNearRoute(
  polylinePoints: RoutePoint[],
  cameras: Camera[],
  threshold: number = 40
): number[] {
  const cameraIndices: number[] = [];
  const DIRECTION_TOLERANCE_DEG = 50;

  if (polylinePoints.length === 0) return cameraIndices;

  cameras.forEach((camera, index) => {
    if (camera.type === 4) return;

    let minDistance = Infinity;
    let matchingSegIdx = 0;
    
    // Check distance to all segments instead of just vertices
    for (let i = 0; i < polylinePoints.length - 1; i++) {
        const p1 = polylinePoints[i];
        const p2 = polylinePoints[i+1];
        const dist = distanceToSegment(camera.lat, camera.lng, p1.lat, p1.lng, p2.lat, p2.lng);
        if (dist < minDistance) {
            minDistance = dist;
            matchingSegIdx = i;
        }
    }
    
    // Also check the very last point
    const lastPointDist = calculateDistance(
      camera.lat, camera.lng,
      polylinePoints[polylinePoints.length-1].lat, polylinePoints[polylinePoints.length-1].lng
    );
    if (lastPointDist < minDistance) {
      minDistance = lastPointDist;
      matchingSegIdx = Math.max(0, polylinePoints.length - 2);
    }

    if (minDistance >= threshold) return;

    const cameraBearings = getCameraBearingsFromName(camera.name);
    if (cameraBearings === null) {
      cameraIndices.push(index);
      return;
    }

    const routeBearing = getRouteBearingNearIndex(polylinePoints, matchingSegIdx);
    if (routeBearing === null) {
      cameraIndices.push(index);
      return;
    }

    const isMatched = cameraBearings.some(cb => angleGapDeg(routeBearing, cb) <= DIRECTION_TOLERANCE_DEG);
    if (isMatched) {
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
  waypoints?: Coordinate[],
  avoidPolygons?: string[],
  requestContext?: TencentApiRequestContext,
  signal?: AbortSignal
): Promise<Array<{ points: RoutePoint[]; distance: number; duration: number }>> {
  if (!getTencentMapKey()) {
    throw new Error('未配置 TENCENT_MAP_KEY 环境变量');
  }

  throwIfRoutePlanningAborted(signal);

  const baseUrl = new URL('https://apis.map.qq.com/ws/direction/v1/driving/');
  baseUrl.searchParams.set('from', `${start.lat},${start.lng}`);
  baseUrl.searchParams.set('to', `${end.lat},${end.lng}`);
  if (alternatives) baseUrl.searchParams.set('alternatives', '1');
  if (waypoints && waypoints.length > 0) {
    baseUrl.searchParams.set('waypoints', waypoints.map((w) => `${w.lat},${w.lng}`).join(';'));
  }
  if (avoidPolygons && avoidPolygons.length > 0) {
    baseUrl.searchParams.set('avoid_polygons', avoidPolygons.join('|'));
  }

  consumeTencentApiQuota(requestContext);
  await waitTencentRequestSlot(signal);
  throwIfRoutePlanningAborted(signal);
  const url = signTencentUrl(baseUrl);
  const res = await fetch(url, { signal });
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
const AVOID_ROUTE_OFFSETS = [100, 200, 300];
const AVOID_ROUTE_SIDES: Array<'left' | 'right'> = ['left', 'right'];
const AVOID_ROUTE_GUIDED_HELPER_ATTEMPTS = 8;
const AVOID_ROUTE_GUIDED_HELPER_OFFSETS = [180, 280, 380];
const AVOID_ROUTE_SPLIT_HELPER_OFFSETS = [900, 1400];

const AVOID_ROUTE_MAX_DISTANCE_RATIO = 1.18;
const AVOID_ROUTE_MAX_DISTANCE_RATIO_IF_BIG_IMPROVEMENT = 1.30;

type AvoidRouteEvaluation = {
  points: RoutePoint[];
  cameraIndices: number[];
  distance: number;
  duration: number;
};

function pickBestRouteFromCandidates(
  routes: Array<{ points: RoutePoint[]; distance: number; duration: number }>,
  cameras: Camera[]
): AvoidRouteEvaluation | null {
  let best: AvoidRouteEvaluation | null = null;

  for (const r of routes) {
    const evaluated: AvoidRouteEvaluation = {
      ...r,
      cameraIndices: findCamerasNearRoute(r.points, cameras),
    };

    if (
      !best ||
      evaluated.cameraIndices.length < best.cameraIndices.length ||
      (evaluated.cameraIndices.length === best.cameraIndices.length && evaluated.distance < best.distance)
    ) {
      best = evaluated;
    }
  }

  return best;
}

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
  const allCamerasOnRoute = best.cameraIndices
    .map((idx) => cameras[idx])
    .filter((cam): cam is Camera => Boolean(cam))
    .map((cam) => ({
      cam,
      routeIdx: findNearestRoutePointIndex(best.points, cam.lat, cam.lng),
    }))
    // 按路线先后顺序排列途径点，避免路径来回折返形成大回环
    .sort((a, b) => a.routeIdx - b.routeIdx);

  const combinationsPerCamera = AVOID_ROUTE_OFFSETS.length * AVOID_ROUTE_SIDES.length;
  const cameraFocusIndex = Math.floor(iteration / combinationsPerCamera);
  const startIndex = cameraFocusIndex % Math.max(1, allCamerasOnRoute.length);

  const camerasOnRoute = allCamerasOnRoute
    .slice(startIndex, startIndex + AVOID_ROUTE_MAX_WAYPOINTS)
    .map((item) => item.cam);

  const offset = AVOID_ROUTE_OFFSETS[iteration % AVOID_ROUTE_OFFSETS.length];
  const sideRound = Math.floor(iteration / AVOID_ROUTE_OFFSETS.length);
  const side = AVOID_ROUTE_SIDES[sideRound % AVOID_ROUTE_SIDES.length];

  return camerasOnRoute.map((cam) => {
    const { left, right } = computePerpendicularOffsets(best.points, cam.lat, cam.lng, offset);
    return side === 'left' ? left : right;
  });
}

function buildAvoidPolygonsByCameraIndices(
  cameraIndices: Iterable<number>,
  cameras: Camera[],
  radius: number
): string[] {
  return Array.from(cameraIndices)
    .slice(0, 32)
    .map((idx) => {
      const cam = cameras[idx];
      return `${cam.lat - radius},${cam.lng - radius};${cam.lat + radius},${cam.lng - radius};${cam.lat + radius},${cam.lng + radius};${cam.lat - radius},${cam.lng + radius}`;
    });
}

function buildGuidedHelperWaypoint(
  route: AvoidRouteEvaluation,
  cameras: Camera[],
  attempt: number
): { waypoint: Coordinate; focusCameraIndex: number } | null {
  const camerasOnRoute = route.cameraIndices
    .map((cameraIndex) => {
      const cam = cameras[cameraIndex];
      if (!cam) return null;
      return {
        cameraIndex,
        cam,
        routeIdx: findNearestRoutePointIndex(route.points, cam.lat, cam.lng),
      };
    })
    .filter(
      (item): item is { cameraIndex: number; cam: Camera; routeIdx: number } => Boolean(item)
    )
    .sort((a, b) => a.routeIdx - b.routeIdx);

  if (camerasOnRoute.length === 0) {
    return null;
  }

  const focusIdx = attempt % camerasOnRoute.length;
  const focus = camerasOnRoute[focusIdx];
  const offset =
    AVOID_ROUTE_GUIDED_HELPER_OFFSETS[
      Math.floor(attempt / camerasOnRoute.length) % AVOID_ROUTE_GUIDED_HELPER_OFFSETS.length
    ];
  const side: 'left' | 'right' =
    Math.floor(attempt / (camerasOnRoute.length * AVOID_ROUTE_GUIDED_HELPER_OFFSETS.length)) % 2 === 0
      ? 'left'
      : 'right';

  const { left, right } = computePerpendicularOffsets(route.points, focus.cam.lat, focus.cam.lng, offset);
  return {
    waypoint: side === 'left' ? left : right,
    focusCameraIndex: focus.cameraIndex,
  };
}

async function tryGuidedHelperRoute(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[],
  baseAvoidCameraIds: Set<number>,
  currentBest: AvoidRouteEvaluation,
  attempt: number,
  polygonRadius: number,
  requestContext?: TencentApiRequestContext,
  signal?: AbortSignal
): Promise<AvoidRouteEvaluation | null> {
  throwIfRoutePlanningAborted(signal);

  const helper = buildGuidedHelperWaypoint(currentBest, cameras, attempt);
  if (!helper) {
    return null;
  }

  const helperAvoid = new Set(baseAvoidCameraIds);
  helperAvoid.add(helper.focusCameraIndex);
  const avoidPolygons = buildAvoidPolygonsByCameraIndices(helperAvoid, cameras, polygonRadius);

  let routes: Array<{ points: RoutePoint[]; distance: number; duration: number }> = [];
  try {
    routes = await callTencentDrivingAPI(
      start,
      end,
      true,
      [helper.waypoint],
      avoidPolygons,
      requestContext,
      signal
    );
    if (requestContext) {
      requestContext.rateLimitRetries = 0;
    }
  } catch (err) {
    if (isRoutePlanningAbortedError(err)) {
      throw err;
    }

    const msg = String(err);
    if (msg.includes('每秒请求量')) {
      if (requestContext) {
        requestContext.rateLimitRetries += 1;
        if (requestContext.rateLimitRetries > requestContext.maxRateLimitRetries) {
          console.warn(
            `[route] guided helper stopped: rate-limit retries exceeded (${requestContext.maxRateLimitRetries})`
          );
          return null;
        }
      }
      await delayWithAbort(600, signal);
      try {
        routes = await callTencentDrivingAPI(
          start,
          end,
          true,
          [helper.waypoint],
          avoidPolygons,
          requestContext,
          signal
        );
        if (requestContext) {
          requestContext.rateLimitRetries = 0;
        }
      } catch (retryErr) {
        if (isRoutePlanningAbortedError(retryErr)) {
          throw retryErr;
        }
        console.warn('[route] guided helper retry failed:', retryErr);
        return null;
      }
    } else {
      console.warn('[route] guided helper request failed:', err);
      return null;
    }
  }

  let best: AvoidRouteEvaluation | null = null;
  for (const r of routes) {
    const evaluated: AvoidRouteEvaluation = {
      ...r,
      cameraIndices: findCamerasNearRoute(r.points, cameras),
    };
    if (
      !best ||
      evaluated.cameraIndices.length < best.cameraIndices.length ||
      (evaluated.cameraIndices.length === best.cameraIndices.length && evaluated.distance < best.distance)
    ) {
      best = evaluated;
    }
  }

  if (best) {
    console.log(
      `[route] guided helper attempt ${attempt + 1}: hit ${best.cameraIndices.length}, distance ${best.distance}`
    );
  }

  return best;
}

function buildSplitHelperWaypoints(
  route: AvoidRouteEvaluation,
  cameras: Camera[]
): Coordinate[] {
  if (route.points.length < 2) {
    return [];
  }

  let focusRouteIdx = Math.floor(route.points.length / 2);
  if (route.cameraIndices.length > 0) {
    const routeIndices = route.cameraIndices
      .map((cameraIndex) => {
        const cam = cameras[cameraIndex];
        if (!cam) return null;
        return findNearestRoutePointIndex(route.points, cam.lat, cam.lng);
      })
      .filter((idx): idx is number => typeof idx === 'number')
      .sort((a, b) => a - b);

    if (routeIndices.length > 0) {
      focusRouteIdx = routeIndices[Math.floor(routeIndices.length / 2)];
    }
  }

  const anchor = route.points[focusRouteIdx] ?? route.points[Math.floor(route.points.length / 2)];
  if (!anchor) {
    return [];
  }

  const helpers: Coordinate[] = [];
  for (const offset of AVOID_ROUTE_SPLIT_HELPER_OFFSETS) {
    const { left, right } = computePerpendicularOffsets(route.points, anchor.lat, anchor.lng, offset);
    helpers.push(left, right);
  }
  return helpers;
}

function mergeSplitLegRoutes(
  firstLeg: AvoidRouteEvaluation,
  secondLeg: AvoidRouteEvaluation
): AvoidRouteEvaluation {
  const mergedPoints: RoutePoint[] = [...firstLeg.points];

  if (secondLeg.points.length > 0) {
    const secondPoints = [...secondLeg.points];
    const tail = mergedPoints[mergedPoints.length - 1];
    const head = secondPoints[0];
    if (tail && head && calculateDistance(tail.lat, tail.lng, head.lat, head.lng) < 8) {
      secondPoints.shift();
    }
    mergedPoints.push(...secondPoints);
  }

  const cameraIndexSet = new Set<number>([
    ...firstLeg.cameraIndices,
    ...secondLeg.cameraIndices,
  ]);

  return {
    points: mergedPoints,
    cameraIndices: Array.from(cameraIndexSet),
    distance: firstLeg.distance + secondLeg.distance,
    duration: firstLeg.duration + secondLeg.duration,
  };
}

export async function planAvoidCamerasRouteStep(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[],
  iteration: number,
  best?: AvoidRouteStepState,
  anchorDistance?: number,
  signal?: AbortSignal
): Promise<{ current: AvoidRouteStepState; best: AvoidRouteStepState; done: boolean; anchorDistance: number }> {
  throwIfRoutePlanningAborted(signal);

  const waypoints =
    best && best.cameraIndices.length > 0
      ? buildAvoidWaypoints(best, cameras, iteration)
      : undefined;

  const routes = await callTencentDrivingAPI(start, end, true, waypoints, undefined, undefined, signal); // true for alternatives
  if (routes.length === 0) {
    throw new Error('腾讯地图路线规划失败: 未返回可用路线');
  }

  const nextAnchorDistance = anchorDistance ?? routes[0].distance;
  
  let currentBest: AvoidRouteStepState | null = null;
  let overallBest: AvoidRouteStepState | undefined = best;

  for (const r of routes) {
    const state: AvoidRouteStepState = {
      ...r,
      cameraIndices: findCamerasNearRoute(r.points, cameras),
    };
    
    if (!currentBest || state.cameraIndices.length < currentBest.cameraIndices.length || 
        (state.cameraIndices.length === currentBest.cameraIndices.length && state.distance < currentBest.distance)) {
      currentBest = state;
    }
    
    overallBest = pickBetterAvoidRoute(overallBest, state, nextAnchorDistance);
  }

  return {
    current: currentBest!,
    best: overallBest!,
    done: overallBest!.cameraIndices.length === 0,
    anchorDistance: nextAnchorDistance,
  };
}

/**
 * 规划普通路线（腾讯地图真实路网，API 不可用时回退直线）
 */
export async function planRoute(
  start: Coordinate,
  end: Coordinate,
  signal?: AbortSignal
): Promise<{ points: RoutePoint[]; distance: number; duration: number }> {
  try {
    const routes = await callTencentDrivingAPI(start, end, false, undefined, undefined, undefined, signal);
    return routes[0];
  } catch (err) {
    if (isRoutePlanningAbortedError(err)) {
      throw err;
    }
    console.warn('腾讯路线规划失败，回退到直线:', err);
    const points = generateFallbackRoute(start, end);
    const distance = calculateDistance(start.lat, start.lng, end.lat, end.lng);
    return { points, distance, duration: Math.round(distance / 13.33) };
  }
}

/**
 * 规划避开摄像头路线
 *
 * 策略：调用腾讯地图核心 avoid_polygons 原生避让属性，结合随机退火抖动（多次尝试）
 *   1. 请求带 alternatives 的路线；
 *   2. 检查路线上是否有摄像头，有则转化为约 35x35 米多边形；
 *   3. 前期贪心加入所有雷区；
 *   4. 如果陷入局部最优（连续两次无法改善），则随机解除部分多边形限制，进行更多路径抖动尝试，总计不超过 20 次。
 */
export async function planAvoidCamerasRoute(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[],
  splitAssistDepth = 0,
  requestContext?: TencentApiRequestContext,
  signal?: AbortSignal
): Promise<{ points: RoutePoint[]; cameraIndices: number[]; distance: number; duration: number }> {
  throwIfRoutePlanningAborted(signal);

  void splitAssistDepth;
  const context = requestContext ?? createTencentApiRequestContext();
  const MAX_ITERATIONS = 20;
  let bestGlobalRoute: AvoidRouteEvaluation | null = null;
  let bestGlobalHits = 999999;
  let bestGlobalDist = Infinity;
  let currentAvoidCamIds = new Set<number>();
  
  // 约 35 米的微型避让区半径 (0.00035度)
  const POLYGON_RADIUS = 0.00035; 
  let noImprovementCount = 0;

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    throwIfRoutePlanningAborted(signal);

    try {
      const avoidPolygons = buildAvoidPolygonsByCameraIndices(
        currentAvoidCamIds,
        cameras,
        POLYGON_RADIUS
      );

      const routes = await callTencentDrivingAPI(
        start,
        end,
        true,
        undefined,
        avoidPolygons,
        context,
        signal
      );
      context.rateLimitRetries = 0;
      if (routes.length === 0) {
        throw new Error('腾讯地图路线规划失败: 未返回可用路线');
      }

      let bestHitsInIter = 999999;
      let bestDistInIter = Infinity;
      let newCamIdsThisIter: number[] = [];
      let bestRouteInIter: { points: RoutePoint[]; cameraIndices: number[]; distance: number; duration: number } | null = null;

      for (const r of routes) {
        const hitCams = findCamerasNearRoute(r.points, cameras);
        if (hitCams.length < bestHitsInIter || (hitCams.length === bestHitsInIter && r.distance < bestDistInIter)) {
          bestHitsInIter = hitCams.length;
          bestDistInIter = r.distance;
          newCamIdsThisIter = hitCams;
          bestRouteInIter = { ...r, cameraIndices: hitCams };
        }
      }

      if (!bestRouteInIter) break;

      let improvedThisRound = false;

      // 如果能在里程不失控的情况下找到更少摄像头的路，就全局接纳它
      // 放宽绕路限制：最多允许绕行 2.0 倍的距离
      if (bestGlobalDist === Infinity || (bestDistInIter <= bestGlobalDist * 2.0)) {
          if (bestHitsInIter < bestGlobalHits || (bestHitsInIter === bestGlobalHits && bestDistInIter < bestGlobalDist)) {
              bestGlobalHits = bestHitsInIter;
              bestGlobalDist = bestDistInIter;
              bestGlobalRoute = bestRouteInIter;
              improvedThisRound = true;
          }
      }

      if (improvedThisRound) {
        noImprovementCount = 0;
      } else {
        noImprovementCount++;
      }

      console.log(`[route] iteration ${i + 1}: hit ${bestHitsInIter} cameras. Distance ${bestDistInIter}. Best Global: ${bestGlobalHits}`);

      if (bestHitsInIter === 0) {
        break; // 0摄像头，直接收工
      }

      // 贪婪添加策略 OR 抖动策略
      if (noImprovementCount < 2) {
        // 贪婪把本次路上的摄像头全部拉黑
        let added = false;
        for (const camIdx of newCamIdsThisIter) {
          if (!currentAvoidCamIds.has(camIdx) && currentAvoidCamIds.size < 32) {
            currentAvoidCamIds.add(camIdx);
            added = true;
          }
        }
        if (!added && noImprovementCount === 0) {
          noImprovementCount = 2; // 虽然有 improved，但没能产生新雷区(死胡同)，强制进入抖动
        }
      } else {
        // 陷入局部最优（死胡同），启动"退火/抖动"：随机丢弃几个已拉黑的摄像头放行（可能是必经之路的桥之类），并把最佳路线里剩下的摄像头随机挑 1~2 个封锁
        console.log(`[route] Local minimum detected, applying perturbation...`);

        // 1. 从当前黑名单中随机宽恕（移除）1~3 个摄像头
        const currentArr = Array.from(currentAvoidCamIds);
        if (currentArr.length > 0) {
          const numToRemove = Math.floor(Math.random() * 3) + 1;
          for (let j = 0; j < numToRemove; j++) {
            if (currentArr.length === 0) break;
            const removeIdx = Math.floor(Math.random() * currentArr.length);
            currentAvoidCamIds.delete(currentArr[removeIdx]);
            currentArr.splice(removeIdx, 1);
          }
        }

        // 2. 将全局最优路线中的目前存留的摄像头，随机挑 1 个加进黑名单进行专点打击
        if (bestGlobalRoute?.cameraIndices.length) {
          const bestCams = bestGlobalRoute.cameraIndices;
          const targetCamIdx = bestCams[Math.floor(Math.random() * bestCams.length)];
          currentAvoidCamIds.add(targetCamIdx);
        }

        noImprovementCount = 0; // 重置计数器，给本次抖动 2 轮机会
      }

    } catch (err) {
      if (isRoutePlanningAbortedError(err)) {
        throw err;
      }

      const message = String(err);
      if (message.includes('每秒请求量')) {
        context.rateLimitRetries += 1;
        if (context.rateLimitRetries > context.maxRateLimitRetries) {
          console.warn(
            `[route] stop retries on rate-limit: exceeded ${context.maxRateLimitRetries}`
          );
          break;
        }
        await delayWithAbort(600, signal);
        i--; // 重试
        continue;
      }
      console.warn(`[route] iteration ${i + 1} failed:`, err);
      break;
    }
  }

  if (!bestGlobalRoute) {
    throwIfRoutePlanningAborted(signal);
    const points = generateFallbackRoute(start, end);
    const distance = calculateDistance(start.lat, start.lng, end.lat, end.lng);
    bestGlobalRoute = {
      points,
      distance,
      duration: Math.round(distance / 13.33),
      cameraIndices: findCamerasNearRoute(points, cameras),
    };
  }

  throwIfRoutePlanningAborted(signal);
  console.log(`[route] final: ${bestGlobalRoute.cameraIndices.length} cameras`);
  return bestGlobalRoute;
}

export async function planAvoidCamerasRouteByVersion(
  start: Coordinate,
  end: Coordinate,
  cameras: Camera[],
  algorithmVersion: AvoidAlgorithmVersion,
  splitAssistDepth = 0,
  requestContext?: TencentApiRequestContext,
  signal?: AbortSignal
): Promise<{ points: RoutePoint[]; cameraIndices: number[]; distance: number; duration: number }> {
  switch (algorithmVersion) {
    case AVOID_ALGORITHM_V1_0:
    case AVOID_ALGORITHM_V1_0_BETA_1:
    default:
      return planAvoidCamerasRoute(start, end, cameras, splitAssistDepth, requestContext, signal);
  }
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
  durationSeconds?: number,
  avoidAlgorithmVersion?: AvoidAlgorithmVersion
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
    avoidAlgorithmVersion,
    createdAt: new Date().toISOString(),
  };
}

