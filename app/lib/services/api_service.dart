import 'package:dio/dio.dart';
import '../models/camera.dart';
import '../models/route.dart';
import 'package:latlong2/latlong.dart';

class ApiService {
  // 本地开发时使用局域网 IP，部署后改为 Vercel 域名
  // Android 模拟器用 10.0.2.2, iOS 模拟器用 localhost
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
}

