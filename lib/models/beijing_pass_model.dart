import 'dart:convert';

/// 进京证类型
enum BeijingPassType {
  /// 六环外（不限次数，每次7天）
  outsideSixth,

  /// 六环内（每年限12次，每次7天）
  insideSixth,
}

extension BeijingPassTypeExt on BeijingPassType {
  String get code {
    switch (this) {
      case BeijingPassType.outsideSixth:
        return '2';
      case BeijingPassType.insideSixth:
        return '1';
    }
  }

  String get label {
    switch (this) {
      case BeijingPassType.outsideSixth:
        return '六环外进京通行证（不限次数）';
      case BeijingPassType.insideSixth:
        return '六环内进京通行证（每年限12次）';
    }
  }

  /// 北京交警接口使用的两位证件类型码。
  String get officialCode {
    switch (this) {
      case BeijingPassType.outsideSixth:
        return '02';
      case BeijingPassType.insideSixth:
        return '01';
    }
  }

  String get shortLabel {
    switch (this) {
      case BeijingPassType.outsideSixth:
        return '六环外通行证';
      case BeijingPassType.insideSixth:
        return '六环内通行证';
    }
  }

  static BeijingPassType fromCode(String? code) {
    if (code == '1') {
      return BeijingPassType.insideSixth;
    }
    return BeijingPassType.outsideSixth;
  }
}

/// 进京证状态
enum BeijingPassStatus {
  /// 审核中
  reviewing,

  /// 已生效/已通过
  valid,

  /// 审核未通过
  rejected,

  /// 已过期/已失效
  expired,

  /// 未知
  unknown,
}

extension BeijingPassStatusExt on BeijingPassStatus {
  String get label {
    switch (this) {
      case BeijingPassStatus.reviewing:
        return '审核中';
      case BeijingPassStatus.valid:
        return '已生效';
      case BeijingPassStatus.rejected:
        return '未通过';
      case BeijingPassStatus.expired:
        return '已失效';
      case BeijingPassStatus.unknown:
        return '未办理/未知';
    }
  }
}

/// 进京证申请预填配置
class BeijingPassConfig {
  /// 北京交警 Authorization Token
  final String token;

  /// 车牌号 (例如 冀A88888)
  final String licensePlate;

  /// 号牌种类（北京交警接口字段 hpzl）
  final String plateType;

  /// 车型 (例如 小型普通客车)
  final String carModel;

  /// 发动机号
  final String engineNo;

  /// 车架号/VIN后6位或完整VIN
  final String vin;

  /// 车辆ID（交管系统绑定的carId，若有可填，没有则可留空）
  final String carId;

  /// 驾驶人姓名
  final String driverName;

  /// 驾驶人身份证/驾驶证号
  final String driverLicence;

  /// 进京类型
  final BeijingPassType passType;

  /// 进京道口名称
  final String entranceName;

  /// 进京目的地
  final String destination;

  /// 提交办理时是否已在北京（接口字段 sfzj）。
  final bool isInBeijing;

  /// 已在京时的详细地址（接口字段 zjxxdz / xxdz）。
  final String inBeijingAddress;

  /// 社区地址高德经度（接口字段 sqdzgdjd）。
  final String sqdzgdjd;

  /// 社区地址高德纬度（接口字段 sqdzgdwd）。
  final String sqdzgdwd;

  /// 社区地址百度经度（接口字段 sqdzbdjd）。
  final String sqdzbdjd;

  /// 社区地址百度纬度（接口字段 sqdzbdwd）。
  final String sqdzbdwd;

  /// 自定义接口 Base URL（若留空则使用官方默认）
  final String customApiBase;

  /// 按车辆 ID 保存的办证补充资料。
  final Map<String, BeijingPassVehicleSupplement> vehicleSupplements;

  const BeijingPassConfig({
    this.token = '',
    this.licensePlate = '',
    this.plateType = '',
    this.carModel = '小型普通客车',
    this.engineNo = '',
    this.vin = '',
    this.carId = '',
    this.driverName = '',
    this.driverLicence = '',
    this.passType = BeijingPassType.outsideSixth,
    this.entranceName = '其他道路',
    this.destination = '其它',
    this.isInBeijing = false,
    this.inBeijingAddress = '昌平北站',
    this.sqdzgdjd = '116.231525',
    this.sqdzgdwd = '40.231452',
    this.sqdzbdjd = '116.237936',
    this.sqdzbdwd = '40.237461',
    this.customApiBase = '',
    this.vehicleSupplements = const {},
  });

  BeijingPassConfig copyWith({
    String? token,
    String? licensePlate,
    String? plateType,
    String? carModel,
    String? engineNo,
    String? vin,
    String? carId,
    String? driverName,
    String? driverLicence,
    BeijingPassType? passType,
    String? entranceName,
    String? destination,
    bool? isInBeijing,
    String? inBeijingAddress,
    String? sqdzgdjd,
    String? sqdzgdwd,
    String? sqdzbdjd,
    String? sqdzbdwd,
    String? customApiBase,
    Map<String, BeijingPassVehicleSupplement>? vehicleSupplements,
  }) {
    return BeijingPassConfig(
      token: token ?? this.token,
      licensePlate: licensePlate ?? this.licensePlate,
      plateType: plateType ?? this.plateType,
      carModel: carModel ?? this.carModel,
      engineNo: engineNo ?? this.engineNo,
      vin: vin ?? this.vin,
      carId: carId ?? this.carId,
      driverName: driverName ?? this.driverName,
      driverLicence: driverLicence ?? this.driverLicence,
      passType: passType ?? this.passType,
      entranceName: entranceName ?? this.entranceName,
      destination: destination ?? this.destination,
      isInBeijing: isInBeijing ?? this.isInBeijing,
      inBeijingAddress: inBeijingAddress ?? this.inBeijingAddress,
      sqdzgdjd: sqdzgdjd ?? this.sqdzgdjd,
      sqdzgdwd: sqdzgdwd ?? this.sqdzgdwd,
      sqdzbdjd: sqdzbdjd ?? this.sqdzbdjd,
      sqdzbdwd: sqdzbdwd ?? this.sqdzbdwd,
      customApiBase: customApiBase ?? this.customApiBase,
      vehicleSupplements: vehicleSupplements ?? this.vehicleSupplements,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'licensePlate': licensePlate,
      'plateType': plateType,
      'carModel': carModel,
      'engineNo': engineNo,
      'vin': vin,
      'carId': carId,
      'driverName': driverName,
      'driverLicence': driverLicence,
      'passType': passType.code,
      'entranceName': entranceName,
      'destination': destination,
      'isInBeijing': isInBeijing,
      'inBeijingAddress': inBeijingAddress,
      'sqdzgdjd': sqdzgdjd,
      'sqdzgdwd': sqdzgdwd,
      'sqdzbdjd': sqdzbdjd,
      'sqdzbdwd': sqdzbdwd,
      'customApiBase': customApiBase,
      'vehicleSupplements': vehicleSupplements.map(
        (vehicleId, supplement) => MapEntry(vehicleId, supplement.toJson()),
      ),
    };
  }

  factory BeijingPassConfig.fromJson(Map<String, dynamic> json) {
    final addr = (json['inBeijingAddress'] as String?)?.trim() ?? '';
    return BeijingPassConfig(
      token: (json['token'] as String?)?.trim() ?? '',
      licensePlate: (json['licensePlate'] as String?)?.trim() ?? '',
      plateType: (json['plateType'] as String?)?.trim() ?? '',
      carModel: (json['carModel'] as String?)?.trim() ?? '小型普通客车',
      engineNo: (json['engineNo'] as String?)?.trim() ?? '',
      vin: (json['vin'] as String?)?.trim() ?? '',
      carId: (json['carId'] as String?)?.trim() ?? '',
      driverName: (json['driverName'] as String?)?.trim() ?? '',
      driverLicence: (json['driverLicence'] as String?)?.trim() ?? '',
      passType: BeijingPassTypeExt.fromCode(json['passType'] as String?),
      entranceName: (json['entranceName'] as String?)?.trim() ?? '其他道路',
      destination: (json['destination'] as String?)?.trim() ?? '其它',
      isInBeijing: json['isInBeijing'] == true,
      inBeijingAddress: addr.isNotEmpty ? addr : '昌平北站',
      sqdzgdjd: (json['sqdzgdjd'] as String?)?.trim() ?? '116.231525',
      sqdzgdwd: (json['sqdzgdwd'] as String?)?.trim() ?? '40.231452',
      sqdzbdjd: (json['sqdzbdjd'] as String?)?.trim() ?? '116.237936',
      sqdzbdwd: (json['sqdzbdwd'] as String?)?.trim() ?? '40.237461',
      customApiBase: (json['customApiBase'] as String?)?.trim() ?? '',
      vehicleSupplements: _parseVehicleSupplements(json['vehicleSupplements']),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory BeijingPassConfig.fromJsonString(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return BeijingPassConfig.fromJson(map);
    } catch (_) {
      return const BeijingPassConfig();
    }
  }

  static Map<String, BeijingPassVehicleSupplement> _parseVehicleSupplements(
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    final supplements = <String, BeijingPassVehicleSupplement>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      supplements[entry.key as String] = BeijingPassVehicleSupplement.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return supplements;
  }

  bool get isTokenConfigured => token.trim().isNotEmpty;

  /// 车辆及驾驶人信息是否满足提交办证的基本要求。
  /// 若已绑定交管系统车辆 ID (carId)，官方接口只需车牌与驾驶人身份即可提交；
  /// 若未绑定车辆 ID，则需要发动机号与车架号进行核验。
  bool get isEssentialInfoComplete {
    final hasPlate = licensePlate.trim().isNotEmpty;
    final hasDriver =
        driverName.trim().isNotEmpty && driverLicence.trim().isNotEmpty;
    if (!hasPlate || !hasDriver) return false;
    if (carId.trim().isNotEmpty) return true;
    return engineNo.trim().isNotEmpty && vin.trim().isNotEmpty;
  }
}

/// 只在提交办证时使用、且与某一车辆绑定的补充资料。
class BeijingPassVehicleSupplement {
  final String carModel;
  final String engineNo;
  final String vin;
  final String driverName;
  final String driverLicence;

  const BeijingPassVehicleSupplement({
    this.carModel = '',
    this.engineNo = '',
    this.vin = '',
    this.driverName = '',
    this.driverLicence = '',
  });

  Map<String, dynamic> toJson() => {
    'carModel': carModel,
    'engineNo': engineNo,
    'vin': vin,
    'driverName': driverName,
    'driverLicence': driverLicence,
  };

  factory BeijingPassVehicleSupplement.fromJson(Map<String, dynamic> json) {
    return BeijingPassVehicleSupplement(
      carModel: (json['carModel'] as String?)?.trim() ?? '',
      engineNo: (json['engineNo'] as String?)?.trim() ?? '',
      vin: (json['vin'] as String?)?.trim() ?? '',
      driverName: (json['driverName'] as String?)?.trim() ?? '',
      driverLicence: (json['driverLicence'] as String?)?.trim() ?? '',
    );
  }
}

/// 进京证办证记录
class BeijingPassRecord {
  final String id;
  final String licensePlate;
  final BeijingPassType passType;
  final DateTime? startDate;
  final DateTime? endDate;
  final BeijingPassStatus status;
  final String statusDesc;
  final int totalCount;
  final int usedCount;
  final String driverName;
  final String driverLicence;
  final String rawJson;

  const BeijingPassRecord({
    this.id = '',
    this.licensePlate = '',
    this.passType = BeijingPassType.outsideSixth,
    this.startDate,
    this.endDate,
    this.status = BeijingPassStatus.unknown,
    this.statusDesc = '',
    this.totalCount = 0,
    this.usedCount = 0,
    this.driverName = '',
    this.driverLicence = '',
    this.rawJson = '',
  });

  /// 距离到期还剩多少天（若已过期返回负数或 0）
  int get remainingDays {
    if (endDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final diff = end.difference(today).inDays;
    return diff >= 0 ? diff + 1 : 0;
  }

  /// 是否当前有效（在有效期内且状态为 valid）
  bool get isValidNow {
    if (status != BeijingPassStatus.valid ||
        startDate == null ||
        endDate == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  /// 建议的下一次续签起始日期
  DateTime get suggestedNextStartDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (endDate != null && endDate!.isAfter(today)) {
      // 顺延到现有进京证结束日期的次日
      return DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
      ).add(const Duration(days: 1));
    }
    // 默认明天（避免当天中午12点后无法办理限制）
    return today.add(const Duration(days: 1));
  }
}

/// Token 查询返回的已绑定车辆及其办证记录。
class BeijingPassVehicle {
  final String id;
  final String licensePlate;
  final String plateType;
  final String vehicleType;
  final List<BeijingPassRecord> records;

  const BeijingPassVehicle({
    this.id = '',
    this.licensePlate = '',
    this.plateType = '',
    this.vehicleType = '',
    this.records = const [],
  });

  /// 当前生效的进京证记录（isValidNow == true）。
  /// 若没有任何生效中的记录，则返回最新的历史记录（可能已过期/被拒绝）；
  /// 若 records 为空则返回 null。
  /// **注意**：使用前必须检查 isValidNow，不能假设返回值一定是有效记录。
  BeijingPassRecord? get activeRecord {
    for (final record in records) {
      if (record.isValidNow) return record;
    }
    return records.isEmpty ? null : records.first;
  }

  String get displayName {
    final plate = licensePlate.isEmpty ? '未命名车辆' : licensePlate;
    return vehicleType.isEmpty ? plate : '$plate · $vehicleType';
  }

  /// 从该车辆历史记录中获取最近填写的驾驶人姓名
  String get lastDriverName {
    for (final record in records) {
      if (record.driverName.trim().isNotEmpty) return record.driverName.trim();
    }
    return '';
  }

  /// 从该车辆历史记录中获取最近填写的驾驶人身份证/驾驶证号
  String get lastDriverLicence {
    for (final record in records) {
      if (record.driverLicence.trim().isNotEmpty) {
        return record.driverLicence.trim();
      }
    }
    return '';
  }
}
