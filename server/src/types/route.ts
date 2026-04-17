export interface Coordinate {
  lat: number;
  lng: number;
}

export interface RouteRequest {
  start: Coordinate;
  end: Coordinate;
  avoidCameras: boolean;
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
  maxIterations?: number;
  bestRoute?: RouteStepState;
  anchorDistance?: number;
}

export interface RoutePoint {
  lat: number;
  lng: number;
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
