import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/camera.dart';
import '../models/route.dart';
import 'package:latlong2/latlong.dart';

const String _cameraCacheKey = 'camera_response_v1';
const int _cameraCacheTtlMs = 24 * 60 * 60 * 1000;
const String _localWayPointsKey = 'local_waypoints_v1';
const String _localRoutePlansKey = 'local_route_plans_v1';

String _resolveBaseUrl() {
  if (kIsWeb) {
    // Web 端：Chrome 本地开发用 localhost:3000，部署到生产域名时用当前 origin 的 server
    final origin = Uri.base.origin;
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      return 'http://localhost:3000';
    }
    return 'https://flow-way.tz0618.uk';
  }
  // 原生端（Android / iOS）直接打生产接口
  return 'https://flow-way.tz0618.uk';
}

String _formatError(Object e) {
  if (e is DioException) {
    final resp = e.response;
    if (resp != null) {
      return '[${resp.statusCode}] ${resp.statusMessage} — ${resp.data}';
    }
    return '${e.type.name}: ${e.message}';
  }
  return e.toString();
}

class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: _resolveBaseUrl(),
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  String _makeLocalId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 20);
    return 'local-$prefix-$now-$rnd';
  }

  Future<List<Map<String, dynamic>>> _readLocalList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeLocalList(String key, List<Map<String, dynamic>> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<bool> _saveWayPointToLocal({
    required String name,
    required LatLng location,
  }) async {
    try {
      final list = await _readLocalList(_localWayPointsKey);
      final item = <String, dynamic>{
        'id': _makeLocalId('wp'),
        'name': name,
        'lat': location.latitude,
        'lng': location.longitude,
        'createdAt': DateTime.now().toIso8601String(),
      };

      list.insert(0, item);
      await _writeLocalList(_localWayPointsKey, list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<WayPoint>> _getLocalWayPoints() async {
    final list = await _readLocalList(_localWayPointsKey);
    return list.map(WayPoint.fromJson).toList();
  }

  Future<bool> _deleteLocalWayPoint(String id) async {
    try {
      final list = await _readLocalList(_localWayPointsKey);
      final before = list.length;
      list.removeWhere((e) => (e['id'] as String?) == id);
      if (list.length == before) return false;
      await _writeLocalList(_localWayPointsKey, list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _saveRoutePlanToLocal({
    required String name,
    required PlaceResult start,
    required PlaceResult end,
    required List<PlaceResult> waypoints,
    required bool avoidCameras,
  }) async {
    try {
      Map<String, dynamic> toPoint(PlaceResult p) => {
            'name': p.name,
            'address': p.address,
            'lat': p.location.latitude,
            'lng': p.location.longitude,
          };

      final list = await _readLocalList(_localRoutePlansKey);
      final item = <String, dynamic>{
        'id': _makeLocalId('plan'),
        'name': name,
        'start': toPoint(start),
        'end': toPoint(end),
        'waypoints': waypoints.map(toPoint).toList(),
        'avoidCameras': avoidCameras,
        'createdAt': DateTime.now().toIso8601String(),
      };

      list.insert(0, item);
      await _writeLocalList(_localRoutePlansKey, list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<SavedRoutePlanRecord>> _getLocalRoutePlans() async {
    final list = await _readLocalList(_localRoutePlansKey);
    return list.map(SavedRoutePlanRecord.fromJson).toList();
  }

  Future<bool> _deleteLocalRoutePlan(String id) async {
    try {
      final list = await _readLocalList(_localRoutePlansKey);
      final before = list.length;
      list.removeWhere((e) => (e['id'] as String?) == id);
      if (list.length == before) return false;
      await _writeLocalList(_localRoutePlansKey, list);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CamerasResponse?> _readCachedCameras({
    required bool allowExpired,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cameraCacheKey);
      if (raw == null || raw.isEmpty) return null;

      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return null;

      final savedAtUtcMs = parsed['savedAtUtcMs'];
      final expiresAtUtcMs = parsed['expiresAtUtcMs'];
      final data = parsed['data'];
      if (data is! Map<String, dynamic>) return null;

      final nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      bool isExpired;
      if (savedAtUtcMs is int) {
        isExpired = nowUtcMs - savedAtUtcMs >= _cameraCacheTtlMs;
      } else if (expiresAtUtcMs is int) {
        // 兼容历史缓存结构
        isExpired = nowUtcMs >= expiresAtUtcMs;
      } else {
        isExpired = true;
      }

      if (isExpired && !allowExpired) return null;

      return CamerasResponse.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedCameras(CamerasResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final nowUtc = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'savedAtUtcMs': nowUtc.millisecondsSinceEpoch,
      'data': response.toJson(),
    };
    await prefs.setString(_cameraCacheKey, jsonEncode(payload));
  }

  /// 获取所有摄像头数据
  /// 策略：每次启动时检查缓存是否超过 24 小时；
  /// 未过期直接返回，过期则请求接口并更新缓存。
  Future<CamerasResponse> getCameras({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedFresh = await _readCachedCameras(allowExpired: false);
      if (cachedFresh != null) return cachedFresh;
    }

    try {
      final response = await _dio.get('/api/cameras');
      final parsed = CamerasResponse.fromJson(response.data as Map<String, dynamic>);
      await _writeCachedCameras(parsed);
      return parsed;
    } catch (e) {
      final cachedExpired = await _readCachedCameras(allowExpired: true);
      if (cachedExpired != null) return cachedExpired;
      throw Exception('加载摄像头数据失败: ${_formatError(e)}');
    }
  }

  /// 强制重新爬取摄像头并更新缓存
  Future<CamerasResponse> recrawlCameras() async {
    try {
      final response = await _dio.post('/api/cameras');
      final parsed = CamerasResponse.fromJson(response.data as Map<String, dynamic>);
      await _writeCachedCameras(parsed);
      return parsed;
    } catch (e) {
      throw Exception('重新爬取摄像头失败: ${_formatError(e)}');
    }
  }

  /// 规划路线（支持避开摄像头的智能路由）
  /// [start] 起点坐标
  /// [end] 终点坐标
  /// [avoidCameras] 是否尽量避开摄像头（废弃摄像头由服务端自动排除）
  Future<RouteResponse> planRoute({
    required LatLng start,
    required LatLng end,
    bool avoidCameras = false,
    bool ignoreOutsideSixthRing = false,
  }) async {
    try {
      final response = await _dio.post('/api/route/plan', data: {
        'start': {
          'lat': start.latitude,
          'lng': start.longitude,
        },
        'end': {
          'lat': end.latitude,
          'lng': end.longitude,
        },
        'avoidCameras': avoidCameras,
        'ignoreOutsideSixthRing': ignoreOutsideSixthRing,
      });
      return RouteResponse.fromJson(response.data);
    } catch (e) {
      final msg = '路线规划失败: ${_formatError(e)}';
      print(msg);
      return RouteResponse(errorMessage: msg);
    }
  }

  /// 单步路线规划（每次只请求一轮，便于前端逐轮绘制）
  Future<RouteStepResponse> planRouteStep({
    required LatLng start,
    required LatLng end,
    required int iteration,
    required int maxIterations,
    bool ignoreOutsideSixthRing = false,
    NavigationRoute? bestRoute,
    double? anchorDistance,
    List<LatLng>? waypoints,
    int? legIndex,
    int? totalLegs,
  }) async {
    try {
      final response = await _dio.post('/api/route/plan-step', data: {
        'start': {
          'lat': start.latitude,
          'lng': start.longitude,
        },
        'end': {
          'lat': end.latitude,
          'lng': end.longitude,
        },
        'iteration': iteration,
        'maxIterations': maxIterations,
        if (waypoints != null)
          'waypoints': waypoints
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
        if (legIndex != null) 'legIndex': legIndex,
        if (totalLegs != null) 'totalLegs': totalLegs,
        if (anchorDistance != null) 'anchorDistance': anchorDistance,
        'ignoreOutsideSixthRing': ignoreOutsideSixthRing,
        if (bestRoute != null) 'bestRoute': {
          'polylinePoints': bestRoute.polylinePoints
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
          'distance': bestRoute.distance,
          'duration': bestRoute.duration,
          'cameraIndicesOnRoute': bestRoute.cameraIndicesOnRoute,
        },
      });
      return RouteStepResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      final msg = '路线单步规划失败: ${_formatError(e)}';
      print(msg);
      return RouteStepResponse(
        iteration: iteration,
        maxIterations: maxIterations,
        done: true,
        errorMessage: msg,
      );
    }
  }

  /// 保存标记点
  Future<bool> saveWayPoint({
    required String name,
    required LatLng location,
  }) async {
    try {
      await _dio.post('/api/waypoints', data: {
        'name': name,
        'lat': location.latitude,
        'lng': location.longitude,
      });

      // Keep a local cache copy after remote persistence succeeds.
      await _saveWayPointToLocal(name: name, location: location);
      return true;
    } catch (e) {
      print('保存标记点失败: ${_formatError(e)}');

      // Best-effort local backup, but report failure to avoid masking DB issues.
      await _saveWayPointToLocal(name: name, location: location);
      return false;
    }
  }

  /// 获取用户保存的标记点
  Future<List<WayPoint>> getWayPoints() async {
    final local = await _getLocalWayPoints();

    try {
      final response = await _dio.get('/api/waypoints');
      final List<dynamic> data = response.data['waypoints'] ?? [];
      final remote = data
          .map((item) => WayPoint.fromJson(item as Map<String, dynamic>))
          .toList();

      final merged = <String, WayPoint>{};
      for (final wp in [...remote, ...local]) {
        final key = '${wp.name}_${wp.location.latitude.toStringAsFixed(6)}_${wp.location.longitude.toStringAsFixed(6)}';
        merged[key] = wp;
      }
      final result = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (e) {
      print('获取标记点失败: ${_formatError(e)}');
      return local..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  /// 删除标记点
  Future<bool> deleteWayPoint(String id) async {
    if (id.startsWith('local-')) {
      return _deleteLocalWayPoint(id);
    }

    final localDeleted = await _deleteLocalWayPoint(id);
    try {
      await _dio.delete('/api/waypoints/$id');
      return true;
    } catch (e) {
      print('删除标记点失败: ${_formatError(e)}');
      return localDeleted;
    }
  }

  /// 搜索建议词（输入时自动补全）
  Future<List<PlaceResult>> suggestPlaces(
    String keyword, {
    LatLng? nearBy,
  }) async {
    try {
      final params = <String, dynamic>{'keyword': keyword};
      if (nearBy != null) {
        params['lat'] = nearBy.latitude;
        params['lng'] = nearBy.longitude;
      }
      final response = await _dio.get('/api/suggest', queryParameters: params);
      final List<dynamic> data = response.data['suggestions'] ?? [];
      return data
          .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('搜索建议失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 搜索地点（关键词 + 可选当前坐标用于附近优先）
  Future<List<PlaceResult>> searchPlaces(
    String keyword, {
    LatLng? nearBy,
  }) async {
    try {
      final params = <String, dynamic>{'keyword': keyword};
      if (nearBy != null) {
        params['lat'] = nearBy.latitude;
        params['lng'] = nearBy.longitude;
      }
      final response = await _dio.get('/api/search', queryParameters: params);
      final List<dynamic> data = response.data['results'] ?? [];
      return data
          .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('搜索地点失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 逆地理编码：通过坐标反查地点名称
  Future<PlaceResult?> reverseGeocode({
    required LatLng point,
  }) async {
    try {
      final response = await _dio.get(
        '/api/reverse-geocode',
        queryParameters: {
          'lat': point.latitude,
          'lng': point.longitude,
        },
      );
      final data = response.data['place'];
      if (data is! Map<String, dynamic>) return null;
      return PlaceResult.fromJson(data);
    } catch (e) {
      print('逆地理编码失败: ${_formatError(e)}');
      return null;
    }
  }

  /// 保存导航线路（含规划后的折线）
  Future<bool> saveNavigationRoute({
    required NavigationRoute route,
    required String name,
    List<PlaceResult>? stops,
  }) async {
    try {
      await _dio.post('/api/saved-routes', data: {
        'name': name,
        'route': route.toJson(),
        if (stops != null)
          'stops': stops
              .map(
                (p) => {
                  'name': p.name,
                  'address': p.address,
                  'lat': p.location.latitude,
                  'lng': p.location.longitude,
                },
              )
              .toList(),
      });
      return true;
    } catch (e) {
      print('保存导航线路失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 保存起点/终点/途径点方案
  Future<bool> saveRoutePlanPoints({
    required String name,
    required PlaceResult start,
    required PlaceResult end,
    required List<PlaceResult> waypoints,
    required bool avoidCameras,
  }) async {
    final localSaved = await _saveRoutePlanToLocal(
      name: name,
      start: start,
      end: end,
      waypoints: waypoints,
      avoidCameras: avoidCameras,
    );

    try {
      Map<String, dynamic> toPoint(PlaceResult p) => {
            'name': p.name,
            'address': p.address,
            'lat': p.location.latitude,
            'lng': p.location.longitude,
          };

      await _dio.post('/api/saved-route-plans', data: {
        'name': name,
        'start': toPoint(start),
        'end': toPoint(end),
        'waypoints': waypoints.map(toPoint).toList(),
        'avoidCameras': avoidCameras,
      });
      return true;
    } catch (e) {
      print('保存点位方案失败: ${_formatError(e)}');
      return localSaved;
    }
  }

  /// 获取已保存的导航线路
  Future<List<SavedNavigationRouteRecord>> getSavedNavigationRoutes() async {
    try {
      final response = await _dio.get('/api/saved-routes');
      final List<dynamic> data = response.data['routes'] ?? [];
      return data
          .map((e) => SavedNavigationRouteRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取已保存线路失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 删除已保存线路
  Future<bool> deleteSavedNavigationRoute(String id) async {
    try {
      await _dio.delete('/api/saved-routes/$id');
      return true;
    } catch (e) {
      print('删除已保存线路失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 获取已保存的起终点/途径点方案
  Future<List<SavedRoutePlanRecord>> getSavedRoutePlans() async {
    final local = await _getLocalRoutePlans();

    try {
      final response = await _dio.get('/api/saved-route-plans');
      final List<dynamic> data = response.data['plans'] ?? [];
      final remote = data
          .map((e) => SavedRoutePlanRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      final merged = <String, SavedRoutePlanRecord>{};
      for (final plan in [...remote, ...local]) {
        final wpKey = plan.waypoints
            .map((w) => '${w.location.latitude.toStringAsFixed(6)},${w.location.longitude.toStringAsFixed(6)}')
            .join(';');
        final key = '${plan.name}_${plan.start.location.latitude.toStringAsFixed(6)},${plan.start.location.longitude.toStringAsFixed(6)}_${plan.end.location.latitude.toStringAsFixed(6)},${plan.end.location.longitude.toStringAsFixed(6)}_${plan.avoidCameras}_$wpKey';
        merged[key] = plan;
      }
      final result = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (e) {
      print('获取点位方案失败: ${_formatError(e)}');
      return local..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  /// 删除已保存点位方案
  Future<bool> deleteSavedRoutePlan(String id) async {
    if (id.startsWith('local-')) {
      return _deleteLocalRoutePlan(id);
    }

    final localDeleted = await _deleteLocalRoutePlan(id);
    try {
      await _dio.delete('/api/saved-route-plans/$id');
      return true;
    } catch (e) {
      print('删除点位方案失败: ${_formatError(e)}');
      return localDeleted;
    }
  }

  /// 保存最近导航记录
  Future<bool> saveRecentNavigation({
    required String name,
    required PlaceResult start,
    required PlaceResult end,
    required List<PlaceResult> waypoints,
    required bool avoidCameras,
    String? source,
  }) async {
    try {
      Map<String, dynamic> toPoint(PlaceResult p) => {
            'name': p.name,
            'address': p.address,
            'lat': p.location.latitude,
            'lng': p.location.longitude,
          };

      await _dio.post('/api/recent-navigations', data: {
        'name': name,
        'start': toPoint(start),
        'end': toPoint(end),
        'waypoints': waypoints.map(toPoint).toList(),
        'avoidCameras': avoidCameras,
        if (source != null) 'source': source,
      });
      return true;
    } catch (e) {
      print('保存最近导航失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 获取最近导航记录
  Future<List<RecentNavigationRecord>> getRecentNavigations() async {
    try {
      final response = await _dio.get('/api/recent-navigations');
      final List<dynamic> data = response.data['records'] ?? [];
      return data
          .map((e) => RecentNavigationRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取最近导航失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 删除最近导航记录
  Future<bool> deleteRecentNavigation(String id) async {
    try {
      await _dio.delete('/api/recent-navigations/$id');
      return true;
    } catch (e) {
      print('删除最近导航失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 获取废弃摄像头列表
  Future<List<DismissedCamera>> getDismissedCameras() async {
    try {
      final response = await _dio.get('/api/dismissed-cameras');
      final List<dynamic> data = response.data['dismissed'] ?? [];
      return data
          .map((e) => DismissedCamera.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取废弃摄像头失败: ${_formatError(e)}');
      return [];
    }
  }

  /// 标记摄像头为废弃（保存到服务端 Redis）
  Future<bool> markCameraDismissed({
    required double lat,
    required double lng,
    required String name,
  }) async {
    try {
      await _dio.post('/api/dismissed-cameras',
          data: {'lat': lat, 'lng': lng, 'name': name});
      return true;
    } catch (e) {
      print('标记废弃失败: ${_formatError(e)}');
      return false;
    }
  }

  /// 取消废弃标记
  Future<bool> unmarkCameraDismissed({
    required double lat,
    required double lng,
  }) async {
    try {
      await _dio.delete('/api/dismissed-cameras',
          data: {'lat': lat, 'lng': lng});
      return true;
    } catch (e) {
      print('取消废弃失败: ${_formatError(e)}');
      return false;
    }
  }
}

class PlaceResult {
  final String name;
  final String address;
  final LatLng location;

  PlaceResult({
    required this.name,
    required this.address,
    required this.location,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
    );
  }
}

class SavedCoordinate {
  final String name;
  final String address;
  final LatLng location;

  SavedCoordinate({
    required this.name,
    required this.address,
    required this.location,
  });

  factory SavedCoordinate.fromJson(Map<String, dynamic> json) {
    return SavedCoordinate(
      name: json['name'] as String? ?? '未命名地点',
      address: json['address'] as String? ?? '',
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
    );
  }

  PlaceResult toPlaceResult() => PlaceResult(
        name: name,
        address: address,
        location: location,
      );
}

class SavedNavigationRouteRecord {
  final String id;
  final String name;
  final NavigationRoute route;
  final List<SavedCoordinate> stops;
  final DateTime createdAt;

  SavedNavigationRouteRecord({
    required this.id,
    required this.name,
    required this.route,
    required this.stops,
    required this.createdAt,
  });

  factory SavedNavigationRouteRecord.fromJson(Map<String, dynamic> json) {
    final List<dynamic> stopsData = json['stops'] as List<dynamic>? ?? const [];
    return SavedNavigationRouteRecord(
      id: json['id'] as String,
      name: json['name'] as String? ?? '未命名线路',
      route: NavigationRoute.fromJson(json['route'] as Map<String, dynamic>),
      stops: stopsData
          .map((e) => SavedCoordinate.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class SavedRoutePlanRecord {
  final String id;
  final String name;
  final SavedCoordinate start;
  final SavedCoordinate end;
  final List<SavedCoordinate> waypoints;
  final bool avoidCameras;
  final DateTime createdAt;

  SavedRoutePlanRecord({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.waypoints,
    required this.avoidCameras,
    required this.createdAt,
  });

  factory SavedRoutePlanRecord.fromJson(Map<String, dynamic> json) {
    final List<dynamic> waypointsData =
        json['waypoints'] as List<dynamic>? ?? const [];
    return SavedRoutePlanRecord(
      id: json['id'] as String,
      name: json['name'] as String? ?? '未命名点位方案',
      start: SavedCoordinate.fromJson(json['start'] as Map<String, dynamic>),
      end: SavedCoordinate.fromJson(json['end'] as Map<String, dynamic>),
      waypoints: waypointsData
          .map((e) => SavedCoordinate.fromJson(e as Map<String, dynamic>))
          .toList(),
      avoidCameras: json['avoidCameras'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class RecentNavigationRecord {
  final String id;
  final String name;
  final SavedCoordinate start;
  final SavedCoordinate end;
  final List<SavedCoordinate> waypoints;
  final bool avoidCameras;
  final String source;
  final DateTime createdAt;

  RecentNavigationRecord({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.waypoints,
    required this.avoidCameras,
    required this.source,
    required this.createdAt,
  });

  factory RecentNavigationRecord.fromJson(Map<String, dynamic> json) {
    final List<dynamic> waypointsData =
        json['waypoints'] as List<dynamic>? ?? const [];
    return RecentNavigationRecord(
      id: json['id'] as String,
      name: json['name'] as String? ?? '未命名最近导航',
      start: SavedCoordinate.fromJson(json['start'] as Map<String, dynamic>),
      end: SavedCoordinate.fromJson(json['end'] as Map<String, dynamic>),
      waypoints: waypointsData
          .map((e) => SavedCoordinate.fromJson(e as Map<String, dynamic>))
          .toList(),
      avoidCameras: json['avoidCameras'] as bool? ?? false,
      source: json['source'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DismissedCamera {
  final double lat;
  final double lng;
  final String name;
  final String markedAt;

  DismissedCamera({
    required this.lat,
    required this.lng,
    required this.name,
    required this.markedAt,
  });

  factory DismissedCamera.fromJson(Map<String, dynamic> json) {
    return DismissedCamera(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      name: json['name'] as String,
      markedAt: json['markedAt'] as String? ?? '',
    );
  }
}

