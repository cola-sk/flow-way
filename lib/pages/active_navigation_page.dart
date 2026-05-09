import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/camera.dart';
import '../models/route.dart';
import '../services/api_service.dart';
import '../utils/coordinate_transform.dart';
import '../widgets/jinjing_marker.dart';
import 'save_route_dialog.dart';

class ActiveNavigationPage extends StatefulWidget {
  final NavigationRoute route;
  final List<Camera> camerasOnRoute;
  final ApiService apiService;
  final List<PlaceResult> stops;

  const ActiveNavigationPage({
    Key? key,
    required this.route,
    required this.camerasOnRoute,
    required this.apiService,
    required this.stops,
  }) : super(key: key);

  @override
  State<ActiveNavigationPage> createState() => _ActiveNavigationPageState();
}

class _ActiveNavigationPageState extends State<ActiveNavigationPage> {
  final MapController _mapController = MapController();
  final FlutterTts _flutterTts = FlutterTts();
  final Distance _distanceCalc = const Distance();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  LatLng? _currentMapPosition;
  double _currentSpeed = 0.0; // m/s
  double _heading = 0.0;     // degrees
  DateTime? _navStartTime;


  bool _isFollowing = true;
  bool _isOffRoute = false;
  int _offRouteCounter = 0; // 连续偏离计数器
  bool _muteVoiceGuidance = false;

  // 记录已经播报过的摄像头 ID/名称，避免重复播报
  final Set<String> _alertedCameras = {};
  
  // 记录已经播报过的步骤标识，避免重复播报
  final Set<String> _alertedSteps = {};

  Camera? _nextCamera;
  double? _distanceToNextCamera;

  // 吸附后的坐标（用于显示）
  LatLng? _snappedMapPosition;

  bool _isOverviewMode = false;

  RouteStep? _nextStep;
  double? _distanceToNextStep;

  // 当前所在路段（用于底部道路信息显示）
  RouteStep? _currentStep;
  double? _distanceRemainingInStep;  // 当前路段剩余距离

  // 路线进度游标：记录用户已走过的最远线段下标，只前进不后退，
  // 防止弯道上把身后的线段识别为「当前位置」导致距离偏长
  int _routeProgressIdx = 0;

  Timer? _overviewTimer;
  int _overviewCountdown = 5;
  bool _isOverviewPinned = false;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _initTts();
    _startNavigation();
    _navStartTime = DateTime.now();
    widget.apiService.reportEvent('navigation_start', {
      'timestamp': _navStartTime!.toIso8601String(),
      'camera_count': widget.camerasOnRoute.length,
      'route_distance': widget.route.distance,
      'route_duration': widget.route.duration,
    });
  }


  Future<void> _initTts() async {
    await _flutterTts.setLanguage("zh-CN");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _speak("开始导航，请沿路线行驶。");
  }

  Future<void> _speak(String text) async {
    if (_muteVoiceGuidance) {
      return;
    }
    await _flutterTts.speak(text);
  }

  Future<void> _toggleVoiceMute() async {
    final next = !_muteVoiceGuidance;
    if (next) {
      await _flutterTts.stop();
    }
    if (!mounted) return;
    setState(() {
      _muteVoiceGuidance = next;
    });
  }

  void _startNavigation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final LocationSettings settings = kIsWeb
        ? const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
          )
        : AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
            intervalDuration: const Duration(milliseconds: 500),
            forceLocationManager: true,
          );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      final mapPos = CoordinateTransform.wgs84ToGcj02(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      // 计算吸附后的坐标用于显示
      final snappedPos = _calculateSnappedPosition(mapPos);

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _currentMapPosition = mapPos;
        _snappedMapPosition = snappedPos;
        _currentSpeed = position.speed; // m/s
        if (position.speed > 1.0) {
          _heading = position.heading; // degrees
        }
      });
      _processNavigationLogic(mapPos);

      double targetZoom = 17.0;
      // 当前步骤末端转向不足 300 米时，拉升视角（缩放级别减小）以便看清路口全貌
      if (_distanceRemainingInStep != null && _distanceRemainingInStep! < 300 &&
          _currentStep != null && _isActionableStep(_currentStep!)) {
        targetZoom = 16.0;
      }

      if (_isFollowing) {
        _mapController.moveAndRotate(
          snappedPos, // 使用吸附后的位置跟随，更平滑
          targetZoom, // 动态 zoom level
          360.0 - _heading, // map rotated inversely to heading for heading-up
        );
      }
    });
  }

  /// 将原始坐标吸附到导航路线上（从进度游标附近搜索，避免回吸到已过的路段）
  LatLng _calculateSnappedPosition(LatLng currentLoc) {
    if (widget.route.polylinePoints.length < 2) return currentLoc;

    double minDistance = double.infinity;
    LatLng snappedPoint = currentLoc;
    final int searchStart = math.max(0, _routeProgressIdx - 2);

    for (int i = searchStart; i < widget.route.polylinePoints.length - 1; i++) {
      final p1 = widget.route.polylinePoints[i];
      final p2 = widget.route.polylinePoints[i + 1];
      final projected = _projectPointOnSegment(currentLoc, p1, p2);
      final dist = _distanceCalc(currentLoc, projected);
      if (dist < minDistance) {
        minDistance = dist;
        snappedPoint = projected;
      }
    }

    if (minDistance < 30) {
      return snappedPoint;
    }
    return currentLoc;
  }

  /// 计算点到线段的垂直投影点
  LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    double x = p.longitude;
    double y = p.latitude;
    double x1 = a.longitude;
    double y1 = a.latitude;
    double x2 = b.longitude;
    double y2 = b.latitude;

    double dx = x2 - x1;
    double dy = y2 - y1;

    if (dx == 0 && dy == 0) return a;

    // 计算投影比例 t
    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);

    if (t < 0) return a;
    if (t > 1) return b;

    return LatLng(y1 + t * dy, x1 + t * dx);
  }

  /// 从步骤中提取方向关键词（用于语音和显示）
  String _getDirectionLabel(RouteStep step) {
    final text = step.action ?? step.instruction;
    if (text.contains('左转')) return '左转';
    if (text.contains('右转')) return '右转';
    if (text.contains('掉头') || text.contains('调头')) return '掉头';
    if (text.contains('靠左') || text.contains('左前')) return '靠左行驶';
    if (text.contains('靠右') || text.contains('右前')) return '靠右行驶';
    if (text.contains('直行') || text.contains('直走')) return '直行';
    return step.instruction;
  }

  /// 判断步骤是否包含需要提示的转向动作（非直行/出发）
  bool _isActionableStep(RouteStep step) {
    final text = step.action ?? step.instruction;
    return text.contains('左转') ||
        text.contains('右转') ||
        text.contains('掉头') ||
        text.contains('调头') ||
        text.contains('靠左') ||
        text.contains('靠右') ||
        text.contains('左前') ||
        text.contains('右前');
  }

  void _processNavigationLogic(LatLng currentLoc) {
    if (widget.route.polylinePoints.isEmpty) return;

    // 1. 从进度游标附近搜索最近线段
    //    允许少量回溯（-2）以应对 GPS 抖动，但不回到起点，防止弯道把身后路段误判为当前位置
    final int searchStart = math.max(0, _routeProgressIdx - 2);
    double minDistanceToRoute = double.infinity;
    int bestSegIdx = searchStart;
    LatLng bestSnapped = currentLoc;

    for (int i = searchStart; i < widget.route.polylinePoints.length - 1; i++) {
      final p1 = widget.route.polylinePoints[i];
      final p2 = widget.route.polylinePoints[i + 1];
      final projected = _projectPointOnSegment(currentLoc, p1, p2);
      final d = _distanceCalc(currentLoc, projected);
      if (d < minDistanceToRoute) {
        minDistanceToRoute = d;
        bestSegIdx = i;
        bestSnapped = projected;
      }
    }

    // 进度游标只前进不后退
    _routeProgressIdx = math.max(_routeProgressIdx, bestSegIdx);
    final nearestSegIdx = _routeProgressIdx;

    // 在当前进度段上重新计算吸附点（进度可能因游标超过 bestSegIdx 而更新）
    final LatLng snappedOnRoute;
    if (nearestSegIdx == bestSegIdx) {
      snappedOnRoute = bestSnapped;
    } else if (nearestSegIdx + 1 < widget.route.polylinePoints.length) {
      snappedOnRoute = _projectPointOnSegment(
        currentLoc,
        widget.route.polylinePoints[nearestSegIdx],
        widget.route.polylinePoints[nearestSegIdx + 1],
      );
    } else {
      snappedOnRoute = widget.route.polylinePoints.last;
    }

    // 偏离检测：连续 3 次超过 60 米才触发
    if (minDistanceToRoute > 60) {
      _offRouteCounter++;
    } else {
      _offRouteCounter = 0;
    }
    final offRoute = _offRouteCounter >= 3;
    if (offRoute && !_isOffRoute) {
      _speak("您已偏离路线，请注意行驶。");
    }
    _isOffRoute = offRoute;

    // 2. 摄像头距离检测
    Camera? nearestCam;
    double minCamDist = double.infinity;
    for (var cam in widget.camerasOnRoute) {
      final camLoc = LatLng(cam.lat, cam.lng);
      final d = _distanceCalc(currentLoc, camLoc);
      if (d < 1000 && d < minCamDist) {
        minCamDist = d;
        nearestCam = cam;
      }
    }
    setState(() {
      _nextCamera = nearestCam;
      _distanceToNextCamera = nearestCam != null ? minCamDist : null;
    });
    if (nearestCam != null && minCamDist < 300) {
      final camId = "${nearestCam.lat}_${nearestCam.lng}";
      if (!_alertedCameras.contains(camId)) {
        _alertedCameras.add(camId);
        _speak("注意，前方三百米有进京证抓拍摄像头。");
      }
    }

    // 3. 步骤检测：找第一个 polylineIdxEnd > nearestSegIdx 的步骤
    if (widget.route.steps == null || widget.route.steps!.isEmpty) return;

    int currentStepIndex = widget.route.steps!.length - 1;
    for (int i = 0; i < widget.route.steps!.length; i++) {
      if (widget.route.steps![i].polylineIdxEnd > nearestSegIdx) {
        currentStepIndex = i;
        break;
      }
    }

    final curStep = widget.route.steps![currentStepIndex];

    // 4. 计算到下一步骤起点的路线距离（从吸附点沿路线累加）
    RouteStep? nextStep;
    double distToNext = 0.0;
    if (currentStepIndex + 1 < widget.route.steps!.length) {
      nextStep = widget.route.steps![currentStepIndex + 1];
      final targetIdx = nextStep.polylineIdxStart;
      if (nearestSegIdx + 1 < widget.route.polylinePoints.length) {
        distToNext = _distanceCalc(
            snappedOnRoute, widget.route.polylinePoints[nearestSegIdx + 1]);
        for (int i = nearestSegIdx + 1;
            i < targetIdx && i + 1 < widget.route.polylinePoints.length;
            i++) {
          distToNext += _distanceCalc(
              widget.route.polylinePoints[i], widget.route.polylinePoints[i + 1]);
        }
      }
    }

    // 5. 当前路段剩余距离
    double remainingInStep = 0.0;
    final endIdx = curStep.polylineIdxEnd;
    if (nearestSegIdx + 1 < widget.route.polylinePoints.length &&
        endIdx > nearestSegIdx) {
      remainingInStep = _distanceCalc(
          snappedOnRoute, widget.route.polylinePoints[nearestSegIdx + 1]);
      for (int i = nearestSegIdx + 1;
          i < endIdx && i + 1 < widget.route.polylinePoints.length;
          i++) {
        remainingInStep += _distanceCalc(
            widget.route.polylinePoints[i], widget.route.polylinePoints[i + 1]);
      }
    }

    setState(() {
      _currentStep = curStep;
      _distanceRemainingInStep = remainingInStep;
      _nextStep = nextStep;
      _distanceToNextStep = nextStep != null ? distToNext : null;
    });

    // 转向语音播报：基于当前步骤末端的转向动作和剩余距离
    if (_isActionableStep(curStep) && remainingInStep > 0) {
      final stepId = curStep.polylineIdxStart.toString();
      final dirLabel = _getDirectionLabel(curStep);
      if (remainingInStep <= 150 && remainingInStep > 30) {
        final key150 = "${stepId}_150m";
        if (!_alertedSteps.contains(key150)) {
          _alertedSteps.add(key150);
          _speak("前方 ${remainingInStep.round()} 米，$dirLabel");
        }
      } else if (remainingInStep <= 30) {
        final key30 = "${stepId}_30m";
        if (!_alertedSteps.contains(key30)) {
          _alertedSteps.add(key30);
          _speak(dirLabel);
        }
      }
    }
  }

  void _enterOverviewMode() {
    if (!mounted) return;
    
    setState(() {
      _isOverviewMode = true;
      _isFollowing = false;
      _isOverviewPinned = false;
      _overviewCountdown = 5;
    });

    _overviewTimer?.cancel();
    _overviewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_overviewCountdown > 1) {
          _overviewCountdown--;
        } else {
          timer.cancel();
          _resumeFollowing();
        }
      });
    });

    _fitRouteOverview();
  }

  void _resumeFollowing() {
    if (!mounted) return;
    _overviewTimer?.cancel();
    
    final targetPos = _snappedMapPosition ?? 
                     _currentMapPosition ?? 
                     widget.route.startPoint;
    
    setState(() {
      _isFollowing = true;
      _isOverviewMode = false;
    });

    _mapController.moveAndRotate(
      targetPos,
      17.0,
      360.0 - _heading,
    );
  }

  void _pinOverview() {
    _overviewTimer?.cancel();
    setState(() {
      _isOverviewPinned = true;
    });
  }

  void _fitRouteOverview() {
    if (widget.route.polylinePoints.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(widget.route.polylinePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            top: 120,
            bottom: 160,
            left: 60,
            right: 60,
          ),
        ),
      );
      _mapController.rotate(0.0);
    } catch (e) {
      debugPrint('Fit route overview failed: $e');
      _mapController.moveAndRotate(widget.route.startPoint, 12.0, 0.0);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _overviewTimer?.cancel();
    _flutterTts.stop();
    unawaited(WakelockPlus.disable());
    
    if (_navStartTime != null) {
      final duration = DateTime.now().difference(_navStartTime!);
      widget.apiService.reportEvent('navigation_end', {
        'duration_seconds': duration.inSeconds,
        'start_time': _navStartTime!.toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
      });
      _navStartTime = null;
    }
    
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.route.startPoint,
              initialZoom: 17.0,
              minZoom: 3.0,
              maxZoom: 20.0,
              // rotation properties?
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  if (_isFollowing) setState(() => _isFollowing = false);
                  if (_isOverviewMode) {
                    _overviewTimer?.cancel();
                    setState(() => _isOverviewMode = false);
                  }
                }
              },
            ),
            children: [
              // 高德瓦片图层 (GCJ-02 坐标系)
              TileLayer(
                urlTemplate:
                    'https://rt{s}.map.gtimg.com/tile?z={z}&x={x}&y={y}&styleid=1000&scene=0&version=347',
                subdomains: const ['0', '1', '2', '3'],
                tms: true,
                userAgentPackageName: 'com.flowway.app',
                maxZoom: 20,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.route.polylinePoints,
                    strokeWidth: 6.0,
                    color: Colors.blueAccent,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Cameras
                  for (var cam in widget.camerasOnRoute)
                    Marker(
                      point: LatLng(cam.lat, cam.lng),
                      width: 40,
                      height: 40,
                      child: const JinjingMarker(size: 40),
                    ),
                  // Current Position
                  if (_currentPosition != null)
                    Marker(
                      point: _snappedMapPosition ??
                          _currentMapPosition ??
                          LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                      width: 40,
                      height: 40,
                      child: Transform.rotate(
                        angle: _heading * (math.pi / 180),
                        child: _buildLocationIcon(),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // Top Dashboard
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildTopPanel(),
          ),

          // Bottom Controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 当前步骤提示条
                if (_currentStep != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _currentStep!.instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                _buildBottomPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTurnIcon(String text) {
    if (text.contains('左转')) return Icons.turn_left;
    if (text.contains('右转')) return Icons.turn_right;
    if (text.contains('掉头') || text.contains('调头')) return Icons.u_turn_left;
    if (text.contains('左前方') || text.contains('左侧')) return Icons.turn_slight_left;
    if (text.contains('右前方') || text.contains('右侧')) return Icons.turn_slight_right;
    if (text.contains('直行') || text.contains('直走')) return Icons.straight;
    return Icons.navigation;
  }

  Widget _buildLocationIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 3),
          ),
        ),
        // Heading indicator
        Positioned(
          top: 0,
          child: Icon(Icons.arrow_upward, size: 16, color: Colors.blue[800]),
        ),
      ],
    );
  }

  Widget _buildTopPanel() {
    // 当前步骤末端有转向动作（当前路段行驶完后需执行的操作）
    final bool isTurningSoon = _currentStep != null &&
        _isActionableStep(_currentStep!) &&
        _distanceRemainingInStep != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '时速: ${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_isOffRoute)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('已偏离', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          if (_nextCamera != null && _distanceToNextCamera != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '前方摄像头: ${_distanceToNextCamera! < 1000 ? '${_distanceToNextCamera!.toStringAsFixed(0)}米' : '${(_distanceToNextCamera! / 1000).toStringAsFixed(1)}公里'}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ],
              ),
            ),
          
          // 转向提示卡片：仅在 500m 内显示；否则显示直行剩余距离
          // [已隐藏] 注释掉转向提示卡片以隐藏"右转"、"左转"等提示
          /*
          if (isTurningSoon)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTurnIcon(_currentStep!.action ?? _currentStep!.instruction),
                      size: 28,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_distanceRemainingInStep! >= 1000 ? '${(_distanceRemainingInStep! / 1000).toStringAsFixed(1)}公里' : '${_distanceRemainingInStep!.toInt()}米'} ${_getDirectionLabel(_currentStep!)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else 
          */
        ],
      ),
    );
  }

  void _reroute() {
    Navigator.of(context).pop('reroute');
  }

  Widget _buildBottomPanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧：退出 + 换航
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FloatingActionButton(
              heroTag: null,
              backgroundColor: Colors.red,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close, color: Colors.white),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
              heroTag: null,
              backgroundColor: Colors.orange,
              onPressed: _reroute,
              icon: const Icon(Icons.alt_route, color: Colors.white, size: 20),
              label: const Text('换航', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        
        // 右侧控制区域
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 语音开关
            FloatingActionButton(
              heroTag: null,
              backgroundColor: _muteVoiceGuidance ? const Color(0xFF546E7A) : Colors.white,
              onPressed: _toggleVoiceMute,
              child: Icon(
                _muteVoiceGuidance ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: _muteVoiceGuidance ? Colors.white : Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            
            // 全览按钮 (进入全览后隐藏)
            if (!_isOverviewMode) ...[
              FloatingActionButton(
                key: const ValueKey('nav_overview_btn'),
                heroTag: null,
                backgroundColor: Colors.white,
                onPressed: _enterOverviewMode,
                child: const Icon(
                  Icons.route,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
            ],

            // 根据状态显示：恢复跟随 或 (保存+状态)
            if (!_isFollowing) ...[
              if (_isOverviewMode && !_isOverviewPinned) ...[
                FloatingActionButton.extended(
                  heroTag: null,
                  backgroundColor: Colors.orange,
                  onPressed: _pinOverview,
                  icon: const Icon(Icons.push_pin_rounded, color: Colors.white, size: 20),
                  label: const Text('固定'),
                ),
                const SizedBox(width: 8),
              ],
              FloatingActionButton.extended(
                heroTag: null,
                backgroundColor: Colors.blue,
                onPressed: _resumeFollowing,
                icon: const Icon(Icons.my_location, color: Colors.white, size: 20),
                label: Text(
                  (_isOverviewMode && !_isOverviewPinned)
                      ? '恢复($_overviewCountdown)'
                      : '恢复跟随',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.navigation, color: Colors.white),
                    SizedBox(width: 8),
                    Text('导航中', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
