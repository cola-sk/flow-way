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

  ApiService get apiService => _apiService;

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

  /// 根据进京/在京详细地址自动解析所属北京行政区名（如“昌平区”）
  static String extractDistrict(String address) {
    const districts = [
      '东城区',
      '西城区',
      '朝阳区',
      '丰台区',
      '石景山区',
      '海淀区',
      '门头沟区',
      '房山区',
      '通州区',
      '顺义区',
      '昌平区',
      '大兴区',
      '怀柔区',
      '平谷区',
      '密云区',
      '延庆区',
    ];
    final trimmed = address.trim();
    if (trimmed.isEmpty) return '昌平区';
    for (final d in districts) {
      if (trimmed.contains(d)) return d;
    }
    for (final d in districts) {
      final nameWithoutQu = d.substring(0, d.length - 1);
      if (trimmed.contains(nameWithoutQu)) return d;
    }
    return '昌平区';
  }

  /// 构建符合北京交警 insertApplyRecord 官方接口规范的请求负载
  static Map<String, dynamic> buildApplyPayload({
    required BeijingPassConfig config,
    required DateTime applyDate,
    String? applyIdOld,
    String? vId,
  }) {
    final applyDateStr =
        '${applyDate.year.toString().padLeft(4, '0')}-${applyDate.month.toString().padLeft(2, '0')}-${applyDate.day.toString().padLeft(2, '0')}';

    final effectiveVId = (vId != null && vId.trim().isNotEmpty)
        ? vId.trim()
        : config.carId.trim();
    final inBjAddress = config.inBeijingAddress.trim().isNotEmpty
        ? config.inBeijingAddress.trim()
        : '昌平北站';
    final district = extractDistrict(inBjAddress);

    final gdjd = double.tryParse(config.sqdzgdjd.trim()) ?? 116.231525;
    final gdwd = double.tryParse(config.sqdzgdwd.trim()) ?? 40.231452;
    final bdjd = double.tryParse(config.sqdzbdjd.trim()) ?? 116.237936;
    final bdwd = double.tryParse(config.sqdzbdwd.trim()) ?? 40.237461;

    final hpzl = config.plateType.trim().isNotEmpty
        ? config.plateType.trim()
        : (config.licensePlate.trim().length >= 8 ? '52' : '02');
    final driverLicence = config.driverLicence.trim();
    final driverName = config.driverName.trim();

    // 目的地与进京目的字典严格配对（01: 自驾旅游，06: 其它）
    final isTravel = config.destination.trim() == '自驾旅游';
    final jjmd = isTravel ? '01' : '06';
    final jjmdmc = isTravel ? '自驾旅游' : '其它';

    // 进京道口字典严格配对（00401: 京藏高速，00606: 其他道路）
    final isJingzang = config.entranceName.trim() == '京藏高速';
    final jjlk = isJingzang ? '00401' : '00606';
    final jjlkmc = isJingzang ? '京藏高速' : '其他道路';

    final payload = <String, dynamic>{
      'dabh': 'null',
      'hphm': config.licensePlate.trim(),
      'hpzl': hpzl,
      'vId': effectiveVId,
      'jjdq': district,
      'jjlk': jjlk,
      'jjlkmc': jjlkmc,
      'jjmd': jjmd,
      'jjmdmc': jjmdmc,
      'jjrq': applyDateStr,
      'jjzzl': config.passType.officialCode,
      'jsrxm': driverName,
      'jszh': driverLicence,
      'sfzmhm': driverLicence,
      'xxdz': inBjAddress,
      'sqdzbdjd': bdjd,
      'sqdzbdwd': bdwd,
      'sqdzgdjd': gdjd,
      'sqdzgdwd': gdwd,
      'txrxx': const <dynamic>[],
      'sfzj': config.isInBeijing ? '1' : '0',
    };

    if (config.isInBeijing) {
      payload['zjxxdz'] = inBjAddress;
    }
    if (applyIdOld != null && applyIdOld.trim().isNotEmpty) {
      payload['applyIdOld'] = applyIdOld.trim();
    }

    return payload;
  }

  static String? _checkWafOrHtmlResponse(
    dynamic responseData,
    int? statusCode,
  ) {
    if (statusCode == 405) {
      return '上游交警服务拦截了请求（WAF 405）。Web 预览端受海外节点网络限制，请在 Android 手机客户端运行使用。';
    }
    if (responseData is String) {
      final s = responseData.toLowerCase();
      if (s.contains('<!doctype html') ||
          s.contains('<html') ||
          s.contains('damddos') ||
          s.contains('method not allowed')) {
        return '上游交警服务拦截了网络请求（防火墙阻断）。Web 预览端受海外节点限制，请在 Android 手机客户端运行使用。';
      }
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

      final wafErr = _checkWafOrHtmlResponse(
        response.data,
        response.statusCode,
      );
      if (wafErr != null) {
        return BeijingPassFetchResult.failure(wafErr);
      }

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
      final wafErr = _checkWafOrHtmlResponse(
        e.response?.data,
        e.response?.statusCode,
      );
      if (wafErr != null) {
        return BeijingPassFetchResult.failure(wafErr);
      }
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
    String? applyIdOld,
    String? vId,
  }) async {
    if (!config.isTokenConfigured) {
      return BeijingPassApplyResult.failure('未配置 Token，无法提交申请');
    }
    final effectiveVId = (vId != null && vId.trim().isNotEmpty)
        ? vId.trim()
        : config.carId.trim();
    if (config.licensePlate.trim().isEmpty) {
      return BeijingPassApplyResult.failure('未指定车牌号码');
    }
    if (config.driverName.trim().isEmpty ||
        config.driverLicence.trim().isEmpty) {
      return BeijingPassApplyResult.failure('请先填写驾驶人姓名与身份证/驾驶证号');
    }
    // 若未绑定交管系统车辆 ID，则需要发动机号与车架号
    if (effectiveVId.isEmpty &&
        (config.engineNo.trim().isEmpty || config.vin.trim().isEmpty)) {
      return BeijingPassApplyResult.failure('车辆未绑定且缺少发动机号/车架号');
    }

    final token = config.token.trim();
    final payload = buildApplyPayload(
      config: config,
      applyDate: applyDate,
      applyIdOld: applyIdOld,
      vId: vId,
    );

    try {
      final response = await _dio.post(
        _endpointUrl(config, 'submit-apply'),
        options: Options(headers: await _requestHeaders(token)),
        data: payload,
      );

      final wafErr = _checkWafOrHtmlResponse(
        response.data,
        response.statusCode,
      );
      if (wafErr != null) {
        return BeijingPassApplyResult.failure(wafErr);
      }

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
      final wafErr = _checkWafOrHtmlResponse(
        e.response?.data,
        e.response?.statusCode,
      );
      if (wafErr != null) {
        return BeijingPassApplyResult.failure(wafErr);
      }
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

    final driverName =
        json['jsrxm']?.toString() ??
        json['driverName']?.toString() ??
        '';
    final driverLicence =
        json['jszh']?.toString() ??
        json['sfzmhm']?.toString() ??
        json['driverLicence']?.toString() ??
        '';

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
      driverName: driverName,
      driverLicence: driverLicence,
      rawJson: jsonEncode(json),
    );
  }
}
