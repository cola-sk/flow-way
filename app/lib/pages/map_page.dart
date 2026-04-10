import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/camera.dart';
import '../models/route.dart';
import '../services/api_service.dart';
import '../widgets/navigation_bar.dart' as nav;
import '../widgets/navigation_dialog.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  List<Camera> _cameras = [];
  List<WayPoint> _wayPoints = [];
  bool _loading = true;
  String? _error;
  String _updatedAt = '';

  // 当前导航路线
  NavigationRoute? _currentRoute;
  bool _isNavigating = false;

  // 北京中心坐标 (GCJ-02)
  static const _beijingCenter = LatLng(39.9042, 116.4074);

  @override
  void initState() {
    super.initState();
    _loadCameras();
    _loadWayPoints();
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

  Future<void> _loadWayPoints() async {
    try {
      final waypoints = await _apiService.getWayPoints();
      setState(() {
        _wayPoints = waypoints;
      });
    } catch (e) {
      print('加载标记点失败: $e');
    }
  }

  void _showNavigationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => NavigationDialog(
        onNavigate: (start, end, avoidCameras) async {
          await _planRoute(start, end, avoidCameras);
        },
        recentLocations: const [],
      ),
    );
  }

  Future<void> _planRoute(LatLng start, LatLng end, bool avoidCameras) async {
    setState(() => _isNavigating = true);

    try {
      final response = await _apiService.planRoute(
        start: start,
        end: end,
        avoidCameras: avoidCameras,
      );

      if (response.route != null) {
        setState(() {
          _currentRoute = response.route;
        });
        // 缩放地图以显示整个路线
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([start, end]),
            padding: const EdgeInsets.all(100),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已规划路线\n距离: ${(_currentRoute!.distance / 1000).toStringAsFixed(1)}km\n'
              '摄像头数: ${_currentRoute!.cameraIndicesOnRoute.length}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.errorMessage ?? '路线规划失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('路线规划异常: $e')),
      );
    } finally {
      setState(() => _isNavigating = false);
    }
  }

  void _addWayPoint(LatLng location) {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameController = TextEditingController();
        return AlertDialog(
          title: const Text('添加标记点'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: '输入标记点名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入标记点名称')),
                  );
                  return;
                }

                final success = await _apiService.saveWayPoint(
                  name: name,
                  location: location,
                );

                if (success) {
                  await _loadWayPoints();
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('标记点已保存')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('保存标记点失败')),
                    );
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _deleteWayPoint(WayPoint wayPoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标记点'),
        content: Text('确定删除标记点 "${wayPoint.name}" 吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteWayPoint(wayPoint.id);
      if (success) {
        await _loadWayPoints();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('标记点已删除')),
          );
        }
      }
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

  void _showWayPointInfo(WayPoint wayPoint) {
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
                const Icon(Icons.bookmark, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wayPoint.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('坐标', '${wayPoint.location.longitude}, ${wayPoint.location.latitude}'),
            _infoRow('创建时间', wayPoint.createdAt.toString().split('.')[0]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteWayPoint(wayPoint);
                  },
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // 导航到此标记点
                    _planRoute(_beijingCenter, wayPoint.location, true);
                    Navigator.pop(ctx);
                  },
                  child: const Text('导航到这里'),
                ),
              ],
            ),
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
          GestureDetector(
            onLongPress: (details) {
              // 长按地图添加标记点
              final tapPosition = _mapController.camera.project(
                LatLng(
                  details.localPosition.dy.toDouble(),
                  details.localPosition.dx.toDouble(),
                ),
              );
              // 简单实现，实际需要使用更精确的坐标转换
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('长按地图可添加标记点 (开发中)')),
              );
            },
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _beijingCenter,
                initialZoom: 11,
                minZoom: 5,
                maxZoom: 18,
                onTap: (tapPosition, point) {
                  // 短按添加标记点
                  _addWayPoint(point);
                },
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

                // 路线图层
                if (_currentRoute != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _currentRoute!.polylinePoints,
                        color: Colors.blue,
                        strokeWidth: 4,
                        isDashed: false,
                      ),
                    ],
                  ),

                // 路线起点和终点标记
                if (_currentRoute != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentRoute!.startPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 30,
                        ),
                      ),
                      Marker(
                        point: _currentRoute!.endPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                    ],
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

                // 用户标记点层
                MarkerLayer(
                  markers: _wayPoints.map((wayPoint) {
                    return Marker(
                      point: wayPoint.location,
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () => _showWayPointInfo(wayPoint),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.bookmark,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // 顶部安全区域 + 导航栏
          SafeArea(
            child: Column(
              children: [
                nav.NavigationBar(
                  onSearch: _showNavigationDialog,
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
                  '摄像头: ${_cameras.length}个 · 标记点: ${_wayPoints.length}个 · 更新: $_updatedAt',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ),

          // 导航进度指示器
          if (_isNavigating)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('正在规划路线...'),
                    ],
                  ),
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
