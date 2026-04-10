import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class NavigationDialog extends StatefulWidget {
  final Function(LatLng, LatLng, bool) onNavigate;
  final List<String> recentLocations;

  const NavigationDialog({
    super.key,
    required this.onNavigate,
    this.recentLocations = const [],
  });

  @override
  State<NavigationDialog> createState() => _NavigationDialogState();
}

class _NavigationDialogState extends State<NavigationDialog> {
  late TextEditingController _startController;
  late TextEditingController _endController;
  bool _avoidCameras = true;
  bool _useMyLocation = true;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController();
    _endController = TextEditingController();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _handleNavigate() {
    if (_startController.text.isEmpty || _endController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入起点和终点')),
      );
      return;
    }

    // 这里简化处理，实际应该进行地址转坐标
    // 暂时使用固定坐标作为演示
    const startPoint = LatLng(39.9042, 116.4074); // 北京市中心
    const endPoint = LatLng(39.8848, 116.4065); // 相邻位置

    widget.onNavigate(startPoint, endPoint, _avoidCameras);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '绕行导航',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 起点输入
            TextField(
              controller: _startController,
              decoration: InputDecoration(
                hintText: '输入起点地址',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _useMyLocation
                    ? Tooltip(
                        message: '使用我的位置',
                        child: Icon(Icons.my_location,
                            color: Colors.blue[400], size: 18),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            // 终点输入
            TextField(
              controller: _endController,
              decoration: InputDecoration(
                hintText: '输入终点地址',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 避免摄像头开关
            CheckboxListTile(
              title: const Text('尽量避开摄像头'),
              value: _avoidCameras,
              onChanged: (value) {
                setState(() => _avoidCameras = value ?? false);
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleNavigate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    '开始导航',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
