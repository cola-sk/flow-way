import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_way/models/beijing_pass_model.dart';
import 'package:flow_way/services/beijing_pass_service.dart';

void main() {
  group('BeijingPassModel Tests', () {
    test('BeijingPassConfig JSON serialization and deserialization', () {
      const config = BeijingPassConfig(
        token: 'Bearer test_token_123',
        licensePlate: '冀A12345',
        carModel: '小型普通客车',
        engineNo: 'ENG987654',
        vin: 'VIN123456',
        carId: 'car-999',
        driverName: '张三',
        driverLicence: '130102199001011234',
        passType: BeijingPassType.outsideSixth,
        entranceName: '京藏高速',
        destination: '昌平区',
      );

      final jsonStr = config.toJsonString();
      final restored = BeijingPassConfig.fromJsonString(jsonStr);

      expect(restored.token, 'Bearer test_token_123');
      expect(restored.licensePlate, '冀A12345');
      expect(restored.engineNo, 'ENG987654');
      expect(restored.vin, 'VIN123456');
      expect(restored.carId, 'car-999');
      expect(restored.driverName, '张三');
      expect(restored.driverLicence, '130102199001011234');
      expect(restored.passType, BeijingPassType.outsideSixth);
      expect(restored.entranceName, '京藏高速');
      expect(restored.destination, '昌平区');
      expect(restored.isTokenConfigured, isTrue);
      expect(restored.isEssentialInfoComplete, isTrue);
    });

    test(
      'BeijingPassRecord remainingDays & isValidNow & suggestedNextStartDate',
      () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // 有效进京证：从昨天到后天（3天后到期）
        final activeRecord = BeijingPassRecord(
          id: 'rec-001',
          licensePlate: '冀A12345',
          passType: BeijingPassType.outsideSixth,
          startDate: today.subtract(const Duration(days: 1)),
          endDate: today.add(const Duration(days: 3)),
          status: BeijingPassStatus.valid,
          statusDesc: '审核通过',
        );

        expect(activeRecord.isValidNow, isTrue);
        expect(activeRecord.remainingDays, 4); // 包含今天、明天、后天、大后天
        expect(
          activeRecord.suggestedNextStartDate,
          today.add(const Duration(days: 4)),
        );

        // 已过期进京证
        final expiredRecord = BeijingPassRecord(
          id: 'rec-002',
          licensePlate: '冀A12345',
          passType: BeijingPassType.outsideSixth,
          startDate: today.subtract(const Duration(days: 10)),
          endDate: today.subtract(const Duration(days: 3)),
          status: BeijingPassStatus.expired,
          statusDesc: '已失效',
        );

        expect(expiredRecord.isValidNow, isFalse);
        expect(expiredRecord.remainingDays, 0);
        expect(
          expiredRecord.suggestedNextStartDate,
          today.add(const Duration(days: 1)),
        );
      },
    );
  });

  group('BeijingPassService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('BeijingPassService saveConfig & loadConfig', () async {
      final service = BeijingPassService();

      var initial = await service.loadConfig();
      expect(initial.token, isEmpty);
      expect(initial.isTokenConfigured, isFalse);

      const newConfig = BeijingPassConfig(
        token: 'token_abc_xyz',
        licensePlate: '京A88888',
        passType: BeijingPassType.insideSixth,
      );

      await service.saveConfig(newConfig);

      final loaded = await service.loadConfig();
      expect(loaded.token, 'token_abc_xyz');
      expect(loaded.licensePlate, '京A88888');
      expect(loaded.passType, BeijingPassType.insideSixth);
    });

    test('parseTokenExpiry with valid JWT token', () {
      final expTime = DateTime.now().add(const Duration(days: 15));
      final expSeconds = expTime.millisecondsSinceEpoch ~/ 1000;

      final header = base64Url
          .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
          .replaceAll('=', '');
      final payload = base64Url
          .encode(
            utf8.encode(jsonEncode({'userId': '123456', 'exp': expSeconds})),
          )
          .replaceAll('=', '');
      final dummyJwt = '$header.$payload.dummySignature';

      final parsed = BeijingPassService.parseTokenExpiry('Bearer $dummyJwt');
      expect(parsed, isNotNull);
      expect(parsed!.difference(expTime).inSeconds.abs(), lessThanOrEqualTo(1));
    });

    test('parseTokenExpiry with invalid token returns null', () {
      expect(
        BeijingPassService.parseTokenExpiry('random_non_jwt_token'),
        isNull,
      );
    });
  });
}
