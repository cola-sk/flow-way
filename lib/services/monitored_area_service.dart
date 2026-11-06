import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/camera.dart';
import '../models/monitored_area.dart';

/// 监控区域业务管理服务
class MonitoredAreaService {
  static final MonitoredAreaService _instance = MonitoredAreaService._internal();
  factory MonitoredAreaService() => _instance;
  MonitoredAreaService._internal();

  static const String _areasKey = 'monitored_areas_v1';
  static const String _unreadSummariesKey = 'monitored_area_unread_summaries_v1';
  static const String _snapshotPrefix = 'monitored_area_snapshot_';
  static const String _monitoringEnabledKey = 'settings_area_monitoring_enabled';
  static const String _showAreasOnMapKey = 'settings_area_show_on_map';

  final Uuid _uuid = const Uuid();

  /// 检查监控全局开关（默认开启）
  Future<bool> isMonitoringEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_monitoringEnabledKey) ?? true;
  }

  /// 设置监控全局开关
  Future<void> setMonitoringEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringEnabledKey, enabled);
  }

  /// 是否在地图上绘制已保存的区域范围（默认显示）
  Future<bool> isShowAreasOnMap() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showAreasOnMapKey) ?? true;
  }

  /// 设置是否在地图上绘制已保存的区域范围
  Future<void> setShowAreasOnMap(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAreasOnMapKey, show);
  }

  /// 获取所有保存的监控区域
  Future<List<MonitoredArea>> getAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_areasKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((item) => MonitoredArea.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('解析监控区域失败: $e');
      return [];
    }
  }

  /// 保存或更新监控区域
  Future<void> saveArea(
    MonitoredArea area, {
    List<Camera>? initialCameras,
  }) async {
    final areas = await getAreas();
    final index = areas.indexWhere((a) => a.id == area.id);

    int count = area.lastCameraCount;
    if (initialCameras != null) {
      final inArea = initialCameras
          .where((c) => area.containsPoint(c.lat, c.lng))
          .toList();
      count = inArea.length;
      await _saveSnapshot(
        area.id,
        inArea.map((c) => AreaCameraSnapshotItem.fromCamera(c)).toList(),
      );
    }

    final updatedArea = area.copyWith(
      lastCameraCount: count,
      lastCheckedAt: DateTime.now(),
    );

    if (index >= 0) {
      areas[index] = updatedArea;
    } else {
      areas.add(updatedArea);
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(areas.map((a) => a.toJson()).toList());
    await prefs.setString(_areasKey, jsonStr);
  }

  /// 删除监控区域及其关联的快照与提醒
  Future<void> deleteArea(String areaId) async {
    final areas = await getAreas();
    areas.removeWhere((a) => a.id == areaId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _areasKey,
      jsonEncode(areas.map((a) => a.toJson()).toList()),
    );
    await prefs.remove('$_snapshotPrefix$areaId');

    // 清理该区域的未读汇总
    final summaries = await getUnreadSummaries();
    summaries.removeWhere((s) => s.areaId == areaId);
    await prefs.setString(
      _unreadSummariesKey,
      jsonEncode(summaries.map((s) => s.toJson()).toList()),
    );
  }

  /// 切换区域启用/禁用
  Future<void> toggleAreaEnabled(String areaId, bool enabled) async {
    final areas = await getAreas();
    final index = areas.indexWhere((a) => a.id == areaId);
    if (index >= 0) {
      areas[index] = areas[index].copyWith(enabled: enabled);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _areasKey,
        jsonEncode(areas.map((a) => a.toJson()).toList()),
      );
    }
  }

  /// 读取指定区域历史快照
  Future<List<AreaCameraSnapshotItem>?> _getSnapshot(String areaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_snapshotPrefix$areaId');
    if (raw == null || raw.isEmpty) return null;

    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((item) =>
              AreaCameraSnapshotItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// 保存指定区域快照
  Future<void> _saveSnapshot(
    String areaId,
    List<AreaCameraSnapshotItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString('$_snapshotPrefix$areaId', jsonStr);
  }

  /// 获取未读变动汇总
  Future<List<AreaChangeSummary>> getUnreadSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_unreadSummariesKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((item) =>
              AreaChangeSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 标记所有变动已读
  Future<void> markAllSummariesAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unreadSummariesKey);
  }

  /// 标记特定区域变动已读
  Future<void> markAreaSummaryAsRead(String areaId) async {
    final summaries = await getUnreadSummaries();
    summaries.removeWhere((s) => s.areaId == areaId);
    final prefs = await SharedPreferences.getInstance();
    if (summaries.isEmpty) {
      await prefs.remove(_unreadSummariesKey);
    } else {
      await prefs.setString(
        _unreadSummariesKey,
        jsonEncode(summaries.map((s) => s.toJson()).toList()),
      );
    }
  }

  /// 核心比对检测算法：检查当前摄像头列表与各个监控区域的变动
  Future<List<AreaChangeSummary>> checkChanges(List<Camera> cameras) async {
    if (cameras.isEmpty) return [];

    final enabled = await isMonitoringEnabled();
    if (!enabled) return [];

    final areas = await getAreas();
    if (areas.isEmpty) return [];

    final List<AreaChangeSummary> newSummaries = [];
    final List<MonitoredArea> updatedAreas = [];
    final now = DateTime.now();

    for (final area in areas) {
      if (!area.enabled) {
        updatedAreas.add(area);
        continue;
      }

      // 提取当前区域内的摄像头
      final currentInArea =
          cameras.where((c) => area.containsPoint(c.lat, c.lng)).toList();

      final prevSnapshot = await _getSnapshot(area.id);

      // 初次建立基准快照：不触发假警报
      if (prevSnapshot == null) {
        await _saveSnapshot(
          area.id,
          currentInArea.map((c) => AreaCameraSnapshotItem.fromCamera(c)).toList(),
        );
        updatedAreas.add(area.copyWith(
          lastCameraCount: currentInArea.length,
          lastCheckedAt: now,
        ));
        continue;
      }

      // 进行前后快照详细 Diff 比对
      final Map<String, AreaCameraSnapshotItem> prevMap = {
        for (final item in prevSnapshot) item.key: item,
      };

      final Map<String, Camera> currMap = {
        for (final cam in currentInArea)
          '${cam.lat.toStringAsFixed(6)},${cam.lng.toStringAsFixed(6)}_${cam.name}':
              cam,
      };

      final List<CameraChangeRecord> records = [];

      // 1. 查找新增摄像头 (Added)
      for (final entry in currMap.entries) {
        final key = entry.key;
        final cam = entry.value;
        if (!prevMap.containsKey(key)) {
          records.add(CameraChangeRecord(
            id: _uuid.v4(),
            areaId: area.id,
            areaName: area.name,
            changeType: CameraChangeType.added,
            cameraName: cam.name,
            lat: cam.lat,
            lng: cam.lng,
            newType: cam.type,
            newDate: cam.date,
            newEdittime: cam.edittime,
            detectedAt: now,
            description:
                '新增监控摄像头，抓拍类型: ${CameraChangeRecord.formatType(cam.type)}',
          ));
        }
      }

      // 2. 查找已移除/失效摄像头 (Removed)
      for (final entry in prevMap.entries) {
        final key = entry.key;
        final item = entry.value;
        if (!currMap.containsKey(key)) {
          records.add(CameraChangeRecord(
            id: _uuid.v4(),
            areaId: area.id,
            areaName: area.name,
            changeType: CameraChangeType.removed,
            cameraName: item.name,
            lat: item.lat,
            lng: item.lng,
            oldType: item.type,
            oldDate: item.date,
            oldEdittime: item.edittime,
            detectedAt: now,
            description: '摄像头已从最新数据源中下线或移除',
          ));
        }
      }

      // 3. 查找规则类型变动与时间更新 (Type / Info Changed)
      for (final entry in currMap.entries) {
        final key = entry.key;
        final cam = entry.value;
        final prev = prevMap[key];
        if (prev == null) continue;

        if (cam.type != prev.type) {
          records.add(CameraChangeRecord(
            id: _uuid.v4(),
            areaId: area.id,
            areaName: area.name,
            changeType: CameraChangeType.typeChanged,
            cameraName: cam.name,
            lat: cam.lat,
            lng: cam.lng,
            oldType: prev.type,
            newType: cam.type,
            oldDate: prev.date,
            newDate: cam.date,
            oldEdittime: prev.edittime,
            newEdittime: cam.edittime,
            detectedAt: now,
            description:
                '抓拍规则调整：由 [${CameraChangeRecord.formatType(prev.type)}] 变更为 [${CameraChangeRecord.formatType(cam.type)}]',
          ));
        } else if (cam.edittime != prev.edittime ||
            cam.date != prev.date ||
            cam.name != prev.name) {
          final List<String> changeParts = [];
          if (cam.name != prev.name) {
            changeParts.add('名称由 "${prev.name}" 更新为 "${cam.name}"');
          }
          if (cam.edittime != prev.edittime) {
            changeParts.add(
                '编辑时间由 ${prev.edittime ?? '无'} 更新为 ${cam.edittime ?? '无'}');
          }
          if (cam.date != prev.date) {
            changeParts.add('抓取时间由 ${prev.date} 更新为 ${cam.date}');
          }
          records.add(CameraChangeRecord(
            id: _uuid.v4(),
            areaId: area.id,
            areaName: area.name,
            changeType: CameraChangeType.infoChanged,
            cameraName: cam.name,
            lat: cam.lat,
            lng: cam.lng,
            oldType: prev.type,
            newType: cam.type,
            oldDate: prev.date,
            newDate: cam.date,
            oldEdittime: prev.edittime,
            newEdittime: cam.edittime,
            detectedAt: now,
            description: changeParts.join('；'),
          ));
        }
      }

      // 如果有变动，保存汇总
      if (records.isNotEmpty) {
        final summary = AreaChangeSummary(
          areaId: area.id,
          areaName: area.name,
          detectedAt: now,
          records: records,
        );
        newSummaries.add(summary);
      }

      // 无论有无变动，更新该区域的基准快照和记录数
      await _saveSnapshot(
        area.id,
        currentInArea.map((c) => AreaCameraSnapshotItem.fromCamera(c)).toList(),
      );
      updatedAreas.add(area.copyWith(
        lastCameraCount: currentInArea.length,
        lastCheckedAt: now,
      ));
    }

    // 保存更新后的区域元数据
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _areasKey,
      jsonEncode(updatedAreas.map((a) => a.toJson()).toList()),
    );

    // 如果产生了新的变动汇总，追加合并到未读列表
    if (newSummaries.isNotEmpty) {
      final existingSummaries = await getUnreadSummaries();
      // 如果某区域已有未读记录，先替换旧的
      final existingMap = {for (final s in existingSummaries) s.areaId: s};
      for (final ns in newSummaries) {
        existingMap[ns.areaId] = ns;
      }
      final merged = existingMap.values.toList();
      await prefs.setString(
        _unreadSummariesKey,
        jsonEncode(merged.map((s) => s.toJson()).toList()),
      );
    }

    return newSummaries;
  }

  /// 测试专用模拟方法：向指定监控区域注入变动，方便用户直接体验和验收
  Future<AreaChangeSummary?> simulateTestChanges(
    String areaId,
    List<Camera> allCameras,
  ) async {
    final areas = await getAreas();
    final areaIndex = areas.indexWhere((a) => a.id == areaId);
    if (areaIndex < 0) return null;

    final area = areas[areaIndex];
    final inArea =
        allCameras.where((c) => area.containsPoint(c.lat, c.lng)).toList();

    final now = DateTime.now();
    final List<CameraChangeRecord> testRecords = [];

    // 1. 模拟新增 1 个测试摄像头
    double testLat = area.centerLat ?? (area.southWestLat! + area.northEastLat!) / 2;
    double testLng = area.centerLng ?? (area.southWestLng! + area.northEastLng!) / 2;
    // 稍作微小偏移以防完全重叠
    testLat += 0.002;
    testLng += 0.002;

    testRecords.add(CameraChangeRecord(
      id: _uuid.v4(),
      areaId: area.id,
      areaName: area.name,
      changeType: CameraChangeType.added,
      cameraName: '【模拟新增】${area.name}路口抓拍点',
      lat: testLat,
      lng: testLng,
      newType: 5,
      newDate: now.toIso8601String().substring(0, 19),
      detectedAt: now,
      description: '模拟新增探头，抓拍类型: 晚高峰+六环内',
    ));

    // 2. 如果区域内已有摄像头，模拟第 1 个规则变更
    if (inArea.isNotEmpty) {
      final target = inArea.first;
      final newType = target.type == 6 ? 2 : 6;
      testRecords.add(CameraChangeRecord(
        id: _uuid.v4(),
        areaId: area.id,
        areaName: area.name,
        changeType: CameraChangeType.typeChanged,
        cameraName: target.name,
        lat: target.lat,
        lng: target.lng,
        oldType: target.type,
        newType: newType,
        detectedAt: now,
        description:
            '抓拍规则调整：由 [${CameraChangeRecord.formatType(target.type)}] 变更为 [${CameraChangeRecord.formatType(newType)}]',
      ));
    }

    final summary = AreaChangeSummary(
      areaId: area.id,
      areaName: area.name,
      detectedAt: now,
      records: testRecords,
    );

    // 写入未读提醒
    final summaries = await getUnreadSummaries();
    summaries.removeWhere((s) => s.areaId == area.id);
    summaries.insert(0, summary);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _unreadSummariesKey,
      jsonEncode(summaries.map((s) => s.toJson()).toList()),
    );

    return summary;
  }
}
