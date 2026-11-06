import 'package:flutter/material.dart';
import '../models/monitored_area.dart';
import '../services/monitored_area_service.dart';

/// 监控区域管理列表弹窗
class MonitoredAreaManagementSheet extends StatefulWidget {
  final List<MonitoredArea> areas;
  final VoidCallback onAddNewArea;
  final void Function(MonitoredArea area) onLocateArea;
  final Future<void> Function(String areaId) onSimulateTest;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onShowOnMapChanged;

  const MonitoredAreaManagementSheet({
    super.key,
    required this.areas,
    required this.onAddNewArea,
    required this.onLocateArea,
    required this.onSimulateTest,
    required this.onRefresh,
    required this.onShowOnMapChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required List<MonitoredArea> areas,
    required VoidCallback onAddNewArea,
    required void Function(MonitoredArea area) onLocateArea,
    required Future<void> Function(String areaId) onSimulateTest,
    required Future<void> Function() onRefresh,
    required ValueChanged<bool> onShowOnMapChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MonitoredAreaManagementSheet(
        areas: areas,
        onAddNewArea: onAddNewArea,
        onLocateArea: onLocateArea,
        onSimulateTest: onSimulateTest,
        onRefresh: onRefresh,
        onShowOnMapChanged: onShowOnMapChanged,
      ),
    );
  }

  @override
  State<MonitoredAreaManagementSheet> createState() =>
      _MonitoredAreaManagementSheetState();
}

class _MonitoredAreaManagementSheetState
    extends State<MonitoredAreaManagementSheet> {
  final MonitoredAreaService _service = MonitoredAreaService();
  late List<MonitoredArea> _areas;
  bool _monitoringGlobalEnabled = true;
  bool _showOnMap = true;

  @override
  void initState() {
    super.initState();
    _areas = List.from(widget.areas);
    _loadGlobalSwitch();
  }

  Future<void> _loadGlobalSwitch() async {
    final enabled = await _service.isMonitoringEnabled();
    final showOnMap = await _service.isShowAreasOnMap();
    if (mounted) {
      setState(() {
        _monitoringGlobalEnabled = enabled;
        _showOnMap = showOnMap;
      });
    }
  }

  Future<void> _toggleGlobalSwitch(bool val) async {
    await _service.setMonitoringEnabled(val);
    if (mounted) {
      setState(() => _monitoringGlobalEnabled = val);
    }
    await widget.onRefresh();
  }

  Future<void> _toggleShowOnMap(bool val) async {
    await _service.setShowAreasOnMap(val);
    if (mounted) {
      setState(() => _showOnMap = val);
    }
    widget.onShowOnMapChanged(val);
  }

  Future<void> _toggleArea(String areaId, bool val) async {
    await _service.toggleAreaEnabled(areaId, val);
    final updated = await _service.getAreas();
    if (mounted) {
      setState(() => _areas = updated);
    }
    await widget.onRefresh();
  }

  Future<void> _deleteArea(MonitoredArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除监控区域'),
        content: Text('确定要删除监控区域【${area.name}】吗？删除后将不再跟踪该区域内的探头变动。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteArea(area.id);
      final updated = await _service.getAreas();
      if (mounted) {
        setState(() => _areas = updated);
      }
      await widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.fence_rounded,
                  color: Color(0xFF0F766E),
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  '监控区域管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 全局提醒开关
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile.adaptive(
              value: _monitoringGlobalEnabled,
              onChanged: _toggleGlobalSwitch,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '开启变动检测与提醒',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                '每次刷新或打开时，自动比对所选区域内探头新增或变动',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile.adaptive(
              value: _showOnMap,
              onChanged: _toggleShowOnMap,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '在地图上显示区域范围',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                '关闭后不再绘制圆圈和矩形，变动检测与提醒不受影响',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _areas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_searching_rounded,
                            size: 48,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '尚未添加任何监控区域',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '可以在地图上圈选家、公司或常走道路周边，\n探头数据有任何变化将实时为您汇总提醒。',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _areas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final area = _areas[index];
                      return _buildAreaCard(context, area);
                    },
                  ),
          ),

          // 底部新建区域按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onAddNewArea();
                  },
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('在地图上圈选新区域'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(BuildContext context, MonitoredArea area) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: area.shapeType == AreaShapeType.circle
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  area.shapeType == AreaShapeType.circle
                      ? Icons.circle_outlined
                      : Icons.crop_square_rounded,
                  size: 16,
                  color: area.shapeType == AreaShapeType.circle
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF9333EA),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${area.dimensionLabel} · 探头 ${area.lastCameraCount} 个',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: area.enabled,
                onChanged: (val) => _toggleArea(area.id, val),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onLocateArea(area);
                },
                icon: const Icon(Icons.my_location_rounded, size: 15),
                label: const Text('地图定位'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () async {
                  await widget.onSimulateTest(area.id);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.science_outlined, size: 15),
                label: const Text('模拟变动'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => _deleteArea(area),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.red),
                tooltip: '删除此区域',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
