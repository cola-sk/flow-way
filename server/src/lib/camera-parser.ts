import {
  CameraDirection,
  CameraStatus,
  EnhancedCamera,
  CameraType,
  VectorDirection,
  CAMERA_DIRECTION_VECTORS,
} from '@/types/camera-enhanced';

/**
 * 从摄像头名称中提取方向信息
 */
export function extractDirection(name: string): CameraDirection {
  const directionMap: [string, CameraDirection][] = [
    ['东向西', CameraDirection.EAST_WEST],
    ['西向东', CameraDirection.WEST_EAST],
    ['南向北', CameraDirection.SOUTH_NORTH],
    ['北向南', CameraDirection.NORTH_SOUTH],
    ['向东', CameraDirection.EAST],
    ['向西', CameraDirection.WEST],
    ['向南', CameraDirection.SOUTH],
    ['向北', CameraDirection.NORTH],
  ];

  for (const [keyword, direction] of directionMap) {
    if (name.includes(keyword)) {
      return direction;
    }
  }

  return CameraDirection.UNKNOWN;
}

/**
 * 从摄像头名称中提取状态标识
 */
export function extractStatus(name: string): CameraStatus {
  return {
    isPilot: name.includes('试用期'),
    isLocationUnconfirmed: name.includes('位置待确认'),
    isPeakHourOnly: name.includes('高峰期'),
    isOutsideSixthRing: name.includes('六环外'),
    otherFlags: extractOtherFlags(name),
  };
}

/**
 * 提取其他特殊标识
 */
function extractOtherFlags(name: string): string[] {
  const flags: string[] = [];
  const patterns = [
    { regex: /【([^】]*)】/g, name: 'bracket' },
    { regex: /（([^）]*)）/g, name: 'paren' },
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.regex.exec(name)) !== null) {
      const flag = match[1];
      if (
        !flag.includes('试用期') &&
        !flag.includes('位置待确认') &&
        !flag.includes('高峰期') &&
        !flag.includes('六环外')
      ) {
        flags.push(flag);
      }
    }
  }

  return flags;
}

/**
 * 从摄像头名称中提取位置信息
 */
export function extractLocationInfo(name: string): {
  district?: string;
  location?: string;
  road?: string;
} {
  // 提取区名称（通常在最前面）
  const districtMatch = name.match(/^(.*?区)/);
  const district = districtMatch ? districtMatch[1] : undefined;

  // 提取具体位置描述（区名称之后到方向信息前）
  let location: string | undefined;
  if (district) {
    const afterDistrict = name.substring(district.length).trim();
    // 去掉方向信息和括号内容
    location = afterDistrict
      .replace(/[东西南北]向[东西南北]/g, '')
      .replace(/向[东西南北]/g, '')
      .replace(/【([^】]*)】/g, '')
      .replace(/（([^）]*)）/g, '')
      .trim();
  }

  // 提取道路名称（包含"路"、"街"、"桥"等关键词）
  const roadMatch = name.match(/([^（【】）]*(?:路|街|桥|环|道|口)[^（【】）]*)/);
  const road = roadMatch ? roadMatch[1].trim() : undefined;

  return { district, location, road };
}

/**
 * 创建增强的摄像头对象
 */
export function createEnhancedCamera(
  id: string,
  name: string,
  lng: number,
  lat: number,
  type: number,
  date: string,
  href: string,
  editTime?: string
): EnhancedCamera {
  const locationInfo = extractLocationInfo(name);

  return {
    id,
    name,
    lng,
    lat,
    type: type as CameraType,
    direction: extractDirection(name),
    date,
    editTime,
    href,
    status: extractStatus(name),
    ...locationInfo,
  };
}

/**
 * 计算两个方向的夹角（0-180度）
 * bearing1: 第一个方向（0-360）
 * bearing2: 第二个方向（0-360）
 */
export function angleBetweenBearings(bearing1: number, bearing2: number): number {
  let diff = Math.abs(bearing1 - bearing2);
  // 取最小角度
  if (diff > 180) {
    diff = 360 - diff;
  }
  return diff;
}

/**
 * 计算两点之间的方向角（bearing）
 * 返回值: 0-360度，0=正北，90=正东，180=正南，270=正西
 */
export function calculateBearing(
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number
): number {
  const dLng = toLng - fromLng;
  const y = Math.sin(dLng) * Math.cos(toRad(toLat));
  const x =
    Math.cos(toRad(fromLat)) * Math.sin(toRad(toLat)) -
    Math.sin(toRad(fromLat)) * Math.cos(toRad(toLat)) * Math.cos(dLng);
  const bearing = (Math.atan2(y, x) * 180) / Math.PI;
  return (bearing + 360) % 360; // 转换为0-360范围
}

/**
 * 判断路线是否会被摄像头拍到
 * 考虑摄像头的拍摄方向
 */
export function willBeDetectedByCamera(
  cameraLat: number,
  cameraLng: number,
  cameraDirection: CameraDirection,
  routeStartLat: number,
  routeStartLng: number,
  routeEndLat: number,
  routeEndLng: number,
  detectionAngleTolerance: number = 90 // 默认±90度范围内可被拍到
): boolean {
  // 如果方向未知，则保守起见认为会被拍到
  if (cameraDirection === CameraDirection.UNKNOWN) {
    return true;
  }

  // 获取摄像头的拍摄方向角度
  const cameraBearing = CAMERA_DIRECTION_VECTORS[cameraDirection];
  if (cameraBearing === -1) {
    return true;
  }

  // 计算路线的方向
  const routeBearing = calculateBearing(
    routeStartLat,
    routeStartLng,
    routeEndLat,
    routeEndLng
  );

  // 计算夹角
  const angle = angleBetweenBearings(cameraBearing, routeBearing);

  // 如果夹角在容差范围内，认为会被拍到
  // 理想情况：摄像头方向与路线方向夹角小于90度时可能被拍到
  return angle <= detectionAngleTolerance;
}

/**
 * 批量评估路线上的摄像头风险
 */
export interface CameraRisk {
  cameraIndex: number;
  camera: EnhancedCamera;
  distance: number; // 到路线的距离（米）
  risk: 'high' | 'medium' | 'low';
  reason: string;
}

export function assessCameraRisks(
  route: Array<{ lat: number; lng: number }>,
  cameras: EnhancedCamera[],
  detectionThreshold: number = 100 // 100米范围内视为靠近
): CameraRisk[] {
  const risks: CameraRisk[] = [];

  cameras.forEach((camera, index) => {
    // 计算摄像头到路线的最短距离
    let minDistance = Infinity;

    for (const routePoint of route) {
      const distance = calculateDistance(
        camera.lat,
        camera.lng,
        routePoint.lat,
        routePoint.lng
      );
      minDistance = Math.min(minDistance, distance);
    }

    if (minDistance <= detectionThreshold) {
      // 计算风险等级
      const willBeDetected = willBeDetectedByCamera(
        camera.lat,
        camera.lng,
        camera.direction,
        route[0].lat,
        route[0].lng,
        route[route.length - 1].lat,
        route[route.length - 1].lng
      );

      let riskLevel: 'high' | 'medium' | 'low' = 'low';
      let reason = '';

      if (willBeDetected) {
        if (camera.status.isPeakHourOnly) {
          riskLevel = 'medium';
          reason = '高峰期摄像头，拍摄方向与路线吻合';
        } else {
          riskLevel = 'high';
          reason = '摄像头拍摄方向与路线吻合';
        }
      } else {
        riskLevel = 'low';
        reason = '摄像头拍摄方向与路线不吻合';
      }

      // 如果是新增未确认的，降低风险等级
      if (camera.status.isLocationUnconfirmed) {
        if (riskLevel === 'high') riskLevel = 'medium';
        else if (riskLevel === 'medium') riskLevel = 'low';
        reason += '（位置未确认）';
      }

      risks.push({
        cameraIndex: index,
        camera,
        distance: minDistance,
        risk: riskLevel,
        reason,
      });
    }
  });

  return risks;
}

// 辅助函数
function toRad(degree: number): number {
  return (degree * Math.PI) / 180;
}

function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000; // 地球半径（米）
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
