export interface Coordinate {
  lat: number;
  lng: number;
}

export interface RouteRequest {
  start: Coordinate;
  end: Coordinate;
  avoidCameras: boolean;
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
  cameraRisks?: CameraRiskInfo[];  // 路线上所有相关摄像头的风险信息
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
