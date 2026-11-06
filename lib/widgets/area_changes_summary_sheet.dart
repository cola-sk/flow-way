import 'package:flutter/material.dart';
import '../models/monitored_area.dart';
import '../services/monitored_area_service.dart';

/// 监控区域摄像头变动汇总展示底部弹窗
class AreaChangesSummarySheet extends StatefulWidget {
  final List<AreaChangeSummary> summaries;
  final VoidCallback onDismissAll;
  final void Function(double lat, double lng, String name, CameraChangeType type)
      onLocateCamera;
  final Future<void> Function(String areaId)? onSimulateTest;

  const AreaChangesSummarySheet({
    super.key,
    required this.summaries,
    required this.onDismissAll,
    required this.onLocateCamera,
    this.onSimulateTest,
  });

  static Future<void> show({
    required BuildContext context,
    required List<AreaChangeSummary> summaries,
    required VoidCallback onDismissAll,
    required void Function(
            double lat, double lng, String name, CameraChangeType type)
        onLocateCamera,
    Future<void> Function(String areaId)? onSimulateTest,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AreaChangesSummarySheet(
        summaries: summaries,
        onDismissAll: onDismissAll,
        onLocateCamera: onLocateCamera,
        onSimulateTest: onSimulateTest,
      ),
    );
  }

  @override
  State<AreaChangesSummarySheet> createState() =>
      _AreaChangesSummarySheetState();
}

class _AreaChangesSummarySheetState extends State<AreaChangesSummarySheet> {
  late int _selectedAreaIndex;
  CameraChangeType? _filterType;

  @override
  void initState() {
    super.initState();
    _selectedAreaIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.summaries.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text(
              '当前监控区域暂无摄像头变动',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        ),
      );
    }

    final currentSummary =
        widget.summaries[_selectedAreaIndex.clamp(0, widget.summaries.length - 1)];

    final filteredRecords = _filterType == null
        ? currentSummary.records
        : currentSummary.records
            .where((r) => r.changeType == _filterType)
            .toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部小手柄
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 头部标题与关闭
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: Color(0xFFEA580C),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '区域摄像头变动汇总',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '发现 ${currentSummary.totalChanges} 处变动 · ${_formatTime(currentSummary.detectedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 多区域切换（若有多个监控区域发生变动）
          if (widget.summaries.length > 1)
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.summaries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final s = widget.summaries[idx];
                  final isSelected = idx == _selectedAreaIndex;
                  return ChoiceChip(
                    label: Text('${s.areaName} (${s.totalChanges})'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedAreaIndex = idx;
                        _filterType = null;
                      });
                    },
                  );
                },
              ),
            ),

          // KPI 核心统计卡片行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _buildKpiCard(
                  title: '新增探头',
                  count: currentSummary.addedCount,
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                  type: CameraChangeType.added,
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: '下线移除',
                  count: currentSummary.removedCount,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  type: CameraChangeType.removed,
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: '规则调整',
                  count: currentSummary.typeChangedCount,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  type: CameraChangeType.typeChanged,
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: '信息更新',
                  count: currentSummary.infoChangedCount,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFDBEAFE),
                  type: CameraChangeType.infoChanged,
                ),
              ],
            ),
          ),

          // 过滤器重置标签（若选中了某个类别）
          if (_filterType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '当前筛选: ${_getFilterLabel(_filterType!)} (${filteredRecords.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getFilterColor(_filterType!),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filterType = null),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('显示全部'),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // 变动明细列表
          Expanded(
            child: filteredRecords.isEmpty
                ? const Center(
                    child: Text('该分类下无变动记录', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: filteredRecords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];
                      return _buildChangeItem(context, record);
                    },
                  ),
          ),

          // 底部操作栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                if (widget.onSimulateTest != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onSimulateTest!(currentSummary.areaId);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('模拟变动'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    widget.onDismissAll();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('全部标记已读'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required Color color,
    required Color bgColor,
    required CameraChangeType type,
  }) {
    final isSelected = _filterType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterType = isSelected ? null : type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count > 0 && type == CameraChangeType.added ? '+$count' : '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeItem(BuildContext context, CameraChangeRecord record) {
    Color tagColor;
    Color tagBgColor;
    String tagLabel;
    IconData tagIcon;

    switch (record.changeType) {
      case CameraChangeType.added:
        tagColor = const Color(0xFF16A34A);
        tagBgColor = const Color(0xFFDCFCE7);
        tagLabel = '新增点位';
        tagIcon = Icons.add_location_alt_rounded;
        break;
      case CameraChangeType.removed:
        tagColor = const Color(0xFFDC2626);
        tagBgColor = const Color(0xFFFEE2E2);
        tagLabel = '已下线';
        tagIcon = Icons.location_off_rounded;
        break;
      case CameraChangeType.typeChanged:
        tagColor = const Color(0xFFD97706);
        tagBgColor = const Color(0xFFFEF3C7);
        tagLabel = '规则调整';
        tagIcon = Icons.published_with_changes_rounded;
        break;
      case CameraChangeType.infoChanged:
        tagColor = const Color(0xFF2563EB);
        tagBgColor = const Color(0xFFDBEAFE);
        tagLabel = '信息更新';
        tagIcon = Icons.update_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tagIcon, size: 12, color: tagColor),
                    const SizedBox(width: 4),
                    Text(
                      tagLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tagColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.cameraName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            record.description,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 13,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '坐标: ${record.lat.toStringAsFixed(5)}, ${record.lng.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onLocateCamera(
                    record.lat,
                    record.lng,
                    record.cameraName,
                    record.changeType,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '地图定位',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _getFilterLabel(CameraChangeType type) {
    switch (type) {
      case CameraChangeType.added:
        return '新增';
      case CameraChangeType.removed:
        return '下线';
      case CameraChangeType.typeChanged:
        return '规则调整';
      case CameraChangeType.infoChanged:
        return '信息更新';
    }
  }

  Color _getFilterColor(CameraChangeType type) {
    switch (type) {
      case CameraChangeType.added:
        return const Color(0xFF16A34A);
      case CameraChangeType.removed:
        return const Color(0xFFDC2626);
      case CameraChangeType.typeChanged:
        return const Color(0xFFD97706);
      case CameraChangeType.infoChanged:
        return const Color(0xFF2563EB);
    }
  }
}
