import 'package:latlong2/latlong.dart';

/// 用户标记的位置点
class WayPoint {
  final String id;
  final String name;
  final LatLng location;
  final DateTime createdAt;

  WayPoint({
    required this.id,
    required this.name,
    required this.location,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': location.latitude,
    'lng': location.longitude,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WayPoint.fromJson(Map<String, dynamic> json) => WayPoint(
    id: json['id'] as String,
    name: json['name'] as String,
    location: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// 路线步骤（转向建议）
class RouteStep {
  final String instruction;
  final double distance;
  final int duration;
  final int polylineIdxStart;
  final int polylineIdxEnd;
  final String? action;
  final String? direction;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.polylineIdxStart,
    required this.polylineIdxEnd,
    this.action,
    this.direction,
  });

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'distance': distance,
    'duration': duration,
    'polylineIdxStart': polylineIdxStart,
    'polylineIdxEnd': polylineIdxEnd,
    'action': action,
    'direction': direction,
  };

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
    instruction: json['instruction'] as String,
    distance: (json['distance'] as num).toDouble(),
    duration: (json['duration'] as num).toInt(),
    polylineIdxStart: (json['polylineIdxStart'] as num).toInt(),
    polylineIdxEnd: (json['polylineIdxEnd'] as num).toInt(),
    action: json['action'] as String?,
    direction: json['direction'] as String?,
  );
}

/// 导航路线信息
class NavigationRoute {
  final String id;
  final LatLng startPoint;
  final LatLng endPoint;
  final List<LatLng> polylinePoints;
  final double distance; // 米
  final int duration; // 秒
  final String routeType; // 'normal' 或 'avoid_cameras'
  final List<int> cameraIndicesOnRoute; // 路线上的摄像头索引
  final List<RouteStep>? steps; // 转向建议
  final DateTime createdAt;

  NavigationRoute({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.routeType,
    required this.cameraIndicesOnRoute,
    this.steps,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startPoint': {
      'lat': startPoint.latitude,
      'lng': startPoint.longitude,
    },
    'endPoint': {
      'lat': endPoint.latitude,
      'lng': endPoint.longitude,
    },
    'polylinePoints': polylinePoints
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'distance': distance,
    'duration': duration,
    'routeType': routeType,
    'cameraIndicesOnRoute': cameraIndicesOnRoute,
    'steps': steps?.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory NavigationRoute.fromJson(Map<String, dynamic> json) => NavigationRoute(
    id: json['id'] as String,
    startPoint: LatLng(
      (json['startPoint']['lat'] as num).toDouble(),
      (json['startPoint']['lng'] as num).toDouble(),
    ),
    endPoint: LatLng(
      (json['endPoint']['lat'] as num).toDouble(),
      (json['endPoint']['lng'] as num).toDouble(),
    ),
    polylinePoints: (json['polylinePoints'] as List)
        .cast<Map<String, dynamic>>()
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList(),
    distance: (json['distance'] as num).toDouble(),
    duration: (json['duration'] as num).toInt(),
    routeType: json['routeType'] as String,
    cameraIndicesOnRoute: List<int>.from(json['cameraIndicesOnRoute'] as List),
    steps: json['steps'] != null
        ? (json['steps'] as List)
            .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList()
        : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// 路线规划 API 响应
class RouteResponse {
  final NavigationRoute? route;
  final String? errorMessage;

  RouteResponse({
    this.route,
    this.errorMessage,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    return RouteResponse(
      route: json['route'] != null ? NavigationRoute.fromJson(json['route']) : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// 路线单步规划 API 响应（每次只规划一轮，用于前端逐轮绘制）
class RouteStepResponse {
  final NavigationRoute? currentRoute;
  final NavigationRoute? bestRoute;
  final int iteration;
  final int maxIterations;
  final bool done;
  final double? anchorDistance;
  final String? errorMessage;

  RouteStepResponse({
    this.currentRoute,
    this.bestRoute,
    required this.iteration,
    required this.maxIterations,
    required this.done,
    this.anchorDistance,
    this.errorMessage,
  });

  factory RouteStepResponse.fromJson(Map<String, dynamic> json) {
    return RouteStepResponse(
      currentRoute: json['currentRoute'] != null
          ? NavigationRoute.fromJson(json['currentRoute'] as Map<String, dynamic>)
          : null,
      bestRoute: json['bestRoute'] != null
          ? NavigationRoute.fromJson(json['bestRoute'] as Map<String, dynamic>)
          : null,
      iteration: (json['iteration'] as num?)?.toInt() ?? 0,
      maxIterations: (json['maxIterations'] as num?)?.toInt() ?? 15,
      done: json['done'] as bool? ?? false,
      anchorDistance: (json['anchorDistance'] as num?)?.toDouble(),
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
