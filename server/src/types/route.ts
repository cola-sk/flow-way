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

export interface RouteResponse {
  route?: Route;
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
