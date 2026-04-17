import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/camera.dart';
import '../models/route.dart';
import '../services/api_service.dart';
import '../widgets/jinjing_marker.dart';

enum _BottomTab { explore, plan, saved, recent }

class _NavStopItem {
  final PlaceResult place;
  final bool fromMyLocation;

  const _NavStopItem({required this.place, this.fromMyLocation = false});

  String get id =>
      '${place.name}_${place.location.latitude}_${place.location.longitude}_$fromMyLocation';
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  static const Color _surface = Color(0xFFF9F9F8);
  static const Color _surfaceCard = Color(0xFFFAFAF7);
  static const Color _surfaceVariant = Color(0xFFE2E3E1);
  static const Color _primary = Color(0xFF6E5E0D);
  static const Color _primaryContainer = Color(0xFFFDE68A);
  static const Color _secondary = Color(0xFF855300);
  static const Color _onSurface = Color(0xFF1A1C1B);
  static const Color _onSurfaceVariant = Color(0xFF4B4738);

  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  List<Camera> _cameras = [];
  List<WayPoint> _wayPoints = [];
  bool _loading = true;
  String? _error;
  String _updatedAt = '';

  // 当前导航路线
  NavigationRoute? _currentRoute;
  bool _isNavigating = false;
  bool _stopPlanningRequested = false;
  int _planningIteration = 0;
  static const int _planStepMaxIterations = 1000000000;
  static const int _minPlanStepIntervalMs = 500;
  int _lastPlanStepRequestAtMs = 0;
  String? _planningStatus;
  // 路线上无法绕开的摄像头索引（仅 avoidCameras=true 时有效）
  Set<int> _unavoidableCameraIndices = {};

  // 从服务端加载的废弃摄像头坐标集合（格式 "lat.toFixed6,lng.toFixed6"）
  final Set<String> _dismissedCoords = {};

  // 北京中心坐标 (GCJ-02)
  static const _beijingCenter = LatLng(39.9042, 116.4074);

  // 用户当前位置
  LatLng? _userPosition;

  // 搜索状态
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _suggestDebounce;
  List<PlaceResult> _suggestions = [];
  bool _isSuggesting = false;
  bool _showSuggestions = false;
  PlaceResult? _selectedPlace;

  // 定位状态：定位完成（成功或失败）后才显示摄像头
  bool _locationResolved = false;

  // 导航模式状态
  // _navSearchTarget: null=普通搜索 / 'end'=搜索终点 / 'waypoint'=搜索途径点
  bool _navMode = false;
  bool _navStartIsMyLocation = true;
  PlaceResult? _navStartPlace;
  PlaceResult? _navEndPlace;
  final List<PlaceResult> _navWaypoints = [];
  bool _avoidCameras = true;
  String? _navSearchTarget;
  bool _navPanelCollapsed = false;
  _BottomTab _activeTab = _BottomTab.explore;

  List<SavedNavigationRouteRecord> _savedRoutes = [];
  List<SavedRoutePlanRecord> _savedRoutePlans = [];
  bool _loadingSaved = false;
  String? _savedError;

  List<RecentNavigationRecord> _recentNavigations = [];
  bool _loadingRecent = false;
  String? _recentError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCameras();
    _loadWayPoints();
    _loadDismissedCameras();
    _locateUser();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _requestStopPlanning('应用切到后台，正在停止...');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _suggestDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    try {
      // 先检查设备级定位服务开关
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请先开启设备定位服务（GPS）')));
          setState(() => _locationResolved = true);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationResolved = true);
        return;
      }

      // 优先用上次缓存位置快速定位（Web 不支持此 API）
      if (!kIsWeb) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          final pos = LatLng(lastKnown.latitude, lastKnown.longitude);
          setState(() {
            _userPosition = pos;
            _locationResolved = true;
          });
          _mapController.move(pos, 17);
        }
      }

      // 再获取精确位置：Android 用 AndroidSettings，Web/iOS 用通用 LocationSettings
      final LocationSettings locationSettings = kIsWeb
          ? const LocationSettings(accuracy: LocationAccuracy.high)
          : AndroidSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 40),
              forceLocationManager: false,
            );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      if (mounted) {
        final pos = LatLng(position.latitude, position.longitude);
        setState(() {
          _userPosition = pos;
          _locationResolved = true;
        });
        _mapController.move(pos, 17);
      }
    } catch (e) {
      // 定位失败时保持默认北京中心，仍然解锁摄像头显示
      print('定位失败: $e');
      if (mounted) setState(() => _locationResolved = true);
    }
  }

  void _fetchSuggestions(String keyword) {
    _suggestDebounce?.cancel();
    if (keyword.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSuggesting = true);
      final results = await _apiService.suggestPlaces(
        keyword,
        nearBy: _userPosition,
      );
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSuggesting = false;
          _showSuggestions = true;
        });
      }
    });
  }

  Future<void> _selectSuggestion(PlaceResult suggestion) async {
    _searchFocusNode.unfocus();
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    // 用 search 接口获取精确地点信息
    final results = await _apiService.searchPlaces(
      suggestion.name,
      nearBy: _userPosition,
    );
    final place = results.isNotEmpty ? results.first : suggestion;
    if (!mounted) return;

    if (_navSearchTarget == 'start') {
      // 导航模式下选中起点
      setState(() {
        _navStartIsMyLocation = false;
        _navStartPlace = place;
        _navSearchTarget = null;
        _selectedPlace = null;
        _searchController.clear();
      });
      _mapController.move(place.location, 15);
    } else if (_navSearchTarget == 'end') {
      // 导航模式下选中终点
      setState(() {
        _navEndPlace = place;
        _navSearchTarget = null;
        _selectedPlace = null;
        _searchController.clear();
      });
      _mapController.move(place.location, 15);
    } else if (_navSearchTarget == 'waypoint') {
      // 导航模式下选中途径点
      setState(() {
        _navWaypoints.add(place);
        _navSearchTarget = null;
        _selectedPlace = null;
        _searchController.clear();
      });
    } else {
      // 普通搜索 -> 显示地点 marker
      _searchController.text = suggestion.name;
      setState(() => _selectedPlace = place);
      _mapController.move(place.location, 16);
    }
  }

  String _formatLatLng(LatLng point) {
    return '${point.longitude.toStringAsFixed(6)}, ${point.latitude.toStringAsFixed(6)}';
  }

  PlaceResult _buildMapPointPlace(LatLng point) {
    return PlaceResult(
      name: '地图选点',
      address: _formatLatLng(point),
      location: point,
    );
  }

  Future<void> _addNavWaypointFromPlace(PlaceResult place) async {
    var waypoint = place;

    // 地图点选默认名称较泛化，先尝试反查真实地点名；失败则保留现有兜底文案。
    if (place.name == '地图选点') {
      final resolved = await _apiService.reverseGeocode(point: place.location);
      if (resolved != null) {
        waypoint = resolved;
      }
    }

    if (!mounted) return;

    if (!_navMode) {
      _enterNavMode(startIsMyLocation: true, waypoints: [waypoint]);
    } else {
      setState(() {
        _navWaypoints.add(waypoint);
        _navSearchTarget = null;
        _searchController.text = waypoint.name;
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已添加途径点: ${waypoint.name}')));
  }

  void _showMapPointActions(LatLng point) {
    _showPlaceActions(_buildMapPointPlace(point));
  }

  Future<PlaceResult> _resolveMapPointPlaceName(PlaceResult place) async {
    if (place.name != '地图选点') {
      return place;
    }

    final resolved = await _apiService.reverseGeocode(point: place.location);
    if (resolved == null || resolved.name.trim().isEmpty) {
      return place;
    }
    return resolved;
  }

  Future<void> _setEndPlaceFromAction(PlaceResult place) async {
    final resolvedPlace = await _resolveMapPointPlaceName(place);
    if (!mounted) return;

    final wasNavMode = _navMode;
    _searchController.text = resolvedPlace.name;
    _searchFocusNode.unfocus();

    setState(() {
      _navMode = true;
      _activeTab = _BottomTab.plan;
      _navEndPlace = resolvedPlace;
      _navSearchTarget = null;

      if (!wasNavMode) {
        _navStartIsMyLocation = true;
        _navStartPlace = null;
        _navWaypoints.clear();
      }

      _selectedPlace = null;
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  Future<void> _setStartPlaceFromAction(PlaceResult place) async {
    final resolvedPlace = await _resolveMapPointPlaceName(place);
    if (!mounted) return;

    final wasNavMode = _navMode;
    _searchController.text = resolvedPlace.name;
    _searchFocusNode.unfocus();

    setState(() {
      _navMode = true;
      _activeTab = _BottomTab.plan;
      _navStartIsMyLocation = false;
      _navStartPlace = resolvedPlace;
      _navSearchTarget = null;

      if (!wasNavMode) {
        _navEndPlace = null;
        _navWaypoints.clear();
      }

      _selectedPlace = null;
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  void _showPlaceActions(PlaceResult place) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (place.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  place.address,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _setEndPlaceFromAction(place);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _primary.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('去这里'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _setStartPlaceFromAction(place);
                      },
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('从这里出发'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _addNavWaypointFromPlace(place);
                  },
                  icon: const Icon(Icons.add_road_rounded, size: 16),
                  label: const Text('作为途径点'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _enterNavMode({
    PlaceResult? startPlace,
    PlaceResult? endPlace,
    bool startIsMyLocation = true,
    List<PlaceResult>? waypoints,
  }) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _navMode = true;
      _activeTab = _BottomTab.plan;
      _navPanelCollapsed = false;
      _navStartIsMyLocation = startIsMyLocation;
      _navStartPlace = startPlace;
      _navEndPlace = endPlace;
      _navWaypoints
        ..clear()
        ..addAll(waypoints ?? const []);
      _selectedPlace = null;
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  void _exitNavMode({_BottomTab nextTab = _BottomTab.explore}) {
    setState(() {
      _navMode = false;
      _activeTab = nextTab;
      _navPanelCollapsed = false;
      _navStartPlace = null;
      _navEndPlace = null;
      _navWaypoints.clear();
      _navSearchTarget = null;
      _currentRoute = null;
      _unavoidableCameraIndices = {};
      _planningIteration = 0;
      _planningStatus = null;
      _searchController.clear();
    });
  }

  void _switchTab(_BottomTab tab) {
    if (tab == _activeTab &&
        (tab == _BottomTab.explore ||
            tab == _BottomTab.plan ||
            tab == _BottomTab.saved ||
            tab == _BottomTab.recent)) {
      if (tab == _BottomTab.saved) {
        _loadSavedData(silent: true);
      } else if (tab == _BottomTab.recent) {
        _loadRecentData(silent: true);
      }
      return;
    }

    if (tab == _BottomTab.plan) {
      if (!_navMode) {
        _enterNavMode();
      } else {
        setState(() => _activeTab = tab);
      }
      return;
    }

    if (_navMode) {
      _exitNavMode(nextTab: tab);
    } else {
      setState(() => _activeTab = tab);
    }

    if (tab == _BottomTab.saved) {
      _loadSavedData();
    } else if (tab == _BottomTab.recent) {
      _loadRecentData();
    }
  }

  Future<void> _startNavigation() async {
    if (_isNavigating) return;

    if (_navEndPlace == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先设置终点')));
      return;
    }

    final stopItems = _buildNavStopItems();
    final orderedPoints = stopItems.map((item) => item.place.location).toList();
    if (orderedPoints.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少设置起点和终点')));
      return;
    }

    final start = stopItems.first.place;
    final end = stopItems.last.place;
    final waypoints = stopItems.length > 2
        ? stopItems
              .sublist(1, stopItems.length - 1)
              .map((e) => e.place)
              .toList()
        : <PlaceResult>[];
    unawaited(
      _recordRecentNavigation(
        start: start,
        end: end,
        waypoints: waypoints,
        avoidCameras: _avoidCameras,
        source: 'start_navigation',
      ),
    );

    _searchFocusNode.unfocus();
    setState(() {
      _navPanelCollapsed = true;
      _navSearchTarget = null;
      _showSuggestions = false;
      _suggestions = [];
    });

    _stopPlanningRequested = false;
    await _planRouteWithStops(orderedPoints, _avoidCameras);
  }

  void _toggleNavPanelCollapsed() {
    final next = !_navPanelCollapsed;
    if (next) {
      _searchFocusNode.unfocus();
    }
    setState(() {
      _navPanelCollapsed = next;
      if (next) {
        _navSearchTarget = null;
        _showSuggestions = false;
        _suggestions = [];
      }
    });
  }

  String _navCompactSummary() {
    final startName = _resolvedNavStartPlace().name;
    final endName = _navEndPlace?.name ?? '未设置终点';
    final wpCount = _navWaypoints.length;
    final wpText = wpCount == 0 ? '' : ' · $wpCount个途径点';
    return '$startName -> $endName$wpText';
  }

  void _requestStopPlanning([String status = '正在停止...']) {
    if (!_isNavigating || _stopPlanningRequested) return;
    setState(() {
      _stopPlanningRequested = true;
      _planningStatus = status;
    });
  }

  String _saveNameTimestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }

  String _formatRecentCreatedAt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<String?> _promptSaveName({
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入名称',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _savedWaypointSummary({
    required String startName,
    required String endName,
    required List<String> waypointNames,
  }) {
    if (waypointNames.isEmpty) {
      return '$startName -> $endName';
    }
    if (waypointNames.length == 1) {
      return '$startName -> ${waypointNames.first} -> $endName';
    }
    return '$startName -> ${waypointNames.first} -> .... -> $endName';
  }

  Future<void> _saveCurrentRoute() async {
    final route = _currentRoute;
    if (route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可保存的导航线路，请先完成一次导航规划')));
      return;
    }

    final stops = _buildNavStopItems().map((item) => item.place).toList();
    final startName = stops.isNotEmpty ? stops.first.name : '起点';
    final endName = stops.length >= 2 ? stops.last.name : '终点';
    final defaultName = '$startName -> $endName ${_saveNameTimestamp()}';
    final inputName = await _promptSaveName(
      title: '保存线路名称',
      initialValue: defaultName,
    );
    if (!mounted || inputName == null) return;
    final routeName = inputName.trim().isEmpty ? defaultName : inputName.trim();

    final ok = await _apiService.saveNavigationRoute(
      route: route,
      name: routeName,
      stops: stops,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '线路已保存' : '保存线路失败')));
  }

  Future<void> _saveCurrentRoutePlanPoints() async {
    final end = _navEndPlace;
    if (end == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先设置终点后再保存点位方案')));
      return;
    }

    final start = _resolvedNavStartPlace();
    final waypoints = List<PlaceResult>.from(_navWaypoints);
    final defaultName = '${start.name} -> ${end.name} ${_saveNameTimestamp()}';
    final inputName = await _promptSaveName(
      title: '保存点位方案名称',
      initialValue: defaultName,
    );
    if (!mounted || inputName == null) return;
    final planName = inputName.trim().isEmpty ? defaultName : inputName.trim();

    final ok = await _apiService.saveRoutePlanPoints(
      name: planName,
      start: start,
      end: end,
      waypoints: waypoints,
      avoidCameras: _avoidCameras,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? '点位方案已保存' : '保存点位方案失败')));
  }

  PlaceResult _placeFromSavedCoordinate(SavedCoordinate c) {
    return PlaceResult(name: c.name, address: c.address, location: c.location);
  }

  List<PlaceResult> _stopsFromSavedRoute(SavedNavigationRouteRecord record) {
    if (record.stops.isNotEmpty) {
      return record.stops.map(_placeFromSavedCoordinate).toList();
    }
    return [
      PlaceResult(
        name: '起点',
        address: _formatLatLng(record.route.startPoint),
        location: record.route.startPoint,
      ),
      PlaceResult(
        name: '终点',
        address: _formatLatLng(record.route.endPoint),
        location: record.route.endPoint,
      ),
    ];
  }

  Future<void> _loadSavedData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingSaved = true;
        _savedError = null;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.getSavedNavigationRoutes(),
        _apiService.getSavedRoutePlans(),
      ]);

      if (!mounted) return;
      setState(() {
        _savedRoutes = results[0] as List<SavedNavigationRouteRecord>;
        _savedRoutePlans = results[1] as List<SavedRoutePlanRecord>;
        _loadingSaved = false;
        _savedError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSaved = false;
        _savedError = '加载保存列表失败: $e';
      });
    }
  }

  Future<void> _deleteSavedRoute(SavedNavigationRouteRecord record) async {
    final ok = await _apiService.deleteSavedNavigationRoute(record.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _savedRoutes.removeWhere((item) => item.id == record.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除保存线路')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除保存线路失败')));
    }
  }

  Future<void> _deleteSavedRoutePlan(SavedRoutePlanRecord plan) async {
    final ok = await _apiService.deleteSavedRoutePlan(plan.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _savedRoutePlans.removeWhere((item) => item.id == plan.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除点位方案')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除点位方案失败')));
    }
  }

  void _applySavedRouteToNavigation(SavedNavigationRouteRecord record) {
    final stops = _stopsFromSavedRoute(record);
    final start = stops.first;
    final end = stops.length >= 2 ? stops.last : start;
    final waypoints = stops.length > 2
        ? stops.sublist(1, stops.length - 1)
        : <PlaceResult>[];

    setState(() {
      _navMode = true;
      _activeTab = _BottomTab.plan;
      _navPanelCollapsed = false;
      _navStartIsMyLocation = false;
      _navStartPlace = start;
      _navEndPlace = end;
      _navWaypoints
        ..clear()
        ..addAll(waypoints);
      _avoidCameras = record.route.routeType == 'avoid_cameras';
      _currentRoute = record.route;
      _unavoidableCameraIndices = record.route.cameraIndicesOnRoute.toSet();
      _navSearchTarget = null;
      _selectedPlace = null;
      _showSuggestions = false;
      _suggestions = [];
      _searchController.clear();
    });
    unawaited(
      _recordRecentNavigation(
        start: start,
        end: end,
        waypoints: waypoints,
        avoidCameras: record.route.routeType == 'avoid_cameras',
        source: 'apply_saved_route',
      ),
    );
    _fitRouteToMap(record.route);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已将保存线路应用到导航模式')));
  }

  void _applySavedRoutePlanToNavigation(SavedRoutePlanRecord plan) {
    final start = _placeFromSavedCoordinate(plan.start);
    final end = _placeFromSavedCoordinate(plan.end);
    final waypoints = plan.waypoints.map(_placeFromSavedCoordinate).toList();

    setState(() {
      _navMode = true;
      _activeTab = _BottomTab.plan;
      _navPanelCollapsed = false;
      _navStartIsMyLocation = false;
      _navStartPlace = start;
      _navEndPlace = end;
      _navWaypoints
        ..clear()
        ..addAll(waypoints);
      _avoidCameras = plan.avoidCameras;
      _currentRoute = null;
      _unavoidableCameraIndices = {};
      _navSearchTarget = null;
      _selectedPlace = null;
      _showSuggestions = false;
      _suggestions = [];
      _searchController.clear();
    });
    _fitPlacesToMap([start, ...waypoints, end]);
    unawaited(
      _recordRecentNavigation(
        start: start,
        end: end,
        waypoints: waypoints,
        avoidCameras: plan.avoidCameras,
        source: 'apply_saved_plan',
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已将点位方案应用到导航模式')));
  }

  void _showSavedRouteDetail(SavedNavigationRouteRecord record) {
    final stops = _stopsFromSavedRoute(record);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _infoRow(
              '类型',
              record.route.routeType == 'avoid_cameras' ? '避开摄像头' : '普通',
            ),
            _infoRow(
              '里程',
              '${(record.route.distance / 1000).toStringAsFixed(1)} km',
            ),
            _infoRow('时长', '${(record.route.duration / 60).round()} 分钟'),
            _infoRow('点位', '${stops.length} 个'),
            const SizedBox(height: 10),
            ...stops
                .take(4)
                .map(
                  (p) => Text(
                    '• ${p.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showSavedRoutePlanDetail(SavedRoutePlanRecord plan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _infoRow('起点', plan.start.name),
            _infoRow('终点', plan.end.name),
            _infoRow('途径点', '${plan.waypoints.length} 个'),
            _infoRow('避开摄像头', plan.avoidCameras ? '是' : '否'),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRecentData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingRecent = true;
        _recentError = null;
      });
    }

    try {
      final data = await _apiService.getRecentNavigations();
      if (!mounted) return;
      setState(() {
        _recentNavigations = data;
        _loadingRecent = false;
        _recentError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRecent = false;
        _recentError = '加载最近记录失败: $e';
      });
    }
  }

  Future<void> _deleteRecentNavigation(RecentNavigationRecord record) async {
    final ok = await _apiService.deleteRecentNavigation(record.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _recentNavigations.removeWhere((item) => item.id == record.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除最近记录')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除最近记录失败')));
    }
  }

  Future<void> _recordRecentNavigation({
    required PlaceResult start,
    required PlaceResult end,
    required List<PlaceResult> waypoints,
    required bool avoidCameras,
    required String source,
  }) async {
    final name = '${start.name} -> ${end.name} ${_saveNameTimestamp()}';
    await _apiService.saveRecentNavigation(
      name: name,
      start: start,
      end: end,
      waypoints: waypoints,
      avoidCameras: avoidCameras,
      source: source,
    );
  }

  void _applyRecentNavigationToNavigation(RecentNavigationRecord record) {
    setState(() {
      _navMode = true;
      _activeTab = _BottomTab.plan;
      _navPanelCollapsed = false;
      _navStartIsMyLocation = false;
      _navStartPlace = _placeFromSavedCoordinate(record.start);
      _navEndPlace = _placeFromSavedCoordinate(record.end);
      _navWaypoints
        ..clear()
        ..addAll(record.waypoints.map(_placeFromSavedCoordinate));
      _avoidCameras = record.avoidCameras;
      _currentRoute = null;
      _unavoidableCameraIndices = {};
      _navSearchTarget = null;
      _selectedPlace = null;
      _showSuggestions = false;
      _suggestions = [];
      _searchController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已将最近记录应用到导航模式')));
  }

  void _showRecentNavigationDetail(RecentNavigationRecord record) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _infoRow('起点', record.start.name),
            _infoRow('终点', record.end.name),
            _infoRow('途径点', '${record.waypoints.length} 个'),
            _infoRow('避开摄像头', record.avoidCameras ? '是' : '否'),
            _infoRow('来源', record.source.isEmpty ? '未知' : record.source),
            _infoRow('记录时间', _formatRecentCreatedAt(record.createdAt)),
          ],
        ),
      ),
    );
  }

  PlaceResult _resolvedNavStartPlace() {
    if (_navStartIsMyLocation) {
      final pos = _userPosition ?? _beijingCenter;
      return PlaceResult(
        name: '我的位置',
        address: _formatLatLng(pos),
        location: pos,
      );
    }

    return _navStartPlace ??
        PlaceResult(
          name: '起点',
          address: _formatLatLng(_beijingCenter),
          location: _beijingCenter,
        );
  }

  List<_NavStopItem> _buildNavStopItems() {
    final items = <_NavStopItem>[
      _NavStopItem(
        place: _resolvedNavStartPlace(),
        fromMyLocation: _navStartIsMyLocation,
      ),
      ..._navWaypoints.map((wp) => _NavStopItem(place: wp)),
    ];

    if (_navEndPlace != null) {
      items.add(_NavStopItem(place: _navEndPlace!));
    }

    return items;
  }

  void _reverseNavStops() {
    final originalItems = _buildNavStopItems();
    if (originalItems.length < 2) return;

    setState(() {
      final items = originalItems.reversed.toList();
      final hasEnd = _navEndPlace != null && items.length >= 2;
      final first = items.first;

      _navStartIsMyLocation = first.fromMyLocation;
      _navStartPlace = first.fromMyLocation ? null : first.place;

      if (hasEnd) {
        _navEndPlace = items.last.place;
      }

      final middle = hasEnd
          ? items.sublist(1, items.length - 1)
          : items.sublist(1);
      _navWaypoints
        ..clear()
        ..addAll(middle.map((e) => e.place));
    });
  }

  void _reorderNavStops(int oldIndex, int newIndex) {
    final items = _buildNavStopItems();
    if (items.length < 2) return;

    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = items.removeAt(oldIndex);
      items.insert(newIndex, moved);

      final hasEnd = _navEndPlace != null && items.length >= 2;
      final first = items.first;

      _navStartIsMyLocation = first.fromMyLocation;
      _navStartPlace = first.fromMyLocation ? null : first.place;

      if (hasEnd) {
        _navEndPlace = items.last.place;
      }

      final middle = hasEnd
          ? items.sublist(1, items.length - 1)
          : items.sublist(1);
      _navWaypoints
        ..clear()
        ..addAll(middle.map((e) => e.place));
    });
  }

  String _stopLabel(int index, int total) {
    final hasEnd = _navEndPlace != null;
    if (index == 0) return '起点';
    if (hasEnd && index == total - 1) return '终点';
    return '途径点';
  }

  Color _stopColor(int index, int total) {
    final hasEnd = _navEndPlace != null;
    if (index == 0) return Colors.green[700]!;
    if (hasEnd && index == total - 1) return const Color(0xFFBA1A1A);
    return _secondary;
  }

  IconData _stopIcon(int index, int total) {
    final hasEnd = _navEndPlace != null;
    if (index == 0) return Icons.my_location_rounded;
    if (hasEnd && index == total - 1) return Icons.location_on_rounded;
    return Icons.more_horiz_rounded;
  }

  NavigationRoute _mergeRoutes(
    List<NavigationRoute> segments,
    bool avoidCameras,
  ) {
    final mergedPoints = <LatLng>[];
    final mergedCameraIndices = <int>{};
    double distance = 0;
    int duration = 0;

    for (var i = 0; i < segments.length; i++) {
      final route = segments[i];
      if (i == 0) {
        mergedPoints.addAll(route.polylinePoints);
      } else {
        mergedPoints.addAll(route.polylinePoints.skip(1));
      }
      mergedCameraIndices.addAll(route.cameraIndicesOnRoute);
      distance += route.distance;
      duration += route.duration;
    }

    return NavigationRoute(
      id: 'merged-${DateTime.now().millisecondsSinceEpoch}',
      startPoint: segments.first.startPoint,
      endPoint: segments.last.endPoint,
      polylinePoints: mergedPoints,
      distance: distance,
      duration: duration,
      routeType: avoidCameras ? 'avoid_cameras' : 'normal',
      cameraIndicesOnRoute: mergedCameraIndices.toList()..sort(),
      createdAt: DateTime.now(),
    );
  }

  Future<void> _loadCameras() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getCameras();
      setState(() {
        _cameras = response.cameras;
        _updatedAt = response.updatedAt;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载摄像头数据失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadWayPoints() async {
    try {
      final waypoints = await _apiService.getWayPoints();
      setState(() {
        _wayPoints = waypoints;
      });
    } catch (e) {
      print('加载标记点失败: $e');
    }
  }

  Future<void> _loadDismissedCameras() async {
    try {
      final list = await _apiService.getDismissedCameras();
      setState(() {
        _dismissedCoords.clear();
        for (final c in list) {
          _dismissedCoords.add(
            '${c.lat.toStringAsFixed(6)},${c.lng.toStringAsFixed(6)}',
          );
        }
      });
    } catch (e) {
      print('加载废弃摄像头失败: $e');
    }
  }

  bool _isCameraDismissed(Camera camera) {
    final key =
        '${camera.lat.toStringAsFixed(6)},${camera.lng.toStringAsFixed(6)}';
    return _dismissedCoords.contains(key);
  }

  void _fitRouteToMap(NavigationRoute route) {
    final points = route.polylinePoints;
    if (points.isEmpty) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          points.length > 1 ? points : [route.startPoint, route.endPoint],
        ),
        padding: const EdgeInsets.all(100),
      ),
    );
  }

  void _fitPlacesToMap(List<PlaceResult> places) {
    final points = places.map((e) => e.location).toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(100),
      ),
    );
  }

  Future<NavigationRoute?> _planRouteIteratively(
    LatLng start,
    LatLng end, {
    String? legLabel,
    List<LatLng>? userWaypoints,
    int? legIndex,
    int? totalLegs,
  }) async {
    NavigationRoute? bestRoute;
    NavigationRoute? currentRoute;
    double? anchorDistance;

    var i = 0;
    while (mounted && !_stopPlanningRequested) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - _lastPlanStepRequestAtMs;
      if (elapsed < _minPlanStepIntervalMs) {
        await Future.delayed(
          Duration(milliseconds: _minPlanStepIntervalMs - elapsed),
        );
      }
      _lastPlanStepRequestAtMs = DateTime.now().millisecondsSinceEpoch;

      if (!mounted || _stopPlanningRequested) return bestRoute ?? currentRoute;

      setState(() {
        _planningIteration = i + 1;
        final prefix = legLabel == null ? '' : '$legLabel · ';
        _planningStatus = '$prefix第${i + 1}轮规划中...';
      });

      final step = await _apiService.planRouteStep(
        start: start,
        end: end,
        iteration: i,
        maxIterations: _planStepMaxIterations,
        bestRoute: bestRoute,
        anchorDistance: anchorDistance,
        waypoints: userWaypoints,
        legIndex: legIndex,
        totalLegs: totalLegs,
      );

      if (step.errorMessage != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(step.errorMessage!)));
        }
        break;
      }

      if (step.currentRoute == null || step.bestRoute == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('单步路线规划返回数据不完整')));
        }
        break;
      }

      currentRoute = step.currentRoute!;
      bestRoute = step.bestRoute!;
      anchorDistance = step.anchorDistance ?? anchorDistance;
      final currentRouteValue = currentRoute;
      final bestRouteValue = bestRoute;

      final anchor = anchorDistance ?? bestRouteValue.distance;
      final bool shouldDrawCurrent =
          currentRouteValue.distance <= anchor * 1.20 ||
          currentRouteValue.cameraIndicesOnRoute.length <
              bestRouteValue.cameraIndicesOnRoute.length;
      final NavigationRoute displayRoute = shouldDrawCurrent
          ? currentRouteValue
          : bestRouteValue;

      if (!mounted) return bestRoute;

      // 每轮先绘制当前轮次路线，让用户看到迭代进度
      setState(() {
        _currentRoute = displayRoute;
        _unavoidableCameraIndices = displayRoute.cameraIndicesOnRoute.toSet();
        final prefix = legLabel == null ? '' : '$legLabel · ';
        _planningStatus =
            '$prefix第${i + 1}轮：当前${currentRouteValue.cameraIndicesOnRoute.length}个，最优${bestRouteValue.cameraIndicesOnRoute.length}个';
      });
      _fitRouteToMap(displayRoute);

      if (step.done) {
        break;
      }

      i += 1;
    }

    if (bestRoute != null && mounted) {
      final bestRouteValue = bestRoute;
      setState(() {
        _currentRoute = bestRouteValue;
        _unavoidableCameraIndices = bestRouteValue.cameraIndicesOnRoute.toSet();
        _planningStatus =
            '规划完成：剩余${bestRouteValue.cameraIndicesOnRoute.length}个摄像头';
      });
      _fitRouteToMap(bestRouteValue);
    }

    return bestRoute ?? currentRoute;
  }

  Future<void> _planRoute(LatLng start, LatLng end, bool avoidCameras) async {
    await _planRouteWithStops([start, end], avoidCameras);
  }

  Future<void> _planRouteWithStops(
    List<LatLng> orderedStops,
    bool avoidCameras,
  ) async {
    if (orderedStops.length < 2) return;

    final userWaypoints = orderedStops.length > 2
        ? orderedStops.sublist(1, orderedStops.length - 1)
        : <LatLng>[];

    final totalLegs = orderedStops.length - 1;

    setState(() {
      _isNavigating = true;
      _stopPlanningRequested = false;
      _planningIteration = 0;
      _planningStatus = avoidCameras ? '准备路线规划...' : null;
    });

    try {
      final segmentRoutes = <NavigationRoute>[];

      for (var i = 0; i < totalLegs; i++) {
        if (!mounted || _stopPlanningRequested) break;

        final start = orderedStops[i];
        final end = orderedStops[i + 1];
        final legLabel = '路段 ${i + 1}/$totalLegs';

        setState(() {
          _planningIteration = 0;
          _planningStatus = '$legLabel 规划中...';
        });

        if (avoidCameras) {
          final legRoute = await _planRouteIteratively(
            start,
            end,
            legLabel: legLabel,
            userWaypoints: userWaypoints,
            legIndex: i + 1,
            totalLegs: totalLegs,
          );
          if (legRoute == null) {
            throw Exception('$legLabel 规划失败');
          }
          segmentRoutes.add(legRoute);
        } else {
          final response = await _apiService.planRoute(
            start: start,
            end: end,
            avoidCameras: false,
          );
          if (response.route == null) {
            throw Exception(response.errorMessage ?? '$legLabel 规划失败');
          }
          segmentRoutes.add(response.route!);
        }
      }

      if (segmentRoutes.isNotEmpty && mounted) {
        final merged = _mergeRoutes(segmentRoutes, avoidCameras);
        setState(() {
          _currentRoute = merged;
          _unavoidableCameraIndices = merged.cameraIndicesOnRoute.toSet();
        });
        _fitRouteToMap(merged);
        if (_stopPlanningRequested) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已暂停/停止重试')));
        } else {
          _showRouteResult(merged, avoidCameras);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('路线规划异常: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
          _stopPlanningRequested = false;
          _planningIteration = 0;
          _planningStatus = null;
        });
      }
    }
  }

  /// 路线规划结果弹窗：告知用户绕开了几个摄像头、哪些无法绕开
  void _showRouteResult(NavigationRoute route, bool avoidCameras) {
    final onRouteCount = route.cameraIndicesOnRoute.length;
    // 本次规划绕开的摄像头数（与总数对比无意义，与路线直线对比也难算，
    // 直接告诉用户"路线上仍有 N 个"以及"具体是哪些"）
    final unavoidableCameras = route.cameraIndicesOnRoute
        .where((i) => i < _cameras.length)
        .map((i) => _cameras[i])
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: onRouteCount == 0
                        ? Colors.green.withValues(alpha: 0.12)
                        : const Color(0xFFBA1A1A).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    onRouteCount == 0
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    color: onRouteCount == 0
                        ? Colors.green[700]
                        : const Color(0xFFBA1A1A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        avoidCameras
                            ? (onRouteCount == 0 ? '已完全绕开所有摄像头！' : '路线规划完成')
                            : '路线规划完成',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(route.distance / 1000).toStringAsFixed(1)} km · '
                        '约 ${(route.duration / 60).round()} 分钟',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 摄像头绕行结果
            if (avoidCameras) ...[
              if (onRouteCount == 0)
                _routeResultRow(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: Colors.green[700]!,
                  text: '路线上 0 个摄像头，已完全绕开',
                )
              else ...[
                _routeResultRow(
                  icon: Icons.videocam_off_rounded,
                  iconColor: const Color(0xFFBA1A1A),
                  text: '路线上仍有 $onRouteCount 个摄像头无法绕开（已标红）',
                ),
                const SizedBox(height: 10),
                const Text(
                  '无法绕开的摄像头：',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                ...unavoidableCameras.map(
                  (cam) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.videocam_rounded,
                          size: 14,
                          color: Color(0xFFBA1A1A),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cam.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          cam.typeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else
              _routeResultRow(
                icon: Icons.videocam_rounded,
                iconColor: _onSurfaceVariant,
                text: '普通路线，途经 $onRouteCount 个摄像头',
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                ),
                child: const Text(
                  '知道了',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeResultRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: _onSurface),
          ),
        ),
      ],
    );
  }

  void _deleteWayPoint(WayPoint wayPoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标记点'),
        content: Text('确定删除标记点 "${wayPoint.name}" 吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteWayPoint(wayPoint.id);
      if (success) {
        await _loadWayPoints();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('标记点已删除')));
        }
      }
    }
  }

  Color _cameraColor(int type) {
    switch (type) {
      case 1:
        return const Color(0xFFBA1A1A);
      case 2:
        return const Color(0xFFB96A00);
      case 4:
        return const Color(0xFF7C7766);
      case 6:
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFFBA1A1A);
    }
  }

  /// 最近 7 天新增的摄像头：白底+蓝色边框，同六环内风格但更显眼，试用期加"试"角标
  Widget _buildNewlyAddedMarker(Camera cam) {
    const newColor = Color(0xFF0277BD);
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(color: newColor, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: newColor.withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.videocam_rounded, color: newColor, size: 18),
        ),
        if (cam.isPilot)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '试',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUnavoidableCameraMarker(Camera cam) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFBA1A1A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBA1A1A).withValues(alpha: 0.55),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
    );
  }

  void _showCameraInfo(Camera camera) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDismissed = _isCameraDismissed(camera);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.videocam,
                    color: isDismissed
                        ? Colors.grey
                        : _cameraColor(camera.type),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      camera.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDismissed ? Colors.grey : null,
                        decoration: isDismissed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (isDismissed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已废弃',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow('类型', camera.typeLabel),
              _infoRow('坐标', '${camera.lng}, ${camera.lat}'),
              _infoRow('更新日期', camera.date),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: isDismissed
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.restore),
                        label: const Text('取消废弃'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await _apiService.unmarkCameraDismissed(
                            lat: camera.lat,
                            lng: camera.lng,
                          );
                          if (ok && mounted) {
                            await _loadDismissedCameras();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已取消废弃标记')),
                            );
                          }
                        },
                      )
                    : FilledButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('标记为废弃'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await _apiService.markCameraDismissed(
                            lat: camera.lat,
                            lng: camera.lng,
                            name: camera.name,
                          );
                          if (ok && mounted) {
                            await _loadDismissedCameras();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已标记为废弃，路线规划将自动排除此摄像头'),
                              ),
                            );
                          }
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showWayPointInfo(WayPoint wayPoint) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wayPoint.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(
              '坐标',
              '${wayPoint.location.longitude}, ${wayPoint.location.latitude}',
            ),
            _infoRow('创建时间', wayPoint.createdAt.toString().split('.')[0]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteWayPoint(wayPoint);
                  },
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // 导航到此标记点
                    _planRoute(
                      _userPosition ?? _beijingCenter,
                      wayPoint.location,
                      true,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('导航到这里'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                color: _onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassPanel({
    required Widget child,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _surfaceCard.withValues(alpha: 0.97),
            borderRadius: borderRadius,
            border: Border.all(
              color: _surfaceVariant.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildGlassPanel(
            borderRadius: BorderRadius.circular(999),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _fetchSuggestions,
              style: const TextStyle(
                color: _onSurface,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              decoration: InputDecoration(
                hintText: '今天想去哪里？',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _primary,
                  size: 22,
                ),
                suffixIcon: _showSuggestions || _selectedPlace != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: _onSurfaceVariant,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _showSuggestions = false;
                            _suggestions = [];
                            _selectedPlace = null;
                          });
                          _searchFocusNode.unfocus();
                        },
                      )
                    : IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.mic_none_rounded, size: 18),
                        color: _onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        if (_showSuggestions && (_suggestions.isNotEmpty || _isSuggesting))
          _buildSuggestionList(margin: const EdgeInsets.fromLTRB(16, 8, 16, 0)),
      ],
    );
  }

  Widget _buildSavedPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildGlassPanel(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 430),
              child: _loadingSaved
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(color: _primary),
                      ),
                    )
                  : (_savedError != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _savedError!,
                                style: const TextStyle(
                                  color: Color(0xFFBA1A1A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: _loadSavedData,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                ),
                                child: const Text('重试加载'),
                              ),
                            ],
                          )
                        : (_savedRoutes.isEmpty && _savedRoutePlans.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Text(
                                      '暂无保存内容\n先在导航页点击“保存线路 / 保存点位”',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            '已保存',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: _onSurface,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                            ),
                                            onPressed: () =>
                                                _loadSavedData(silent: true),
                                          ),
                                        ],
                                      ),
                                      if (_savedRoutes.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        const Text(
                                          '线路',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ..._savedRoutes.map((item) {
                                          final stops = _stopsFromSavedRoute(
                                            item,
                                          );
                                          final start = stops.first;
                                          final end = stops.length >= 2
                                              ? stops.last
                                              : start;
                                          final waypoints = stops.length > 2
                                              ? stops
                                                    .sublist(
                                                      1,
                                                      stops.length - 1,
                                                    )
                                                    .map((e) => e.name)
                                                    .toList()
                                              : <String>[];
                                          final summary = _savedWaypointSummary(
                                            startName: start.name,
                                            endName: end.name,
                                            waypointNames: waypoints,
                                          );

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: _buildNavRow(
                                              icon: Icons.alt_route_rounded,
                                              iconColor: _primary,
                                              label: item.name,
                                              subtitle: summary,
                                              isPlaceholder: false,
                                              onTap: () =>
                                                  _applySavedRouteToNavigation(
                                                    item,
                                                  ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons.visibility_outlined,
                                                      size: 16,
                                                      color: _onSurfaceVariant,
                                                    ),
                                                    onPressed: () =>
                                                        _showSavedRouteDetail(
                                                          item,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 16,
                                                      color: Color(0xFFBA1A1A),
                                                    ),
                                                    onPressed: () =>
                                                        _deleteSavedRoute(item),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                      if (_savedRoutePlans.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        const Text(
                                          '起终点与途径点方案',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ..._savedRoutePlans.map((item) {
                                          final waypointNames = item.waypoints
                                              .map((e) => e.name)
                                              .toList();
                                          final summary = _savedWaypointSummary(
                                            startName: item.start.name,
                                            endName: item.end.name,
                                            waypointNames: waypointNames,
                                          );

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: _buildNavRow(
                                              icon: Icons
                                                  .playlist_add_check_circle_outlined,
                                              iconColor: _secondary,
                                              label: item.name,
                                              subtitle: summary,
                                              isPlaceholder: false,
                                              onTap: () =>
                                                  _applySavedRoutePlanToNavigation(
                                                    item,
                                                  ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons.visibility_outlined,
                                                      size: 16,
                                                      color: _onSurfaceVariant,
                                                    ),
                                                    onPressed: () =>
                                                        _showSavedRoutePlanDetail(
                                                          item,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 16,
                                                      color: Color(0xFFBA1A1A),
                                                    ),
                                                    onPressed: () =>
                                                        _deleteSavedRoutePlan(
                                                          item,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  ),
                                ))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildGlassPanel(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 430),
              child: _loadingRecent
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(color: _primary),
                      ),
                    )
                  : (_recentError != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _recentError!,
                                style: const TextStyle(
                                  color: Color(0xFFBA1A1A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: _loadRecentData,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                ),
                                child: const Text('重试加载'),
                              ),
                            ],
                          )
                        : (_recentNavigations.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Text(
                                      '暂无最近记录\n开始导航或应用保存项后会自动记录',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            '最近记录',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: _onSurface,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                            ),
                                            onPressed: () =>
                                                _loadRecentData(silent: true),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ..._recentNavigations.map(
                                        (item) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: _buildNavRow(
                                            icon: Icons.history_rounded,
                                            iconColor: _secondary,
                                            label:
                                                '${item.name} · ${_formatRecentCreatedAt(item.createdAt)}',
                                            isPlaceholder: false,
                                            onTap: () =>
                                                _applyRecentNavigationToNavigation(
                                                  item,
                                                ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  icon: const Icon(
                                                    Icons.visibility_outlined,
                                                    size: 16,
                                                    color: _onSurfaceVariant,
                                                  ),
                                                  onPressed: () =>
                                                      _showRecentNavigationDetail(
                                                        item,
                                                      ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 16,
                                                    color: Color(0xFFBA1A1A),
                                                  ),
                                                  onPressed: () =>
                                                      _deleteRecentNavigation(
                                                        item,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildGlassPanel(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.route_rounded,
                        color: _primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '路线规划',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _toggleNavPanelCollapsed,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _navPanelCollapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 20,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _exitNavMode,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_navPanelCollapsed) ...[
                  _buildNavRow(
                    icon: Icons.route_rounded,
                    iconColor: _primary,
                    label: '导航已折叠',
                    subtitle: _navCompactSummary(),
                    isPlaceholder: false,
                    onTap: _toggleNavPanelCollapsed,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  if (_navSearchTarget == 'start')
                    _buildNavInputRow(
                      icon: Icons.my_location_rounded,
                      iconColor: Colors.green[700]!,
                      hintText: '搜索起点...',
                    )
                  else if (_navSearchTarget == 'end')
                    _buildNavInputRow(
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFBA1A1A),
                      hintText: '搜索终点...',
                    )
                  else if (_navSearchTarget == 'waypoint')
                    _buildNavInputRow(
                      icon: Icons.more_horiz_rounded,
                      iconColor: _secondary,
                      hintText: '搜索途径点...',
                    )
                  else ...[
                    Builder(
                      builder: (context) {
                        final stops = _buildNavStopItems();
                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: stops.length,
                          onReorder: _reorderNavStops,
                          itemBuilder: (context, index) {
                            final item = stops[index];
                            final total = stops.length;
                            final hasEnd = _navEndPlace != null;
                            final isStart = index == 0;
                            final isEnd = hasEnd && index == total - 1;
                            final isWaypoint = !isStart && !isEnd;

                            final waypointIndex = index - 1;

                            return Padding(
                              key: ValueKey(item.id),
                              padding: EdgeInsets.only(
                                bottom: index == total - 1 ? 0 : 8,
                              ),
                              child: _buildNavRow(
                                icon: _stopIcon(index, total),
                                iconColor: _stopColor(index, total),
                                label:
                                    '${_stopLabel(index, total)} · ${item.place.name}',
                                subtitle: item.place.address.isNotEmpty
                                    ? item.place.address
                                    : _formatLatLng(item.place.location),
                                isPlaceholder: false,
                                onTap: isStart
                                    ? () {
                                        setState(
                                          () => _navSearchTarget = 'start',
                                        );
                                        _searchController.clear();
                                        _searchFocusNode.requestFocus();
                                      }
                                    : (isEnd
                                          ? () {
                                              setState(
                                                () => _navSearchTarget = 'end',
                                              );
                                              _searchController.clear();
                                              _searchFocusNode.requestFocus();
                                            }
                                          : null),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isWaypoint)
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: _onSurfaceVariant,
                                        ),
                                        onPressed: () {
                                          if (waypointIndex < 0 ||
                                              waypointIndex >=
                                                  _navWaypoints.length) {
                                            return;
                                          }
                                          setState(
                                            () => _navWaypoints.removeAt(
                                              waypointIndex,
                                            ),
                                          );
                                        },
                                      ),
                                    const SizedBox(width: 4),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          size: 18,
                                          color: _onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (_navEndPlace == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildNavRow(
                          icon: Icons.location_on_rounded,
                          iconColor: const Color(0xFFBA1A1A),
                          label: '选择终点',
                          subtitle: '可搜索地点或地图点选',
                          isPlaceholder: true,
                          onTap: () {
                            setState(() => _navSearchTarget = 'end');
                            _searchController.clear();
                            _searchFocusNode.requestFocus();
                          },
                        ),
                      ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '拖拽右侧手柄可调整起点 / 途径点 / 终点顺序',
                        style: TextStyle(
                          fontSize: 12,
                          color: _onSurfaceVariant.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _navSearchTarget == null
                            ? () {
                                setState(() => _navSearchTarget = 'waypoint');
                                _searchController.clear();
                                _searchFocusNode.requestFocus();
                              }
                            : null,
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: _secondary,
                        ),
                        label: const Text(
                          '添加途径点',
                          style: TextStyle(fontSize: 13, color: _secondary),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _buildNavStopItems().length >= 2
                            ? _reverseNavStops
                            : null,
                        icon: const Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: _secondary,
                        ),
                        label: const Text(
                          '反转点位',
                          style: TextStyle(fontSize: 13, color: _secondary),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '避开摄像头',
                        style: TextStyle(
                          fontSize: 13,
                          color: _onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: _avoidCameras,
                        activeThumbColor: _primary,
                        onChanged: (value) =>
                            setState(() => _avoidCameras = value),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentRoute != null
                              ? _saveCurrentRoute
                              : null,
                          icon: const Icon(
                            Icons.bookmark_add_outlined,
                            size: 16,
                          ),
                          label: const Text('保存线路'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _navEndPlace != null
                              ? _saveCurrentRoutePlanPoints
                              : null,
                          icon: const Icon(
                            Icons.playlist_add_rounded,
                            size: 16,
                          ),
                          label: const Text('保存点位'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isNavigating && _planningStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _planningStatus ??
                            (_planningIteration > 0
                                ? '第$_planningIteration轮规划中...'
                                : '规划中...'),
                        style: TextStyle(
                          fontSize: 12,
                          color: _onSurfaceVariant.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isNavigating
                        ? _requestStopPlanning
                        : (_navEndPlace != null ? _startNavigation : null),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isNavigating
                          ? const Color(0xFFBA1A1A)
                          : _primary,
                      disabledBackgroundColor: _surfaceVariant,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: Text(
                      _isNavigating
                          ? (_stopPlanningRequested ? '正在停止...' : '暂停/停止')
                          : '开始导航',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_navSearchTarget != null &&
            (_suggestions.isNotEmpty || _isSuggesting))
          _buildSuggestionList(margin: const EdgeInsets.fromLTRB(16, 8, 16, 0)),
      ],
    );
  }

  Widget _buildNavInputRow({
    required IconData icon,
    required Color iconColor,
    required String hintText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              onChanged: _fetchSuggestions,
              style: const TextStyle(
                fontSize: 14,
                color: _onSurface,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: _onSurfaceVariant.withValues(alpha: 0.55),
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close_rounded, size: 16),
            color: _onSurfaceVariant,
            onPressed: () {
              _searchController.clear();
              setState(() {
                _navSearchTarget = null;
                _showSuggestions = false;
                _suggestions = [];
              });
              _searchFocusNode.unfocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    required bool isPlaceholder,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: isPlaceholder
                          ? _onSurfaceVariant.withValues(alpha: 0.55)
                          : _onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isPlaceholder
                              ? _onSurfaceVariant.withValues(alpha: 0.52)
                              : _onSurfaceVariant.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing case final action?) action,
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList({EdgeInsetsGeometry? margin}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 270),
      child: Container(
        margin: margin,
        child: _buildGlassPanel(
          borderRadius: BorderRadius.circular(22),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _isSuggesting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _primary,
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 18,
                    endIndent: 18,
                    color: _surfaceVariant.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _primaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: _primary,
                        ),
                      ),
                      title: Text(
                        suggestion.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: suggestion.address.isNotEmpty
                          ? Text(
                              suggestion.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => _selectSuggestion(suggestion),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: _buildGlassPanel(
        borderRadius: BorderRadius.circular(32),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Row(
          children: [
            _buildBottomTab(
              tab: _BottomTab.explore,
              icon: Icons.explore_rounded,
              label: 'Explore',
            ),
            _buildBottomTab(
              tab: _BottomTab.plan,
              icon: Icons.route_rounded,
              label: 'Plan',
            ),
            _buildBottomTab(
              tab: _BottomTab.saved,
              icon: Icons.bookmark_outline_rounded,
              label: 'Saved',
            ),
            _buildBottomTab(
              tab: _BottomTab.recent,
              icon: Icons.history_rounded,
              label: 'Recent',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTab({
    required _BottomTab tab,
    required IconData icon,
    required String label,
  }) {
    final bool active = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(tab),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? _primaryContainer.withValues(alpha: 0.9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: active
                    ? _primary
                    : _onSurfaceVariant.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? _primary
                      : _onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 底部安全区高度 + 导航栏估算高度（icon+label+padding ≈ 72，外层 Padding bottom:8）
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 72.0 + bottomInset + 8;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 地图层
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _beijingCenter,
              initialZoom: 11,
              minZoom: 5,
              maxZoom: 18,
              onTap: (tapPosition, point) {
                _showMapPointActions(point);
              },
              onLongPress: (tapPosition, point) {
                _showMapPointActions(point);
              },
            ),
            children: [
              // 高德瓦片图层 (GCJ-02 坐标系，与摄像头坐标一致)
              TileLayer(
                urlTemplate:
                    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                subdomains: const ['1', '2', '3', '4'],
                userAgentPackageName: 'com.flowway.app',
                maxZoom: 18,
              ),
              // 路线图层
              if (_currentRoute != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentRoute!.polylinePoints,
                      color: _secondary.withValues(alpha: 0.9),
                      strokeWidth: 4.5,
                    ),
                  ],
                ),
              // 路线起点和终点标记
              if (_currentRoute != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentRoute!.startPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 30,
                      ),
                    ),
                    Marker(
                      point: _currentRoute!.endPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              // 摄像头标记层（定位完成后才显示）
              if (_locationResolved)
                MarkerLayer(
                  markers: _cameras.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final cam = entry.value;
                    final isUnavoidable = _unavoidableCameraIndices.contains(
                      idx,
                    );
                    final isDismissed = _isCameraDismissed(cam);
                    return Marker(
                      point: LatLng(cam.lat, cam.lng),
                      width: isUnavoidable ? 38 : (cam.isNewlyAdded ? 36 : 30),
                      height: isUnavoidable ? 38 : (cam.isNewlyAdded ? 36 : 30),
                      child: GestureDetector(
                        onTap: () => _showCameraInfo(cam),
                        child: isDismissed
                            ? Opacity(
                                opacity: 0.55,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF7C7766),
                                      width: 1.3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.videocam_off_rounded,
                                    color: Color(0xFF7C7766),
                                    size: 16,
                                  ),
                                ),
                              )
                            : isUnavoidable
                            ? _buildUnavoidableCameraMarker(cam)
                            : cam.isNewlyAdded
                            ? _buildNewlyAddedMarker(cam)
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _cameraColor(cam.type),
                                    width: 1.3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.videocam_rounded,
                                  color: _cameraColor(cam.type),
                                  size: 16,
                                ),
                              ),
                      ),
                    );
                  }).toList(),
                ),
              // 用户标记点层
              MarkerLayer(
                markers: _wayPoints.map((wayPoint) {
                  return Marker(
                    point: wayPoint.location,
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () => _showWayPointInfo(wayPoint),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // 用户定位标记
              if (_userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userPosition!,
                      width: 48,
                      height: 48,
                      child: const JinjingMarker(size: 48),
                    ),
                  ],
                ),
              // 导航模式地点标记
              if (_navMode)
                MarkerLayer(
                  markers: [
                    if (_navEndPlace != null)
                      Marker(
                        point: _navEndPlace!.location,
                        width: 48,
                        height: 48,
                        child: const JinjingMarker(size: 48),
                      ),
                    ..._navWaypoints.map(
                      (wp) => Marker(
                        point: wp.location,
                        width: 40,
                        height: 40,
                        child: const JinjingMarker(size: 40),
                      ),
                    ),
                    if (!_navStartIsMyLocation && _navStartPlace != null)
                      Marker(
                        point: _navStartPlace!.location,
                        width: 40,
                        height: 40,
                        child: const JinjingMarker(size: 40),
                      ),
                  ],
                ),
              // 搜索选中地点标记（仅非导航模式）
              if (_selectedPlace != null && !_navMode)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPlace!.location,
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => _showPlaceActions(_selectedPlace!),
                        child: const JinjingMarker(size: 48),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: _surface.withValues(alpha: 0.10),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _surface.withValues(alpha: 0.02),
                      _surface.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 顶部搜索框 / 导航面板
          SafeArea(
            child: _activeTab == _BottomTab.saved
                ? _buildSavedPanel()
                : (_activeTab == _BottomTab.recent
                      ? _buildRecentPanel()
                      : (_navMode ? _buildNavPanel() : _buildSearchBar())),
          ),

          // 加载指示器
          if (_loading)
            Center(
              child: _buildGlassPanel(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _primary),
                    SizedBox(height: 10),
                    Text('正在加载摄像头数据...'),
                  ],
                ),
              ),
            ),

          // 错误提示
          if (_error != null)
            Center(
              child: _buildGlassPanel(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFBA1A1A),
                      size: 38,
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _loadCameras,
                      style: FilledButton.styleFrom(backgroundColor: _primary),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),

          // 底部信息栏
          if (!_loading && _error == null)
            Positioned(
              bottom: navBarHeight + 8,
              left: 16,
              right: 84,
              child: _buildGlassPanel(
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '摄像头 ${_cameras.length} · 标记点 ${_wayPoints.length} · $_updatedAt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // 导航进度指示器
          if (_isNavigating)
            Center(
              child: _buildGlassPanel(
                borderRadius: BorderRadius.circular(20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _primary),
                    const SizedBox(height: 10),
                    Text(_planningStatus ?? '正在规划路线...'),
                  ],
                ),
              ),
            ),

          Positioned(
            right: 16,
            bottom: navBarHeight + 8,
            child: FloatingActionButton.small(
              heroTag: 'locate-btn',
              backgroundColor: _primaryContainer,
              foregroundColor: _primary,
              elevation: 2,
              onPressed: () {
                if (_userPosition != null) {
                  _mapController.move(_userPosition!, 14);
                } else {
                  _locateUser();
                }
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _buildBottomNavigationBar()),
          ),
        ],
      ),
    );
  }
}
