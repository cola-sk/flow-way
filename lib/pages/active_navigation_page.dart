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

      double targetZoom = 18.0;
      // 距离下一个路口或转向不足 150 米时，拉升视角（缩放级别减小）以便看清路口全貌
      if (_distanceToNextStep != null && _distanceToNextStep! < 150) {
        targetZoom = 16.5; 
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

  /// 将原始坐标吸附到导航路线上
  LatLng _calculateSnappedPosition(LatLng currentLoc) {
    if (widget.route.polylinePoints.length < 2) return currentLoc;

    double minDistance = double.infinity;
    LatLng snappedPoint = currentLoc;

    // 寻找最近的路线线段
    for (int i = 0; i < widget.route.polylinePoints.length - 1; i++) {
      final p1 = widget.route.polylinePoints[i];
      final p2 = widget.route.polylinePoints[i + 1];

      final projected = _projectPointOnSegment(currentLoc, p1, p2);
      final dist = _distanceCalc(currentLoc, projected);

      if (dist < minDistance) {
        minDistance = dist;
        snappedPoint = projected;
      }
    }

    // 如果距离路线小于 30 米，则认为在路上，进行吸附
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

  int _findNearestPolylineIndex(LatLng currentLoc) {
    double minDist = double.infinity;
    int index = 0;
    for (int i = 0; i < widget.route.polylinePoints.length; i++) {
      final d = _distanceCalc(currentLoc, widget.route.polylinePoints[i]);
      if (d < minDist) {
        minDist = d;
        index = i;
      }
    }
    return index;
  }

  void _processNavigationLogic(LatLng currentLoc) {
    if (widget.route.polylinePoints.isEmpty) return;

    // 1. Off-Route Check (True point-to-segment distance)
    double minDistanceToRoute = double.infinity;
    for (int i = 0; i < widget.route.polylinePoints.length - 1; i++) {
      final p1 = widget.route.polylinePoints[i];
      final p2 = widget.route.polylinePoints[i + 1];
      
      final projected = _projectPointOnSegment(currentLoc, p1, p2);
      final d = _distanceCalc(currentLoc, projected);
      
      if (d < minDistanceToRoute) {
        minDistanceToRoute = d;
      }
    }

    // 如果偏离距离超过 60 米，增加计数器
    final isCurrentlyOff = minDistanceToRoute > 60;
    
    if (isCurrentlyOff) {
      _offRouteCounter++;
    } else {
      _offRouteCounter = 0;
    }

    // 只有连续 3 次（约 1.5 秒）检测到偏离，才触发播报
    final offRoute = _offRouteCounter >= 3;
    
    if (offRoute && !_isOffRoute) {
      _speak("您已偏离路线，请注意行驶。");
    }
    _isOffRoute = offRoute;

    // 2. Camera Proximity Check
    // In a real app we'd project our point onto the route string and find the NEXT camera ahead.
    // For simplicity, we check absolute distances to all cameras on route and find the nearest ahead.
    Camera? nearestCam;
    double minCamDist = double.infinity;

    for (var cam in widget.camerasOnRoute) {
      final camLoc = LatLng(cam.lat, cam.lng);
      final d = _distanceCalc(currentLoc, camLoc);
      
      // simplistic "ahead" check: requires better logic in reality, but distance < 1000 is okay
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

    // 3. Navigation Steps & Turn Prompts
    int nearestIndex = _findNearestPolylineIndex(currentLoc);

    if (widget.route.steps != null && widget.route.steps!.isNotEmpty) {
      // 找到当前所在步骤（以终点索引来判断，只要路段终点在前方，说明仍在当前步骤）
      int currentStepIndex = -1;
      for (int i = 0; i < widget.route.steps!.length; i++) {
        final step = widget.route.steps![i];
        if (step.polylineIdxEnd >= nearestIndex) {
          currentStepIndex = i;
          break;
        }
      }

      if (currentStepIndex != -1 && currentStepIndex + 1 < widget.route.steps!.length) {
        final nextStep = widget.route.steps![currentStepIndex + 1];
        
        // 计算沿路线到达下一步骤起点的距离
        double distToNext = 0.0;
        int targetIdx = nextStep.polylineIdxStart;
        
        if (targetIdx > nearestIndex && nearestIndex + 1 < widget.route.polylinePoints.length) {
          distToNext += _distanceCalc(currentLoc, widget.route.polylinePoints[nearestIndex + 1]);
          for (int i = nearestIndex + 1; i < targetIdx; i++) {
            if (i + 1 < widget.route.polylinePoints.length) {
              distToNext += _distanceCalc(widget.route.polylinePoints[i], widget.route.polylinePoints[i+1]);
            }
          }
        }
        
        setState(() {
          _nextStep = nextStep;
          _distanceToNextStep = distToNext;
        });

        // 转向语音播报逻辑
        if (distToNext > 0) {
          final stepId = nextStep.polylineIdxStart.toString();
          
          // 2. 近距离确认提醒 (150 米以内)
          if (distToNext <= 150 && distToNext > 30) {
            final key150 = "${stepId}_150m";
            if (!_alertedSteps.contains(key150)) {
              _alertedSteps.add(key150);
              // 去掉原始 instruction 可能自带的"前方xxx米"，直接组合
              _speak("前方 ${distToNext.round()} 米，${nextStep.instruction}");
            }
          }
          // 3. 动作执行提醒 (30 米以内)
          else if (distToNext <= 30) {
            final key30 = "${stepId}_30m";
            if (!_alertedSteps.contains(key30)) {
              _alertedSteps.add(key30);
              _speak(nextStep.instruction);
            }
          }
        }
      } else {
        setState(() {
          _nextStep = null;
          _distanceToNextStep = null;
        });
      }
    }
  }

  void _enterOverviewMode() {
    if (!mounted) return;
    
    setState(() {
      _isOverviewMode = true;
      _isFollowing = false;
    });

    _fitRouteOverview();
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
    } catch (e) {
      debugPrint('Fit route overview failed: $e');
      _mapController.move(widget.route.startPoint, 12.0);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
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
              initialZoom: 18.0,
              minZoom: 3.0,
              maxZoom: 20.0,
              // rotation properties?
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  if (_isFollowing) setState(() => _isFollowing = false);
                  if (_isOverviewMode) setState(() => _isOverviewMode = false);
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
            child: _buildBottomPanel(),
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
          
          // 转向提示卡片
          if (_nextStep != null && _distanceToNextStep != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
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
                      _getTurnIcon(_nextStep!.action ?? _nextStep!.instruction), 
                      size: 28, 
                      color: Colors.blue[800]
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _distanceToNextStep! > 1000 
                            ? '前方 ${(_distanceToNextStep! / 1000).toStringAsFixed(1)} 公里'
                            : '前方 ${_distanceToNextStep!.toInt()} 米',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        Text(
                          _nextStep!.instruction,
                          style: const TextStyle(fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_nextStep!.distance > 0 || _nextStep!.duration > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '本段路程: ${_nextStep!.distance >= 1000 ? '${(_nextStep!.distance / 1000).toStringAsFixed(1)} 公里' : '${_nextStep!.distance.toInt()} 米'}  •  预计: ${(_nextStep!.duration / 60).ceil()} 分钟',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ),
                      ],
                    )
                  ),
                ],
              )
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 左侧退出按钮
        FloatingActionButton(
          heroTag: null,
          backgroundColor: Colors.red,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.close, color: Colors.white),
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
            if (!_isFollowing)
              FloatingActionButton.extended(
                heroTag: null,
                backgroundColor: Colors.blue,
                onPressed: () {
                  // 获取目标位置，如果没有当前定位则回退到路线起点
                  final targetPos = _snappedMapPosition ?? 
                                   _currentMapPosition ?? 
                                   widget.route.startPoint;
                  
                  setState(() {
                    _isFollowing = true;
                    _isOverviewMode = false;
                  });

                  _mapController.moveAndRotate(
                    targetPos,
                    18.0,
                    360.0 - _heading,
                  );
                },
                icon: const Icon(Icons.my_location, color: Colors.white),
                label: const Text('恢复跟随'),
              )
            else ...[
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
