import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_way/models/camera.dart';
import 'package:flow_way/models/monitored_area.dart';
import 'package:flow_way/services/monitored_area_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MonitoredArea Model Tests', () {
    test('circle containsPoint correctly tests radius', () {
      // 北京天安门附近坐标: 39.9042, 116.4074
      final area = MonitoredArea.circle(
        id: 'test-circle',
        name: '天安门周边',
        centerLat: 39.9042,
        centerLng: 116.4074,
        radiusMeters: 3000, // 3km
      );

      // 距离约 1km 的点位（王府井附近: 39.9080, 116.4130）
      expect(area.containsPoint(39.9080, 116.4130), isTrue);

      // 距离约 15km 的点位（通州或者昌平附近: 40.05, 116.40）
      expect(area.containsPoint(40.05, 116.40), isFalse);
    });

    test('rectangle containsPoint correctly tests bounding box', () {
      final area = MonitoredArea.rectangle(
        id: 'test-rect',
        name: '望京片区',
        southWestLat: 39.980,
        southWestLng: 116.460,
        northEastLat: 40.020,
        northEastLng: 116.500,
      );

      // 盒内
      expect(area.containsPoint(40.000, 116.480), isTrue);
      // 边界外
      expect(area.containsPoint(39.950, 116.480), isFalse);
      expect(area.containsPoint(40.000, 116.550), isFalse);
    });
  });

  group('MonitoredAreaService Change Detection Tests', () {
    test('baseline snapshot does not trigger false alerts on first run', () async {
      final service = MonitoredAreaService();

      final area = MonitoredArea.circle(
        id: 'area-1',
        name: '测试区域',
        centerLat: 39.9042,
        centerLng: 116.4074,
        radiusMeters: 5000,
      );
      await service.saveArea(area);

      final cameras = [
        Camera(
          name: '探头A',
          lat: 39.9050,
          lng: 116.4080,
          type: 2,
          date: '2026-11-01',
          edittime: '2026-11-01 10:00:00',
          href: '',
        ),
      ];

      // 首次运行，建立基准快照
      final summaries = await service.checkChanges(cameras);
      expect(summaries.isEmpty, isTrue);

      final unread = await service.getUnreadSummaries();
      expect(unread.isEmpty, isTrue);
    });

    test('detects added, removed, typeChanged, and infoChanged cameras accurately', () async {
      final service = MonitoredAreaService();

      final area = MonitoredArea.circle(
        id: 'area-2',
        name: '测试变动区域',
        centerLat: 39.9042,
        centerLng: 116.4074,
        radiusMeters: 5000,
      );
      await service.saveArea(area);

      // 初始数据：探头A、探头B、探头C
      final initialCameras = [
        Camera(
          name: '探头A',
          lat: 39.9050,
          lng: 116.4080,
          type: 2,
          date: '2026-11-01',
          edittime: '2026-11-01 10:00:00',
          href: '',
        ),
        Camera(
          name: '探头B',
          lat: 39.9060,
          lng: 116.4090,
          type: 6,
          date: '2026-11-01',
          edittime: '2026-11-01 10:00:00',
          href: '',
        ),
        Camera(
          name: '探头C',
          lat: 39.9070,
          lng: 116.4100,
          type: 1,
          date: '2026-11-01',
          edittime: '2026-11-01 10:00:00',
          href: '',
        ),
        // 区域外探头：即使它变动也不影响该区域
        Camera(
          name: '区域外探头X',
          lat: 40.5000,
          lng: 116.4000,
          type: 6,
          date: '2026-11-01',
          href: '',
        ),
      ];

      // 1. 初始化基准
      await service.checkChanges(initialCameras);

      // 2. 第二次更新：
      // - 探头A: 规则由 2 变更为 5 (typeChanged)
      // - 探头B: 被删除/下线 (removed)
      // - 探头C: edittime 变更 (infoChanged)
      // - 探头D: 新增探头 (added)
      final updatedCameras = [
        Camera(
          name: '探头A',
          lat: 39.9050,
          lng: 116.4080,
          type: 5, // 变更为 5
          date: '2026-11-01',
          edittime: '2026-11-01 10:00:00',
          href: '',
        ),
        // 探头B 缺席 -> removed
        Camera(
          name: '探头C',
          lat: 39.9070,
          lng: 116.4100,
          type: 1,
          date: '2026-11-01',
          edittime: '2026-11-06 14:00:00', // edittime 变动
          href: '',
        ),
        Camera(
          name: '探头D',
          lat: 39.9080,
          lng: 116.4110,
          type: 2,
          date: '2026-11-06',
          edittime: '2026-11-06 15:00:00',
          href: '',
        ),
        // 区域外探头新增，不应该计入该区域
        Camera(
          name: '区域外探头Y',
          lat: 40.6000,
          lng: 116.4000,
          type: 6,
          date: '2026-11-06',
          href: '',
        ),
      ];

      final summaries = await service.checkChanges(updatedCameras);
      expect(summaries.length, equals(1));

      final summary = summaries.first;
      expect(summary.areaName, equals('测试变动区域'));
      expect(summary.totalChanges, equals(4));
      expect(summary.addedCount, equals(1));
      expect(summary.removedCount, equals(1));
      expect(summary.typeChangedCount, equals(1));
      expect(summary.infoChangedCount, equals(1));

      // 检查未读状态
      final unread = await service.getUnreadSummaries();
      expect(unread.length, equals(1));

      // 全部标记已读
      await service.markAllSummariesAsRead();
      final afterRead = await service.getUnreadSummaries();
      expect(afterRead.isEmpty, isTrue);
    });

    test('simulation test injects mock changes and produces summary', () async {
      final service = MonitoredAreaService();

      final area = MonitoredArea.circle(
        id: 'sim-area',
        name: '模拟测试区',
        centerLat: 39.9042,
        centerLng: 116.4074,
        radiusMeters: 3000,
      );
      await service.saveArea(area);

      final cameras = [
        Camera(
          name: '已有探头1',
          lat: 39.9045,
          lng: 116.4078,
          type: 6,
          date: '2026-11-01',
          href: '',
        ),
      ];

      final summary = await service.simulateTestChanges(area.id, cameras);
      expect(summary, isNotNull);
      expect(summary!.records.isNotEmpty, isTrue);
      expect(
        summary.records.any((r) => r.changeType == CameraChangeType.added),
        isTrue,
      );

      final unread = await service.getUnreadSummaries();
      expect(unread.isNotEmpty, isTrue);
    });
  });
}
