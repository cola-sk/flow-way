import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/camera.dart';
import '../models/route.dart';
import 'package:latlong2/latlong.dart';

String _resolveBaseUrl() {
  if (kIsWeb) {
    // Web 端：Chrome 本地开发用 localhost:3000，部署到生产域名时用当前 origin 的 server
    final origin = Uri.base.origin;
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      return 'http://localhost:3000';
    }
    return 'https://flow-way.tz0618.uk';
  }
  // 原生端（Android / iOS）直接打生产接口
  return 'https://flow-way.tz0618.uk';
}

String _formatError(Object e) {
  if (e is DioException) {
    final resp = e.response;
    if (resp != null) {
      return '[${resp.statusCode}] ${resp.statusMessage} — ${resp.data}';
    }
    return '${e.type.name}: ${e.message}';
  }
  return e.toString();
}

class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: _resolveBaseUrl(),
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  /// 获取所有摄像头数据
  Future<CamerasResponse> getCameras() async {
    final response = await _dio.get('/api/cameras');
    return CamerasResponse.fromJson(response.data);
  }

  /// 规划路线（支持避开摄像头的智能路由）
  /// [start] 起点坐标
  /// [end] 终点坐标
  /// [avoidCameras] 是否尽量避开摄像头（废弃摄像头由服务端自动排除）
  Future<RouteResponse> planRoute({
    required LatLng start,
    required LatLng end,
    bool avoidCameras = false,
  }) async {
    try {
      final response = await _dio.post('/api/route/plan', data: {
        'start': {
          'lat': start.latitude,
          'lng': start.longitude,
        },
        'end': {
          'lat': end.latitude,
          'lng': end.longitude,
        },
        'avoidCameras': avoidCameras,
      });
      return RouteResponse.fromJson(response.data);
    } catch (e) {
      final msg = '路线规划失败: ${_formatError(e)}';
      print(msg);
      return RouteResponse(errorMessage: msg);
    }
  }

  /// 保存标记点
  Future<bool> saveWayPoint({
    required String name,
    required LatLng location,
  }) async {
    try {
      await _dio.post('/api/waypoints', data: {
        'name': name,
        'lat': location.latitude,
        'lng': location.longitude,
      });
      return true;
    } catch (e) {
      print('保存标记点失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 获取用户保存的标记点
  Future<List<WayPoint>> getWayPoints() async {
    try {
      final response = await _dio.get('/api/waypoints');
      final List<dynamic> data = response.data['waypoints'] ?? [];
      return data.map((item) => WayPoint.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('获取标记点失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 删除标记点
  Future<bool> deleteWayPoint(String id) async {
    try {
      await _dio.delete('/api/waypoints/$id');
      return true;
    } catch (e) {
      print('删除标记点失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 搜索建议词（输入时自动补全）
  Future<List<PlaceResult>> suggestPlaces(
    String keyword, {
    LatLng? nearBy,
  }) async {
    try {
      final params = <String, dynamic>{'keyword': keyword};
      if (nearBy != null) {
        params['lat'] = nearBy.latitude;
        params['lng'] = nearBy.longitude;
      }
      final response = await _dio.get('/api/suggest', queryParameters: params);
      final List<dynamic> data = response.data['suggestions'] ?? [];
      return data
          .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('搜索建议失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 搜索地点（关键词 + 可选当前坐标用于附近优先）
  Future<List<PlaceResult>> searchPlaces(
    String keyword, {
    LatLng? nearBy,
  }) async {
    try {
      final params = <String, dynamic>{'keyword': keyword};
      if (nearBy != null) {
        params['lat'] = nearBy.latitude;
        params['lng'] = nearBy.longitude;
      }
      final response = await _dio.get('/api/search', queryParameters: params);
      final List<dynamic> data = response.data['results'] ?? [];
      return data
          .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('搜索地点失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 获取废弃摄像头列表
  Future<List<DismissedCamera>> getDismissedCameras() async {
    try {
      final response = await _dio.get('/api/dismissed-cameras');
      final List<dynamic> data = response.data['dismissed'] ?? [];
      return data
          .map((e) => DismissedCamera.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取废弃摄像头失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 标记摄像头为废弃（保存到服务端 Redis）
  Future<bool> markCameraDismissed({
    required double lat,
    required double lng,
    required String name,
  }) async {
    try {
      await _dio.post('/api/dismissed-cameras',
          data: {'lat': lat, 'lng': lng, 'name': name});
      return true;
    } catch (e) {
      print('标记废弃失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 取消废弃标记
  Future<bool> unmarkCameraDismissed({
    required double lat,
    required double lng,
  }) async {
    try {
      await _dio.delete('/api/dismissed-cameras',
          data: {'lat': lat, 'lng': lng});
      return true;
    } catch (e) {
      print('取消废弃失败: ${_formatError(e)}');
      return false;
    }
  }
}

class PlaceResult {
  final String name;
  final String address;
  final LatLng location;

  PlaceResult({
    required this.name,
    required this.address,
    required this.location,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
    );
  }
}

class DismissedCamera {
  final double lat;
  final double lng;
  final String name;
  final String markedAt;

  DismissedCamera({
    required this.lat,
    required this.lng,
    required this.name,
    required this.markedAt,
  });

  factory DismissedCamera.fromJson(Map<String, dynamic> json) {
    return DismissedCamera(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      name: json['name'] as String,
      markedAt: json['markedAt'] as String? ?? '',
    );
  }
}

