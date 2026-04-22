/**
 * 简化的摄像头检测算法
 * 核心逻辑：只判断路线向量是否在摄像头的拍摄范围内
 */

import { CameraDirection, CAMERA_DIRECTION_VECTORS } from '@/types/camera-enhanced';

/**
 * 计算两点间的方向角（0-360度）
 * 0 = 北, 90 = 东, 180 = 南, 270 = 西
 */
export function calculateBearing(
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number
): number {
  const dLng = toLng - fromLng;
  const y = Math.sin((dLng * Math.PI) / 180) * Math.cos((toLat * Math.PI) / 180);
  const x =
    Math.cos((fromLat * Math.PI) / 180) * Math.sin((toLat * Math.PI) / 180) -
    Math.sin((fromLat * Math.PI) / 180) * Math.cos((toLat * Math.PI) / 180) * Math.cos((dLng * Math.PI) / 180);
  const bearing = (Math.atan2(y, x) * 180) / Math.PI;
  return (bearing + 360) % 360;
}

/**
 * 计算两个方向的最小夹角（0-180度）
 */
function minAngleBetween(bearing1: number, bearing2: number): number {
  let diff = Math.abs(bearing1 - bearing2);
  return diff > 180 ? 360 - diff : diff;
}

/**
 * 判断路线是否会被摄像头拍到
 * 
 * 核心算法：
 * 1. 获取路线的方向向量
 * 2. 获取摄像头的拍摄方向
 * 3. 计算两个方向的夹角
 * 4. 如果夹角在容差范围内，说明会被拍到
 * 
 * @param routeBearing 路线的方向角 (0-360)
 * @param cameraBearing 摄像头的拍摄方向角 (0-360)
 * @param detectionAngle 拍摄容差角度，默认90度
 * @returns true 表示会被拍到，false 表示不会被拍到
 */
export function isDetectedByCamera(
  routeBearing: number,
  cameraBearing: number,
  detectionAngle: number = 90
): boolean {
  // 如果摄像头方向是-1（未知），保守起见认为会被拍到
  if (cameraBearing === -1) {
    return true;
  }

  // 计算最小夹角
  const angle = minAngleBetween(routeBearing, cameraBearing);

  // 如果夹角小于等于容差，说明在拍摄范围内
  return angle <= detectionAngle;
}

/**
 * 简化版：直接判断路线是否会被特定摄像头拍到
 * 
 * @param routeStart 路线起点 {lat, lng}
 * @param routeEnd 路线终点 {lat, lng}
 * @param cameraLat 摄像头纬度（此参数仅用于验证接近，不影响方向判断）
 * @param cameraLng 摄像头经度（此参数仅用于验证接近，不影响方向判断）
 * @param cameraDirection 摄像头的拍摄方向枚举
 * @param detectionAngle 拍摄容差角度，默认90度
 * @returns true 表示会被拍到，false 表示不会被拍到
 */
export function willBeDetected(
  routeStart: { lat: number; lng: number },
  routeEnd: { lat: number; lng: number },
  cameraLat: number,
  cameraLng: number,
  cameraDirection: CameraDirection,
  detectionAngle: number = 90
): boolean {
  // 计算路线的方向向量
  const routeBearing = calculateBearing(
    routeStart.lat,
    routeStart.lng,
    routeEnd.lat,
    routeEnd.lng
  );

  // 获取摄像头的拍摄方向角度
  const cameraBearing = CAMERA_DIRECTION_VECTORS[cameraDirection];

  // 核心判断：路线方向是否在摄像头的拍摄范围内
  return isDetectedByCamera(routeBearing, cameraBearing, detectionAngle);
}

/**
 * 路线段检测
 * 对于长路线，可能会有多个方向变化，需要分段检测
 * 
 * @param routePolyline 路线的所有点 [{lat, lng}, ...]
 * @param cameraLat 摄像头纬度
 * @param cameraLng 摄像头经度
 * @param cameraDirection 摄像头拍摄方向
 * @param distanceThreshold 距离阈值（米），只检测这个范围内的路线段
 * @returns true 表示至少有一段会被拍到，false 表示都不会被拍到
 */
export function isRouteDetected(
  routePolyline: Array<{ lat: number; lng: number }>,
  cameraLat: number,
  cameraLng: number,
  cameraDirection: CameraDirection,
  distanceThreshold: number = 100
): boolean {
  // 如果方向未知，保守起见认为会被拍到
  if (cameraDirection === 'unknown') {
    return true;
  }

  const cameraBearing = CAMERA_DIRECTION_VECTORS[cameraDirection];
  if (cameraBearing === -1) {
    return true;
  }

  // 逐段检查路线
  for (let i = 0; i < routePolyline.length - 1; i++) {
    const segmentStart = routePolyline[i];
    const segmentEnd = routePolyline[i + 1];

    // 快速距离检查：只检查接近摄像头的路线段
    const distToStart = calculateDistance(
      segmentStart.lat,
      segmentStart.lng,
      cameraLat,
      cameraLng
    );
    const distToEnd = calculateDistance(
      segmentEnd.lat,
      segmentEnd.lng,
      cameraLat,
      cameraLng
    );

    // 如果这一段足够接近摄像头
    if (distToStart <= distanceThreshold || distToEnd <= distanceThreshold) {
      // 计算这一段的方向向量
      const segmentBearing = calculateBearing(
        segmentStart.lat,
        segmentStart.lng,
        segmentEnd.lat,
        segmentEnd.lng
      );

      // 判断方向是否匹配 (使用更严格的45度容差，避免垂直或大角度交叉的误判)
      if (isDetectedByCamera(segmentBearing, cameraBearing, 45)) {
        // 判断摄像头是否真的在路线上，而非仅仅在路口附近但实际上未经过
        if (checkCameraOnSegment(
          segmentStart.lat, segmentStart.lng,
          segmentEnd.lat, segmentEnd.lng,
          cameraLat, cameraLng
        )) {
          return true; // 只要有一段会被拍到，就返回 true
        }
      }
    }
  }

  return false; // 所有接近的路线段都不会被拍到
}

/**
 * 高级检查：判断摄像头是否确实在路段的行进轨迹上
 * 通过计算相机的投影点，判断投影点是否在路段上（或非常接近），且相机到路段的垂直距离较小
 */
export function checkCameraOnSegment(
  latA: number, lngA: number,
  latB: number, lngB: number,
  latC: number, lngC: number,
  maxCrossTrackDist: number = 40,
  maxLongitudinalDist: number = 5
): boolean {
  // 将经纬度近似转换为局部平面坐标（单位：米），以A点为原点
  const R = 6371000;
  const latRad = latA * Math.PI / 180;
  const mPerLat = (Math.PI / 180) * R;
  const mPerLng = (Math.PI / 180) * R * Math.cos(latRad);

  const xB = (lngB - lngA) * mPerLng;
  const yB = (latB - latA) * mPerLat;
  const xC = (lngC - lngA) * mPerLng;
  const yC = (latC - latA) * mPerLat;

  const dot = xC * xB + yC * yB;
  const lenSq = xB * xB + yB * yB;
  
  let t = -1;
  if (lenSq !== 0) {
    t = dot / lenSq;
  }

  // 垂直距离（即路宽误差和定位误差）
  let projX = t * xB;
  let projY = t * yB;
  if (lenSq === 0) {
    projX = 0;
    projY = 0;
  }
  const crossTrackDist = Math.sqrt(Math.pow(xC - projX, 2) + Math.pow(yC - projY, 2));

  if (crossTrackDist > maxCrossTrackDist) {
    return false;
  }

  // 计算沿路段方向在起点前或终点后的距离
  const len = Math.sqrt(lenSq);
  let longitudinalDistOutside = 0;
  if (t < 0) {
    longitudinalDistOutside = -t * len;
  } else if (t > 1) {
    longitudinalDistOutside = (t - 1) * len;
  }

  return longitudinalDistOutside <= maxLongitudinalDist;
}

/**
 * 计算两点间距离（哈弗赛因公式）
 */
function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000; // 地球半径（米）
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

/**
 * 示例用法
 */
export function demonstrateDetection() {
  // 摄像头在(39.9, 116.4)，拍摄方向是"东向西"
  const cameraLat = 39.9;
  const cameraLng = 116.4;
  const cameraDirection = 'east_west' as CameraDirection; // 270度（西方向）

  // 路线1：从西边来，往东边去 (heading 东 ≈ 90度)
  const route1Start = { lat: 39.9, lng: 116.3 };
  const route1End = { lat: 39.9, lng: 116.5 };
  const detected1 = willBeDetected(route1Start, route1End, cameraLat, cameraLng, cameraDirection);
  console.log(`路线1（西→东）是否被拍到: ${detected1}`); // false (夹角太大)

  // 路线2：从东边来，往西边去 (heading 西 ≈ 270度)
  const route2Start = { lat: 39.9, lng: 116.5 };
  const route2End = { lat: 39.9, lng: 116.3 };
  const detected2 = willBeDetected(route2Start, route2End, cameraLat, cameraLng, cameraDirection);
  console.log(`路线2（东→西）是否被拍到: ${detected2}`); // true (方向匹配)

  // 路线3：从南边来，往北边去 (heading 北 ≈ 0度)
  const route3Start = { lat: 39.8, lng: 116.4 };
  const route3End = { lat: 40.0, lng: 116.4 };
  const detected3 = willBeDetected(route3Start, route3End, cameraLat, cameraLng, cameraDirection);
  console.log(`路线3（南→北）是否被拍到: ${detected3}`); // false (垂直方向)
}
