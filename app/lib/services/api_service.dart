import 'package:dio/dio.dart';
import '../models/camera.dart';

class ApiService {
  // 本地开发时使用局域网 IP，部署后改为 Vercel 域名
  // Android 模拟器用 10.0.2.2, iOS 模拟器用 localhost
  static const String _baseUrl = 'http://localhost:3002';

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
}
