import 'package:flutter/material.dart';

/// 导航输入框中的途径点项
class WaypointItem {
  final TextEditingController controller;
  String? label;

  WaypointItem({String? initialText})
      : controller = TextEditingController(text: initialText);

  void dispose() {
    controller.dispose();
  }
}

/// 导航输入栏组件：起点 + 途径点 + 终点
class NavigationBar extends StatefulWidget {
  final VoidCallback? onSearch;

  const NavigationBar({super.key, this.onSearch});

  @override
  State<NavigationBar> createState() => _NavigationBarState();
}

class _NavigationBarState extends State<NavigationBar> {
  final TextEditingController _startController =
      TextEditingController(text: '我的位置');
  final TextEditingController _endController = TextEditingController();
  final List<WaypointItem> _waypoints = [];

  void _addWaypoint() {
    setState(() {
      _waypoints.add(WaypointItem());
    });
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints[index].dispose();
      _waypoints.removeAt(index);
    });
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    for (final wp in _waypoints) {
      wp.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 起点
          _buildInputRow(
            icon: Icons.my_location,
            iconColor: Colors.blue,
            controller: _startController,
            hint: '输入起点',
            isStart: true,
          ),

          // 途径点列表
          ..._waypoints.asMap().entries.map((entry) {
            final index = entry.key;
            final wp = entry.value;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildInputRow(
                icon: Icons.more_vert,
                iconColor: Colors.orange,
                controller: wp.controller,
                hint: '途径点 ${index + 1}',
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeWaypoint(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // 终点
          _buildInputRow(
            icon: Icons.location_on,
            iconColor: Colors.red,
            controller: _endController,
            hint: '输入终点',
          ),

          const SizedBox(height: 8),

          // 底部按钮行
          Row(
            children: [
              TextButton.icon(
                onPressed: _addWaypoint,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加途径点'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: widget.onSearch,
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('开始导航'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required String hint,
    bool isStart = false,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing,
        ],
      ],
    );
  }
}
