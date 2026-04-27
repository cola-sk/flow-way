export interface Coordinate {
  lat: number;
  lng: number;
}

export interface RouteRequest {
  start: Coordinate;
  end: Coordinate;
  avoidCameras: boolean;
  ignoreOutsideSixthRing?: boolean;
  userToken?: string;
  avoidAlgorithmVersion?: string;
  ignoreLowRiskCameras?: boolean;
}

export interface RouteStepState {
  polylinePoints: RoutePoint[];
  distance: number;
  duration: number;
  cameraIndicesOnRoute: number[];
}

export interface RoutePlanStepRequest {
  start: Coordinate;
  end: Coordinate;
  iteration: number;
  ignoreOutsideSixthRing?: boolean;
  maxIterations?: number;
  userToken?: string;
  avoidAlgorithmVersion?: string;
  waypoints?: Coordinate[];
  legIndex?: number;
  totalLegs?: number;
  bestRoute?: RouteStepState;
  anchorDistance?: number;
  /** 之前规划过的路线折线，用于"再次尝试"时排除已探索路径 */
  excludePolylines?: RoutePoint[][];
  /** 是否忽略标记为低风险（type=12）的摄像头 */
  ignoreLowRiskCameras?: boolean;
}

export interface RoutePoint {
  lat: number;
  lng: number;
}

export interface RouteStep {
  instruction: string;
  distance: number;
  duration: number;
  polylineIdxStart: number;
  polylineIdxEnd: number;
  action?: string;
  direction?: string;
}

export interface Route {
  id: string;
  startPoint: RoutePoint;
  endPoint: RoutePoint;
  polylinePoints: RoutePoint[];
  distance: number;
  duration: number;
  routeType: 'normal' | 'avoid_cameras';
  cameraIndicesOnRoute: number[];
  avoidAlgorithmVersion?: string;
  steps?: RouteStep[];
  createdAt: string;
}

export interface CameraDetectionDetail {
  cameraIndex: number;
  cameraName: string;
  cameraDirection: string;
  routeBearing: number;      // 路线的方向角（0-360）
  cameraBearing: number;     // 摄像头的方向角（0-360）
  angleGap: number;          // 两个方向的夹角（0-180）
  detected: boolean;         // 是否会被拍到
}

export interface CameraRiskInfo {
  cameraIndex: number;
  cameraName: string;
  cameraDirection: string;
  distance: string;
  riskLevel: 'high' | 'medium' | 'low';
  reason: string;
}

export interface RouteResponse {
  route?: Route;
  cameraDetections?: CameraDetectionDetail[];  // 简化版：检测详情
  cameraRisks?: CameraRiskInfo[];              // 复杂版：风险评估
  errorMessage?: string;
}

export interface RoutePlanStepResponse {
  currentRoute?: Route;
  bestRoute?: Route;
  iteration: number;
  maxIterations: number;
  done: boolean;
  anchorDistance?: number;
  errorMessage?: string;
}

// 标记点类型
export interface WayPoint {
  id: string;
  name: string;
  lat: number;
  lng: number;
  createdAt: string;
}

export interface WayPointsResponse {
  waypoints: WayPoint[];
}
