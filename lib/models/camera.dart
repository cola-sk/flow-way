/// 摄像头数据模型
class Camera {
  final String name;
  final double lng;
  final double lat;
  final int type;
  final String date;
  final String href;

  Camera({
    required this.name,
    required this.lng,
    required this.lat,
    required this.type,
    required this.date,
    required this.href,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      name: json['name'] as String,
      lng: (json['lng'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      type: json['type'] as int,
      date: json['date'] as String,
      href: json['href'] as String? ?? '',
    );
  }

  /// 是否为最近 7 天新增（date 字段距今 < 7 天）
  bool get isNewlyAdded {
    if (date.isEmpty) return false;
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return false;
    return DateTime.now().difference(parsed).inDays < 7;
  }

  /// 是否处于试用期（name 包含"试用期"字眼）
  bool get isPilot => name.contains('试用期');

  /// 类型描述
  String get typeLabel {
    switch (type) {
      case 1:
        return '只拍晚高峰';
      case 2:
        return '六环内（全时段）';
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

class CamerasResponse {
  final List<Camera> cameras;
  final String updatedAt;
  final int total;

  CamerasResponse({
    required this.cameras,
    required this.updatedAt,
    required this.total,
  });

  factory CamerasResponse.fromJson(Map<String, dynamic> json) {
    return CamerasResponse(
      cameras: (json['cameras'] as List)
          .map((e) => Camera.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updatedAt'] as String,
      total: json['total'] as int,
    );
  }
}
