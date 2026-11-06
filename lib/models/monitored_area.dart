import 'package:latlong2/latlong.dart';
import 'camera.dart';

/// 监控区域形状类型
enum AreaShapeType {
  circle, // 圆形圈选
  rectangle, // 矩形框选
}

/// 摄像头变动类型
enum CameraChangeType {
  added, // 新增点位
  removed, // 移除/失效下线
  typeChanged, // 抓拍类型/规则变更
  infoChanged, // 数据更新时间/名称等变更
}

/// 单个摄像头变动明细
class CameraChangeRecord {
  final String id;
  final String areaId;
  final String areaName;
  final CameraChangeType changeType;
  final String cameraName;
  final double lat;
  final double lng;
  final int? oldType;
  final int? newType;
  final String? oldDate;
  final String? newDate;
  final String? oldEdittime;
  final String? newEdittime;
  final DateTime detectedAt;
  final String description;

  CameraChangeRecord({
    required this.id,
    required this.areaId,
    required this.areaName,
    required this.changeType,
    required this.cameraName,
    required this.lat,
    required this.lng,
    this.oldType,
    this.newType,
    this.oldDate,
    this.newDate,
    this.oldEdittime,
    this.newEdittime,
    required this.detectedAt,
    required this.description,
  });

  factory CameraChangeRecord.fromJson(Map<String, dynamic> json) {
    return CameraChangeRecord(
      id: json['id'] as String,
      areaId: json['areaId'] as String,
      areaName: json['areaName'] as String,
      changeType: CameraChangeType.values.firstWhere(
        (e) => e.name == json['changeType'],
        orElse: () => CameraChangeType.infoChanged,
      ),
      cameraName: json['cameraName'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      oldType: json['oldType'] as int?,
      newType: json['newType'] as int?,
      oldDate: json['oldDate'] as String?,
      newDate: json['newDate'] as String?,
      oldEdittime: json['oldEdittime'] as String?,
      newEdittime: json['newEdittime'] as String?,
      detectedAt: DateTime.tryParse(json['detectedAt'] as String? ?? '') ??
          DateTime.now(),
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'areaId': areaId,
      'areaName': areaName,
      'changeType': changeType.name,
      'cameraName': cameraName,
      'lat': lat,
      'lng': lng,
      'oldType': oldType,
      'newType': newType,
      'oldDate': oldDate,
      'newDate': newDate,
      'oldEdittime': oldEdittime,
      'newEdittime': newEdittime,
      'detectedAt': detectedAt.toIso8601String(),
      'description': description,
    };
  }

  static String formatType(int? type) {
    switch (type) {
      case 1:
        return '只拍晚高峰';
      case 2:
        return '六环内';
      case 4:
        return '待核实';
      case 5:
        return '晚高峰+六环内';
      case 6:
        return '六环外';
      default:
        return '未知';
    }
  }
}

/// 区域内摄像头的轻量快照项
class AreaCameraSnapshotItem {
  final String key;
  final String name;
  final double lat;
  final double lng;
  final int type;
  final String date;
  final String? edittime;
  final String href;

  AreaCameraSnapshotItem({
    required this.key,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.date,
    this.edittime,
    required this.href,
  });

  factory AreaCameraSnapshotItem.fromCamera(Camera camera) {
    return AreaCameraSnapshotItem(
      key: '${camera.lat.toStringAsFixed(6)},${camera.lng.toStringAsFixed(6)}_${camera.name}',
      name: camera.name,
      lat: camera.lat,
      lng: camera.lng,
      type: camera.type,
      date: camera.date,
      edittime: camera.edittime,
      href: camera.href,
    );
  }

  factory AreaCameraSnapshotItem.fromJson(Map<String, dynamic> json) {
    return AreaCameraSnapshotItem(
      key: json['key'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      type: json['type'] as int,
      date: json['date'] as String,
      edittime: json['edittime'] as String?,
      href: json['href'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'lat': lat,
      'lng': lng,
      'type': type,
      'date': date,
      if (edittime != null) 'edittime': edittime,
      'href': href,
    };
  }
}

/// 监控区域模型
class MonitoredArea {
  final String id;
  final String name;
  final AreaShapeType shapeType;
  // 圆形属性
  final double? centerLat;
  final double? centerLng;
  final double? radiusMeters;
  // 矩形属性
  final double? southWestLat;
  final double? southWestLng;
  final double? northEastLat;
  final double? northEastLng;
  // 状态与时间
  final DateTime createdAt;
  final bool enabled;
  final DateTime? lastCheckedAt;
  final int lastCameraCount;

  static const Distance _distance = Distance();

  MonitoredArea({
    required this.id,
    required this.name,
    required this.shapeType,
    this.centerLat,
    this.centerLng,
    this.radiusMeters,
    this.southWestLat,
    this.southWestLng,
    this.northEastLat,
    this.northEastLng,
    required this.createdAt,
    this.enabled = true,
    this.lastCheckedAt,
    this.lastCameraCount = 0,
  });

  /// 创建圆形监控区域
  factory MonitoredArea.circle({
    required String id,
    required String name,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    DateTime? createdAt,
    bool enabled = true,
    DateTime? lastCheckedAt,
    int lastCameraCount = 0,
  }) {
    return MonitoredArea(
      id: id,
      name: name,
      shapeType: AreaShapeType.circle,
      centerLat: centerLat,
      centerLng: centerLng,
      radiusMeters: radiusMeters,
      createdAt: createdAt ?? DateTime.now(),
      enabled: enabled,
      lastCheckedAt: lastCheckedAt,
      lastCameraCount: lastCameraCount,
    );
  }

  /// 创建矩形监控区域
  factory MonitoredArea.rectangle({
    required String id,
    required String name,
    required double southWestLat,
    required double southWestLng,
    required double northEastLat,
    required double northEastLng,
    DateTime? createdAt,
    bool enabled = true,
    DateTime? lastCheckedAt,
    int lastCameraCount = 0,
  }) {
    return MonitoredArea(
      id: id,
      name: name,
      shapeType: AreaShapeType.rectangle,
      southWestLat: southWestLat,
      southWestLng: southWestLng,
      northEastLat: northEastLat,
      northEastLng: northEastLng,
      createdAt: createdAt ?? DateTime.now(),
      enabled: enabled,
      lastCheckedAt: lastCheckedAt,
      lastCameraCount: lastCameraCount,
    );
  }

  /// 判断点位是否在当前监控区域内
  bool containsPoint(double lat, double lng) {
    if (shapeType == AreaShapeType.circle) {
      if (centerLat == null || centerLng == null || radiusMeters == null) {
        return false;
      }
      final d = _distance.as(
        LengthUnit.Meter,
        LatLng(centerLat!, centerLng!),
        LatLng(lat, lng),
      );
      return d <= radiusMeters!;
    } else {
      if (southWestLat == null ||
          southWestLng == null ||
          northEastLat == null ||
          northEastLng == null) {
        return false;
      }
      final minLat = southWestLat! < northEastLat! ? southWestLat! : northEastLat!;
      final maxLat = southWestLat! > northEastLat! ? southWestLat! : northEastLat!;
      final minLng = southWestLng! < northEastLng! ? southWestLng! : northEastLng!;
      final maxLng = southWestLng! > northEastLng! ? southWestLng! : northEastLng!;
      return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
    }
  }

  /// 形状描述文字（如 "圆形 · 3.0km" 或 "矩形 · 2.5km × 1.8km"）
  String get dimensionLabel {
    if (shapeType == AreaShapeType.circle) {
      final r = radiusMeters ?? 0;
      if (r >= 1000) {
        return '圆形半径 ${(r / 1000).toStringAsFixed(1)}km';
      }
      return '圆形半径 ${r.toStringAsFixed(0)}m';
    } else {
      return '矩形框选区域';
    }
  }

  MonitoredArea copyWith({
    String? name,
    bool? enabled,
    DateTime? lastCheckedAt,
    int? lastCameraCount,
    double? radiusMeters,
    double? centerLat,
    double? centerLng,
  }) {
    return MonitoredArea(
      id: id,
      name: name ?? this.name,
      shapeType: shapeType,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      southWestLat: southWestLat,
      southWestLng: southWestLng,
      northEastLat: northEastLat,
      northEastLng: northEastLng,
      createdAt: createdAt,
      enabled: enabled ?? this.enabled,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastCameraCount: lastCameraCount ?? this.lastCameraCount,
    );
  }

  factory MonitoredArea.fromJson(Map<String, dynamic> json) {
    return MonitoredArea(
      id: json['id'] as String,
      name: json['name'] as String,
      shapeType: json['shapeType'] == 'rectangle'
          ? AreaShapeType.rectangle
          : AreaShapeType.circle,
      centerLat: (json['centerLat'] as num?)?.toDouble(),
      centerLng: (json['centerLng'] as num?)?.toDouble(),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble(),
      southWestLat: (json['southWestLat'] as num?)?.toDouble(),
      southWestLng: (json['southWestLng'] as num?)?.toDouble(),
      northEastLat: (json['northEastLat'] as num?)?.toDouble(),
      northEastLng: (json['northEastLng'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      enabled: json['enabled'] as bool? ?? true,
      lastCheckedAt: json['lastCheckedAt'] != null
          ? DateTime.tryParse(json['lastCheckedAt'] as String)
          : null,
      lastCameraCount: (json['lastCameraCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shapeType': shapeType.name,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'radiusMeters': radiusMeters,
      'southWestLat': southWestLat,
      'southWestLng': southWestLng,
      'northEastLat': northEastLat,
      'northEastLng': northEastLng,
      'createdAt': createdAt.toIso8601String(),
      'enabled': enabled,
      'lastCheckedAt': lastCheckedAt?.toIso8601String(),
      'lastCameraCount': lastCameraCount,
    };
  }
}

/// 区域变动汇总结果
class AreaChangeSummary {
  final String areaId;
  final String areaName;
  final DateTime detectedAt;
  final List<CameraChangeRecord> records;

  AreaChangeSummary({
    required this.areaId,
    required this.areaName,
    required this.detectedAt,
    required this.records,
  });

  int get addedCount =>
      records.where((r) => r.changeType == CameraChangeType.added).length;
  int get removedCount =>
      records.where((r) => r.changeType == CameraChangeType.removed).length;
  int get typeChangedCount =>
      records.where((r) => r.changeType == CameraChangeType.typeChanged).length;
  int get infoChangedCount =>
      records.where((r) => r.changeType == CameraChangeType.infoChanged).length;
  int get totalChanges => records.length;

  factory AreaChangeSummary.fromJson(Map<String, dynamic> json) {
    return AreaChangeSummary(
      areaId: json['areaId'] as String,
      areaName: json['areaName'] as String,
      detectedAt: DateTime.tryParse(json['detectedAt'] as String? ?? '') ??
          DateTime.now(),
      records: (json['records'] as List? ?? [])
          .map((e) => CameraChangeRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'areaId': areaId,
      'areaName': areaName,
      'detectedAt': detectedAt.toIso8601String(),
      'records': records.map((e) => e.toJson()).toList(),
    };
  }
}
