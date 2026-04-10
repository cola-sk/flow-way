import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/camera.dart';
import '../services/api_service.dart';
import '../widgets/navigation_bar.dart' as nav;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  List<Camera> _cameras = [];
  bool _loading = true;
  String? _error;
  String _updatedAt = '';

  // 北京中心坐标 (GCJ-02)
  static const _beijingCenter = LatLng(39.9042, 116.4074);

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getCameras();
      setState(() {
        _cameras = response.cameras;
        _updatedAt = response.updatedAt;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载摄像头数据失败: $e';
        _loading = false;
      });
    }
  }

  Color _cameraColor(int type) {
    switch (type) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 4:
        return Colors.grey;
      case 6:
        return Colors.purple;
      default:
        return Colors.red;
    }
  }

  void _showCameraInfo(Camera camera) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.videocam, color: _cameraColor(camera.type)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    camera.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('类型', camera.typeLabel),
            _infoRow('坐标', '${camera.lng}, ${camera.lat}'),
            _infoRow('更新日期', camera.date),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地图层
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _beijingCenter,
              initialZoom: 11,
              minZoom: 5,
              maxZoom: 18,
            ),
            children: [
              // 高德瓦片图层 (GCJ-02 坐标系，与摄像头坐标一致)
              TileLayer(
                urlTemplate:
                    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                subdomains: const ['1', '2', '3', '4'],
                userAgentPackageName: 'com.flowway.app',
                maxZoom: 18,
              ),
              // 摄像头标记层
              MarkerLayer(
                markers: _cameras.map((cam) {
                  return Marker(
                    point: LatLng(cam.lat, cam.lng),
                    width: 24,
                    height: 24,
                    child: GestureDetector(
                      onTap: () => _showCameraInfo(cam),
                      child: Icon(
                        Icons.videocam,
                        color: _cameraColor(cam.type),
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // 顶部安全区域 + 导航栏
          SafeArea(
            child: Column(
              children: [
                nav.NavigationBar(
                  onSearch: () {
                    // TODO: 实现绕行导航逻辑
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('绕行导航功能开发中...')),
                    );
                  },
                ),
              ],
            ),
          ),

          // 加载指示器
          if (_loading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('正在加载摄像头数据...'),
                    ],
                  ),
                ),
              ),
            ),

          // 错误提示
          if (_error != null)
            Center(
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadCameras,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 底部信息栏
          if (!_loading && _error == null)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  '摄像头: ${_cameras.length}个 · 更新: $_updatedAt',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ),
        ],
      ),
      // 定位按钮
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          _mapController.move(_beijingCenter, 11);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
