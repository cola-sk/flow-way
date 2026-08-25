import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/beijing_pass_model.dart';
import 'api_service.dart';

/// 进京证查询结果响应
class BeijingPassFetchResult {
  final bool success;
  final String message;
  final bool isTokenInvalid;
  final List<BeijingPassVehicle> vehicles;
  final List<BeijingPassRecord> records;
  final BeijingPassRecord? activeRecord;

  const BeijingPassFetchResult({
    required this.success,
    required this.message,
    this.isTokenInvalid = false,
    this.vehicles = const [],
    this.records = const [],
    this.activeRecord,
  });

  factory BeijingPassFetchResult.failure(
    String message, {
    bool isTokenInvalid = false,
  }) {
    return BeijingPassFetchResult(
      success: false,
      message: message,
      isTokenInvalid: isTokenInvalid,
    );
  }

  factory BeijingPassFetchResult.success({
    List<BeijingPassVehicle> vehicles = const [],
    required List<BeijingPassRecord> records,
    BeijingPassRecord? activeRecord,
    String message = '查询成功',
  }) {
    return BeijingPassFetchResult(
      success: true,
      message: message,
      vehicles: vehicles,
      records: records,
      activeRecord: activeRecord,
    );
  }
}

/// 进京证申请结果响应
class BeijingPassApplyResult {
  final bool success;
  final String message;
  final bool isTokenInvalid;
  final String? applyId;

  const BeijingPassApplyResult({
    required this.success,
    required this.message,
    this.isTokenInvalid = false,
    this.applyId,
  });

  factory BeijingPassApplyResult.failure(
    String message, {
    bool isTokenInvalid = false,
  }) {
    return BeijingPassApplyResult(
      success: false,
      message: message,
      isTokenInvalid: isTokenInvalid,
    );
  }

  factory BeijingPassApplyResult.success({
    required String message,
    String? applyId,
  }) {
    return BeijingPassApplyResult(
      success: true,
      message: message,
      applyId: applyId,
    );
  }
}

/// 北京进京证服务管理类
class BeijingPassService {
  static const String _prefsKey = 'flow_way_beijing_pass_config_v1';
  static const String defaultApiBase = 'https://jjz.jtgl.beijing.gov.cn';

  final Dio _dio;
  final ApiService _apiService;

  BeijingPassService({Dio? dio, ApiService? apiService})
    : _apiService = apiService ?? ApiService(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 30),
              headers: {
                'Content-Type': 'application/json;charset=UTF-8',
                'Accept': 'application/json, text/plain, */*',
                if (!kIsWeb)
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/95.0.4638.74 Mobile Safari/537.36 MMWEBID/1234 MicroMessenger/8.0.18.2040(0x28001235) Process/appbrand0 WeChat/arm64 Weixin NetType/WIFI Language/zh_CN ABI/arm64',
                if (!kIsWeb)
                  'Origin': 'https://servicewechat.com/wx8b273767f4c3c6f2/',
                if (!kIsWeb)
                  'Referer':
                      'https://servicewechat.com/wx8b273767f4c3c6f2/123/page-frame.html',
              },
            ),
          );

  String _endpointUrl(BeijingPassConfig config, String operation) {
    if (kIsWeb) {
      return '${resolveApiBaseUrl()}/api/beijing-pass/$operation';
    }

    final baseUrl = config.customApiBase.trim().isNotEmpty
        ? config.customApiBase.trim()
        : defaultApiBase;
    return switch (operation) {
      'state-list' => '$baseUrl/pro/applyRecordController/stateList',
      'submit-apply' => '$baseUrl/pro/applyRecordController/insertApplyRecord',
      _ => throw ArgumentError.value(operation, 'operation', '不支持的进京证操作'),
    };
  }

  Future<Map<String, String>> _requestHeaders(String token) async {
    final headers = <String, String>{'Authorization': token};
    if (kIsWeb) {
      headers['x-user-token'] = await _apiService.ensureUserToken();
    }
    return headers;
  }

  String? _proxyUserTokenError(DioException error) {
    if (!kIsWeb) return null;
    final data = error.response?.data;
    if (data is! Map) return null;

    final code = data['errorCode']?.toString();
    final message = data['errorMessage']?.toString();
    if (code == 'TOKEN_EXPIRED') {
      return 'Flow Way 用户标识已到期${message == null || message.isEmpty ? '' : '：$message'}，请先续期后再查询';
    }
    if (code == 'TOKEN_INVALID') {
      return 'Flow Way 用户标识无效${message == null || message.isEmpty ? '' : '：$message'}，请先配置有效用户标识';
    }
    return null;
  }

  /// 加载本地保存的进京证配置
  Future<BeijingPassConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      return BeijingPassConfig.fromJsonString(jsonStr);
    }
    return const BeijingPassConfig();
  }

  /// 持久化保存进京证配置
  Future<bool> saveConfig(BeijingPassConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_prefsKey, config.toJsonString());
  }

  /// 清除本地配置
  Future<bool> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_prefsKey);
  }

  /// 解析 JWT Token 的到期时间（若为 JWT）
  static DateTime? parseTokenExpiry(String token) {
    try {
      final clean = token
          .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
          .trim();
      final parts = clean.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      // 补齐 Base64 填充
      final padLength = (4 - (payload.length % 4)) % 4;
      payload += '=' * padLength;
      final decodedStr = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decodedStr) as Map<String, dynamic>;
      if (map.containsKey('exp')) {
        final expSec = map['exp'];
        if (expSec is int) {
          return DateTime.fromMillisecondsSinceEpoch(expSec * 1000);
        }
      }
    } catch (_) {
      // 忽略非标准 JWT 解析错误
    }
    return null;
  }

  /// 查询进京证办证状态
  Future<BeijingPassFetchResult> fetchPassStatus(
    BeijingPassConfig config,
  ) async {
    if (!config.isTokenConfigured) {
      return BeijingPassFetchResult.failure(
        '未配置 Token，请先填入抓包获取的 Authorization',
      );
    }

    final token = config.token.trim();

    try {
      final response = await _dio.post(
        _endpointUrl(config, 'state-list'),
        options: Options(headers: await _requestHeaders(token)),
        // stateList 仅需 Authorization Token；服务端会返回该账号绑定的全部车辆。
        data: const <String, dynamic>{},
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        return BeijingPassFetchResult.failure(
          'Token 已过期或无效，请重新抓包获取并填入',
          isTokenInvalid: true,
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final code = data['code']?.toString() ?? data['resCode']?.toString();
        final msg =
            data['msg']?.toString() ??
            data['message']?.toString() ??
            data['resMsg']?.toString() ??
            '';

        if (code == '401' ||
            code == '403' ||
            msg.contains('未登录') ||
            msg.contains('token') ||
            msg.contains('重新登录')) {
          return BeijingPassFetchResult.failure(
            'Token 认证失效: $msg',
            isTokenInvalid: true,
          );
        }

        // 北京交警 stateList 当前返回 data.bzclxx[].bzxx[]：
        // bzclxx 是车辆列表，bzxx / ecbzxx 是办证记录列表。
        final rawData = data['data'] ?? data['rows'] ?? data['list'];
        final List<BeijingPassRecord> records = [];
        final List<BeijingPassVehicle> vehicles = [];

        if (rawData is List) {
          // 兼容旧版或自定义接口直接返回办证记录列表的情况。
          for (final item in rawData) {
            if (item is Map<String, dynamic>) {
              records.add(_parseRecord(item));
            }
          }
        } else if (rawData is Map) {
          final rawVehicles = rawData['bzclxx'];
          if (rawVehicles is List) {
            for (final vehicle in rawVehicles) {
              if (vehicle is! Map) continue;
              final vehicleMap = Map<String, dynamic>.from(vehicle);
              final vehicleRecords = <BeijingPassRecord>[];
              for (final recordListKey in const ['bzxx', 'ecbzxx']) {
                final permitRecords = vehicleMap[recordListKey];
                if (permitRecords is! List) continue;
                for (final item in permitRecords) {
                  if (item is Map) {
                    final record = _parseRecord(
                      Map<String, dynamic>.from(item),
                      vehicle: vehicleMap,
                    );
                    records.add(record);
                    vehicleRecords.add(record);
                  }
                }
              }
              vehicles.add(
                BeijingPassVehicle(
                  id:
                      vehicleMap['vId']?.toString() ??
                      vehicleMap['vid']?.toString() ??
                      '',
                  licensePlate: vehicleMap['hphm']?.toString() ?? '',
                  plateType: vehicleMap['hpzl']?.toString() ?? '',
                  vehicleType: vehicleMap['cllx']?.toString() ?? '',
                  records: vehicleRecords,
                ),
              );
            }
          }
        }

        // 筛选当前有效的或最新的记录
        BeijingPassRecord? active;
        if (records.isNotEmpty) {
          final valids = records.where((r) => r.isValidNow).toList();
          if (valids.isNotEmpty) {
            active = valids.first;
          } else {
            active = records.first;
          }
        }

        return BeijingPassFetchResult.success(
          vehicles: vehicles,
          records: records,
          activeRecord: active,
          message: msg.isNotEmpty ? msg : '查询成功',
        );
      }

      return BeijingPassFetchResult.failure('接口返回格式异常: ${response.data}');
    } on DioException catch (e) {
      final proxyUserTokenError = _proxyUserTokenError(e);
      if (proxyUserTokenError != null) {
        return BeijingPassFetchResult.failure(proxyUserTokenError);
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return BeijingPassFetchResult.failure(
          'Token 已失效 (HTTP ${e.response?.statusCode})，请重新抓包',
          isTokenInvalid: true,
        );
      }
      return BeijingPassFetchResult.failure(
        '请求接口失败: ${e.message ?? e.toString()}',
      );
    } catch (e) {
      return BeijingPassFetchResult.failure('查询异常: $e');
    }
  }

  /// 提交办证 / 一键续签申请
  Future<BeijingPassApplyResult> submitApplyRecord({
    required BeijingPassConfig config,
    required DateTime applyDate,
    int applyDays = 7,
  }) async {
    if (!config.isTokenConfigured) {
      return BeijingPassApplyResult.failure('未配置 Token，无法提交申请');
    }
    if (!config.isEssentialInfoComplete) {
      return BeijingPassApplyResult.failure('车辆必填信息不完整（车牌、发动机号、车架号、驾驶人信息）');
    }

    final token = config.token.trim();

    final applyDateStr =
        '${applyDate.year.toString().padLeft(4, '0')}-${applyDate.month.toString().padLeft(2, '0')}-${applyDate.day.toString().padLeft(2, '0')}';
    final applyEndDate = applyDate.add(Duration(days: applyDays - 1));
    final applyEndDateStr =
        '${applyEndDate.year.toString().padLeft(4, '0')}-${applyEndDate.month.toString().padLeft(2, '0')}-${applyEndDate.day.toString().padLeft(2, '0')}';

    // 字段名以 stateList 返回的北京交警字段为准；保留原字段用于兼容旧接口。
    final payload = {
      'hphm': config.licensePlate,
      if (config.plateType.isNotEmpty) 'hpzl': config.plateType,
      'vId': config.carId,
      'jjzzl': config.passType.officialCode,
      'sfzj': config.isInBeijing ? '1' : '0',
      if (config.isInBeijing) 'zjxxdz': config.inBeijingAddress,
      'txrxx': const <Object>[],
      // 参考官方小程序续办请求：当前页面暂不提供目的地/路况编码选择，使用默认“其它/其他道路”。
      'jjdq': '010',
      'jjmd': '06',
      'jjlk': '00606',
      'jjmdmc': '其它',
      'jjlkmc': '其他道路',
      'jjrq': applyDateStr,
      'yxqs': applyDateStr,
      'yxqz': applyEndDateStr,
      'sqsj': applyDateStr,
      'cllx': config.carModel,
      'fdjh': config.engineNo,
      'clsbdh': config.vin,
      'jsrxm': config.driverName,
      'jszh': config.driverLicence,
      'applyType': config.passType.code,
      'applyTime': applyDateStr,
      'applyDays': applyDays.toString(),
      'carId': config.carId,
      'licensePlate': config.licensePlate,
      'carModel': config.carModel,
      'engineNo': config.engineNo,
      'vin': config.vin,
      'driverName': config.driverName,
      'driverLicence': config.driverLicence,
      'entranceName': config.entranceName,
      'destination': config.destination,
    };

    try {
      final response = await _dio.post(
        _endpointUrl(config, 'submit-apply'),
        options: Options(headers: await _requestHeaders(token)),
        data: payload,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        return BeijingPassApplyResult.failure(
          'Token 已过期或无效，请重新配置 Token',
          isTokenInvalid: true,
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final code = data['code']?.toString() ?? data['resCode']?.toString();
        final msg =
            data['msg']?.toString() ??
            data['message']?.toString() ??
            data['resMsg']?.toString() ??
            '';

        if (code == '200' || code == '0' || msg.contains('成功')) {
          final applyId =
              data['data']?['id']?.toString() ??
              data['data']?['applyId']?.toString();
          return BeijingPassApplyResult.success(
            message: msg.isNotEmpty ? msg : '进京证申请已成功提交，请等待审核',
            applyId: applyId,
          );
        }

        if (code == '401' ||
            code == '403' ||
            msg.contains('未登录') ||
            msg.contains('token')) {
          return BeijingPassApplyResult.failure(
            'Token 认证失效: $msg',
            isTokenInvalid: true,
          );
        }

        return BeijingPassApplyResult.failure(
          msg.isNotEmpty ? msg : '提交申请失败（错误码: $code）',
        );
      }

      return BeijingPassApplyResult.failure('返回格式异常: ${response.data}');
    } on DioException catch (e) {
      final proxyUserTokenError = _proxyUserTokenError(e);
      if (proxyUserTokenError != null) {
        return BeijingPassApplyResult.failure(proxyUserTokenError);
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return BeijingPassApplyResult.failure(
          'Token 已失效 (HTTP ${e.response?.statusCode})',
          isTokenInvalid: true,
        );
      }
      return BeijingPassApplyResult.failure(
        '网络请求异常: ${e.message ?? e.toString()}',
      );
    } catch (e) {
      return BeijingPassApplyResult.failure('提交办证异常: $e');
    }
  }

  /// 内部解析单条办证记录
  BeijingPassRecord _parseRecord(
    Map<String, dynamic> json, {
    Map<String, dynamic>? vehicle,
  }) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        final s = val.toString().trim();
        if (s.isEmpty) return null;
        return DateTime.tryParse(s.replaceAll('/', '-'));
      } catch (_) {
        return null;
      }
    }

    final id =
        json['id']?.toString() ??
        json['applyId']?.toString() ??
        json['recordId']?.toString() ??
        '';
    final plate =
        json['licensePlate']?.toString() ??
        json['plateNumber']?.toString() ??
        json['hphm']?.toString() ??
        vehicle?['hphm']?.toString() ??
        '';
    final typeCode =
        json['applyType']?.toString() ??
        json['passType']?.toString() ??
        json['jjzzl']?.toString() ??
        '2';
    final typeName = json['jjzzlmc']?.toString() ?? '';
    final passType = typeName.contains('六环内')
        ? BeijingPassType.insideSixth
        : typeName.contains('六环外')
        ? BeijingPassType.outsideSixth
        : BeijingPassTypeExt.fromCode(typeCode);

    final start = parseDate(
      json['applyTime'] ??
          json['validPeriodStart'] ??
          json['startDate'] ??
          json['applyStartDate'] ??
          json['yxqs'] ??
          json['sxrqmc'],
    );
    final end = parseDate(
      json['validPeriodEnd'] ??
          json['endDate'] ??
          json['applyEndDate'] ??
          json['yxqz'] ??
          json['sxrzmc'],
    );

    final statusStr =
        json['status']?.toString() ??
        json['applyStatus']?.toString() ??
        json['blzt']?.toString() ??
        '';
    final statusDesc =
        json['statusDesc']?.toString() ??
        json['applyStatusDesc']?.toString() ??
        json['blztmc']?.toString() ??
        '';

    BeijingPassStatus status = BeijingPassStatus.unknown;
    if (statusStr == '1' ||
        statusDesc.contains('通过') ||
        statusDesc.contains('生效')) {
      status = BeijingPassStatus.valid;
    } else if (statusStr == '0' || statusDesc.contains('审核中')) {
      status = BeijingPassStatus.reviewing;
    } else if (statusStr == '2' ||
        statusDesc.contains('拒绝') ||
        statusDesc.contains('未通过')) {
      status = BeijingPassStatus.rejected;
    } else if (statusStr == '3' ||
        statusDesc.contains('失效') ||
        statusDesc.contains('过期')) {
      status = BeijingPassStatus.expired;
    }

    final total =
        int.tryParse(
          json['totalCount']?.toString() ??
              vehicle?['ybcs']?.toString() ??
              '12',
        ) ??
        12;
    final used =
        int.tryParse(
          json['usedCount']?.toString() ?? vehicle?['sycs']?.toString() ?? '0',
        ) ??
        0;

    return BeijingPassRecord(
      id: id,
      licensePlate: plate,
      passType: passType,
      startDate: start,
      endDate: end,
      status: status,
      statusDesc: statusDesc.isNotEmpty ? statusDesc : status.label,
      totalCount: total,
      usedCount: used,
      rawJson: jsonEncode(json),
    );
  }
}
