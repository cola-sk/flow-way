import 'package:dio/dio.dart';
import '../models/camera.dart';
import '../models/route.dart';
import 'package:latlong2/latlong.dart';

class ApiService {
  // 本地开发时使用局域网 IP，部署后改为 Vercel 域名
  // static const String _baseUrl = 'https://flow-way.tz0618.uk';
  static const String _baseUrl = 'http://localhost:3000';

  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
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
  /// [avoidCameras] 是否尽量避开摄像头
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
      return RouteResponse(errorMessage: '路线规划失败: $e');
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
      print('保存标记点失败: $e');
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
      print('获取标记点失败: $e');
      return [];
    }
  }

  /// 删除标记点
  Future<bool> deleteWayPoint(String id) async {
    try {
      await _dio.delete('/api/waypoints/$id');
      return true;
    } catch (e) {
      print('删除标记点失败: $e');
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
      print('搜索建议失败: $e');
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
      print('搜索地点失败: $e');
      return [];
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

