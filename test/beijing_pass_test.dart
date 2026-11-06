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
          today,
        );

        // 今天正好是有效期的最后一天（今天在上一个有效期内）：顺延到明天
        final lastDayRecord = BeijingPassRecord(
          id: 'rec-003',
          licensePlate: '冀A12345',
          passType: BeijingPassType.outsideSixth,
          startDate: today.subtract(const Duration(days: 6)),
          endDate: today,
          status: BeijingPassStatus.valid,
          statusDesc: '审核通过(生效中)',
        );
        expect(
          lastDayRecord.suggestedNextStartDate,
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

    test('isEssentialInfoComplete logic for bound vs unbound vehicles', () {
      // 1. 未绑定车辆 (carId 为空)：必须有 licensePlate, engineNo, vin, driverName, driverLicence
      const unboundIncomplete = BeijingPassConfig(
        licensePlate: '冀A12345',
        driverName: '张三',
        driverLicence: '130102199001011234',
        carId: '',
      );
      expect(unboundIncomplete.isEssentialInfoComplete, isFalse);

      const unboundComplete = BeijingPassConfig(
        licensePlate: '冀A12345',
        engineNo: 'ENG123',
        vin: 'VIN123456',
        driverName: '张三',
        driverLicence: '130102199001011234',
        carId: '',
      );
      expect(unboundComplete.isEssentialInfoComplete, isTrue);

      // 2. 已绑定车辆 (carId 存在)：只需 licensePlate, driverName, driverLicence，engineNo 与 vin 可选
      const boundCompleteWithoutEngineVin = BeijingPassConfig(
        licensePlate: '冀A12345',
        driverName: '张三',
        driverLicence: '130102199001011234',
        carId: 'v1479816562371952600',
      );
      expect(boundCompleteWithoutEngineVin.isEssentialInfoComplete, isTrue);

      const boundIncompleteNoDriver = BeijingPassConfig(
        licensePlate: '冀A12345',
        carId: 'v1479816562371952600',
      );
      expect(boundIncompleteNoDriver.isEssentialInfoComplete, isFalse);
    });

    test('extractDistrict identifies Beijing districts correctly', () {
      expect(
        BeijingPassService.extractDistrict('北京市海淀区中关村南大街1号'),
        '海淀区',
      );
      expect(
        BeijingPassService.extractDistrict('昌平区天通苑北一区'),
        '昌平区',
      );
      expect(
        BeijingPassService.extractDistrict('朝阳区望京SOHO'),
        '朝阳区',
      );
      expect(
        BeijingPassService.extractDistrict('百度大厦 (海淀)'),
        '海淀区',
      );
      expect(
        BeijingPassService.extractDistrict('通州梨园地铁站'),
        '通州区',
      );
      expect(
        BeijingPassService.extractDistrict('房山长阳半岛'),
        '房山区',
      );
      expect(
        BeijingPassService.extractDistrict('未知地点'),
        '昌平区', // 兜底
      );
    });

    test('buildApplyPayload produces compliant parameters for outside sixth ring', () {
      const config = BeijingPassConfig(
        token: 'test_token',
        licensePlate: '津ADY1951',
        carId: '1479816562371952600',
        driverName: '张三',
        driverLicence: '110101199001011234',
        passType: BeijingPassType.outsideSixth,
        inBeijingAddress: '北京市海淀区百度大厦',
        entranceName: '京藏高速',
        destination: '自驾旅游',
        sqdzbdjd: '116.307393',
        sqdzbdwd: '40.057771',
        sqdzgdjd: '116.300958',
        sqdzgdwd: '40.051939',
      );

      final payload = BeijingPassService.buildApplyPayload(
        config: config,
        applyDate: DateTime(2026, 9, 10),
        vId: '1479816562371952600',
      );

      // 必须为六环外进京证 (02)
      expect(payload['jjzzl'], '02');
      expect(payload['hphm'], '津ADY1951');
      expect(payload['hpzl'], '52'); // 新能源
      expect(payload['vId'], '1479816562371952600');
      expect(payload['jsrxm'], '张三');
      expect(payload['jszh'], '110101199001011234');
      expect(payload['sfzmhm'], '110101199001011234');
      expect(payload['dabh'], 'null');

      // 行政区与地址
      expect(payload['jjdq'], '海淀区');
      expect(payload['xxdz'], '北京市海淀区百度大厦');

      // 目的地与道口必须成对匹配标准码
      expect(payload['jjmd'], '01');
      expect(payload['jjmdmc'], '自驾旅游');
      expect(payload['jjlk'], '00401');
      expect(payload['jjlkmc'], '京藏高速');

      // 坐标必须为 double（官方只需要百度经纬度）
      expect(payload['sqdzbdjd'], isA<double>());
      expect(payload['sqdzbdwd'], isA<double>());
      expect(payload['sqdzbdjd'], 116.307393);
      expect(payload.containsKey('sqdzgdjd'), isFalse);
      expect(payload.containsKey('sqdzgdwd'), isFalse);

      // sfzj 必须为整数 1（在线申办模式）
      expect(payload['sfzj'], 1);

      // 日期
      expect(payload['jjrq'], '2026-09-10');

      // 不能包含未来时间戳 sqsj 以及非交管局要求的字段
      expect(payload.containsKey('sqsj'), isFalse);
      expect(payload.containsKey('txrxx'), isFalse);
    });

    test('BeijingPassVehicle extracts last driver details from records', () {
      final vehicle = BeijingPassVehicle(
        id: '12345',
        licensePlate: '冀A88888',
        records: [
          BeijingPassRecord(
            id: 'rec1',
            licensePlate: '冀A88888',
            driverName: '李四',
            driverLicence: '130102199202021234',
            status: BeijingPassStatus.expired,
          ),
        ],
      );

      expect(vehicle.lastDriverName, '李四');
      expect(vehicle.lastDriverLicence, '130102199202021234');
    });

    test('BeijingPassVehicle isPassengerCar correctly classifies vehicles', () {
      const car1 = BeijingPassVehicle(
        licensePlate: '冀A12345',
        plateType: '02',
        vehicleType: '小型普通客车',
      );
      expect(car1.isPassengerCar, isTrue);

      const newEnergyCar = BeijingPassVehicle(
        licensePlate: '津ADY1951',
        plateType: '52',
        vehicleType: '小型新能源汽车',
      );
      expect(newEnergyCar.isPassengerCar, isTrue);

      const sedan = BeijingPassVehicle(
        licensePlate: '京A88888',
        plateType: '02',
        vehicleType: '小型轿车',
      );
      expect(sedan.isPassengerCar, isTrue);

      const motorcycle = BeijingPassVehicle(
        licensePlate: '京B99999',
        plateType: '07',
        vehicleType: '普通二轮摩托车',
      );
      expect(motorcycle.isPassengerCar, isFalse);

      const lightMotorcycle = BeijingPassVehicle(
        licensePlate: '京B88888',
        plateType: '08',
        vehicleType: '轻便二轮摩托车',
      );
      expect(lightMotorcycle.isPassengerCar, isFalse);

      const truck = BeijingPassVehicle(
        licensePlate: '冀B77777',
        plateType: '01',
        vehicleType: '重型货车',
      );
      expect(truck.isPassengerCar, isFalse);
    });

    test('BeijingPassVehicle latestRecordDate identifies most recent pass date', () {
      final vNoRecord = const BeijingPassVehicle(id: 'v0');
      expect(vNoRecord.latestRecordDate, isNull);

      final vWithRecords = BeijingPassVehicle(
        id: 'v1',
        records: [
          BeijingPassRecord(
            id: 'r1',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 7),
          ),
          BeijingPassRecord(
            id: 'r2',
            startDate: DateTime(2026, 10, 15),
            endDate: DateTime(2026, 10, 21),
          ),
        ],
      );
      expect(vWithRecords.latestRecordDate, DateTime(2026, 10, 21));
    });

    test('BeijingPassService.preferredVehicle always prefers last applied passenger car', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final motorcycleWithActivePass = BeijingPassVehicle(
        id: 'moto-1',
        licensePlate: '京B11111',
        plateType: '07',
        vehicleType: '普通二轮摩托车',
        records: [
          BeijingPassRecord(
            id: 'm-rec',
            startDate: today.subtract(const Duration(days: 2)),
            endDate: today.add(const Duration(days: 4)),
            status: BeijingPassStatus.valid,
          ),
        ],
      );

      final carWithExpiredPass = BeijingPassVehicle(
        id: 'car-1',
        licensePlate: '冀A88888',
        plateType: '02',
        vehicleType: '小型普通客车',
        records: [
          BeijingPassRecord(
            id: 'c-rec',
            startDate: today.subtract(const Duration(days: 10)),
            endDate: today.subtract(const Duration(days: 3)),
            status: BeijingPassStatus.expired,
          ),
        ],
      );

      // 1. 即使摩托车有生效中进京证，也必须优先选中办理过的小客车
      final selected1 = BeijingPassService.preferredVehicle(
        vehicles: [motorcycleWithActivePass, carWithExpiredPass],
      );
      expect(selected1.id, 'car-1');
      expect(selected1.isPassengerCar, isTrue);

      // 2. 多辆小客车时，优先选中最近一次办理进京证的车辆
      final carOlder = BeijingPassVehicle(
        id: 'car-old',
        licensePlate: '冀A11111',
        plateType: '02',
        vehicleType: '小型普通客车',
        records: [
          BeijingPassRecord(
            id: 'r-old',
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 9, 7),
          ),
        ],
      );
      final carRecent = BeijingPassVehicle(
        id: 'car-new',
        licensePlate: '冀A22222',
        plateType: '02',
        vehicleType: '小型普通客车',
        records: [
          BeijingPassRecord(
            id: 'r-new',
            startDate: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 10, 7),
          ),
        ],
      );

      final selected2 = BeijingPassService.preferredVehicle(
        vehicles: [carOlder, carRecent],
      );
      expect(selected2.id, 'car-new');

      // 3. 用户在当前会话已手动选择时保持当前选择
      final selected3 = BeijingPassService.preferredVehicle(
        vehicles: [carOlder, carRecent],
        selectedVehicleId: 'car-old',
      );
      expect(selected3.id, 'car-old');

      // 4. 若无有效记录，匹配本地保存的上次办理车辆
      const carA = BeijingPassVehicle(
        id: 'c-a',
        licensePlate: '冀A12345',
        plateType: '02',
        vehicleType: '小型轿车',
      );
      const carB = BeijingPassVehicle(
        id: 'c-b',
        licensePlate: '冀A67890',
        plateType: '02',
        vehicleType: '小型轿车',
      );
      final selected4 = BeijingPassService.preferredVehicle(
        vehicles: [carA, carB],
        savedCarId: 'c-b',
      );
      expect(selected4.id, 'c-b');
    });
  });
}
