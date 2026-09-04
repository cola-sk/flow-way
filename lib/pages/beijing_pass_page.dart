import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/beijing_pass_model.dart';
import '../services/api_service.dart';
import '../services/beijing_pass_service.dart';

class BeijingPassPage extends StatefulWidget {
  const BeijingPassPage({super.key});

  @override
  State<BeijingPassPage> createState() => _BeijingPassPageState();
}

class _BeijingPassPageState extends State<BeijingPassPage> {
  final BeijingPassService _service = BeijingPassService();

  late BeijingPassConfig _config;
  bool _loadingConfig = true;
  bool _queryingStatus = false;
  bool _submittingApply = false;
  bool _savingConfig = false;

  BeijingPassFetchResult? _lastFetchResult;
  DateTime? _tokenExpiry;
  String? _selectedVehicleId;
  String _plateType = '';
  bool _supplementExpanded = true;
  bool _preferencesExpanded = false;
  bool _isEditingToken = false;
  final Map<String, BeijingPassVehicleSupplement> _vehicleSupplements = {};

  // Controllers
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _engineNoController = TextEditingController();
  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _carIdController = TextEditingController();
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverLicenceController =
      TextEditingController();
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _inBeijingAddressController =
      TextEditingController();
  final TextEditingController _sqdzgdjdController = TextEditingController();
  final TextEditingController _sqdzgdwdController = TextEditingController();
  final TextEditingController _sqdzbdjdController = TextEditingController();
  final TextEditingController _sqdzbdwdController = TextEditingController();
  final TextEditingController _customApiBaseController =
      TextEditingController();

  BeijingPassType _selectedPassType = BeijingPassType.outsideSixth;
  bool _isInBeijing = false;
  DateTime _selectedApplyStartDate = DateTime.now().add(
    const Duration(days: 1),
  );

  @override
  void initState() {
    super.initState();
    _loadConfigAndInit();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _plateController.dispose();
    _carModelController.dispose();
    _engineNoController.dispose();
    _vinController.dispose();
    _carIdController.dispose();
    _driverNameController.dispose();
    _driverLicenceController.dispose();
    _entranceController.dispose();
    _destinationController.dispose();
    _inBeijingAddressController.dispose();
    _sqdzgdjdController.dispose();
    _sqdzgdwdController.dispose();
    _sqdzbdjdController.dispose();
    _sqdzbdwdController.dispose();
    _customApiBaseController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigAndInit() async {
    setState(() => _loadingConfig = true);
    final cfg = await _service.loadConfig();
    _config = cfg;

    _tokenController.text = cfg.token;
    _isEditingToken = cfg.token.trim().isEmpty;
    _plateController.text = cfg.licensePlate;
    _plateType = cfg.plateType;
    _carModelController.text = cfg.carModel;
    _engineNoController.text = cfg.engineNo;
    _vinController.text = cfg.vin;
    _carIdController.text = cfg.carId;
    _driverNameController.text = cfg.driverName;
    _driverLicenceController.text = cfg.driverLicence;
    _entranceController.text = cfg.entranceName == '京藏高速'
        ? '其他道路'
        : cfg.entranceName;
    _destinationController.text = cfg.destination == '昌平区'
        ? '其它'
        : cfg.destination;
    _inBeijingAddressController.text = cfg.inBeijingAddress.isNotEmpty
        ? cfg.inBeijingAddress
        : '昌平北站';
    _sqdzgdjdController.text = cfg.sqdzgdjd.isNotEmpty
        ? cfg.sqdzgdjd
        : '116.231525';
    _sqdzgdwdController.text = cfg.sqdzgdwd.isNotEmpty
        ? cfg.sqdzgdwd
        : '40.231452';
    _sqdzbdjdController.text = cfg.sqdzbdjd.isNotEmpty
        ? cfg.sqdzbdjd
        : '116.237936';
    _sqdzbdwdController.text = cfg.sqdzbdwd.isNotEmpty
        ? cfg.sqdzbdwd
        : '40.237461';
    _customApiBaseController.text = cfg.customApiBase;
    _selectedPassType = cfg.passType;
    _isInBeijing = cfg.isInBeijing;
    _vehicleSupplements.addAll(cfg.vehicleSupplements);
    _supplementExpanded = !_supplementComplete;

    _updateTokenExpiry(cfg.token);

    if (mounted) {
      setState(() => _loadingConfig = false);
    }

    if (cfg.isTokenConfigured) {
      _refreshStatus(silent: true);
    }
  }

  void _updateTokenExpiry(String token) {
    _tokenExpiry = BeijingPassService.parseTokenExpiry(token);
  }

  String _maskToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return '未配置';
    if (t.length <= 16) {
      final len = (t.length / 3).floor();
      return '${t.substring(0, len)}****${t.substring(t.length - len)}';
    }
    final prefix = t.substring(0, 10);
    final suffix = t.substring(t.length - 6);
    return '$prefix****$suffix';
  }

  BeijingPassVehicle? get _selectedVehicle {
    final vehicles = _lastFetchResult?.vehicles ?? const <BeijingPassVehicle>[];
    if (vehicles.isEmpty) return null;
    return _preferredVehicle(vehicles);
  }

  /// 初次进入页面时优先展示当前有生效进京证的车辆；用户已手动选择后保持原选择。
  BeijingPassVehicle _preferredVehicle(List<BeijingPassVehicle> vehicles) {
    for (final vehicle in vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    for (final vehicle in vehicles) {
      if (vehicle.activeRecord?.isValidNow == true) return vehicle;
    }
    return vehicles.first;
  }

  BeijingPassRecord? get _selectedActiveRecord =>
      _selectedVehicle?.activeRecord;

  bool get _supplementComplete {
    final hasPlate = _plateController.text.trim().isNotEmpty;
    final hasDriver =
        _driverNameController.text.trim().isNotEmpty &&
        _driverLicenceController.text.trim().isNotEmpty;
    if (!hasPlate || !hasDriver) return false;
    if (_selectedVehicle != null) return true;
    return _engineNoController.text.trim().isNotEmpty &&
        _vinController.text.trim().isNotEmpty;
  }

  void _storeCurrentVehicleSupplement() {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;
    _vehicleSupplements[vehicleId] = BeijingPassVehicleSupplement(
      carModel: _carModelController.text.trim(),
      engineNo: _engineNoController.text.trim(),
      vin: _vinController.text.trim(),
      driverName: _driverNameController.text.trim(),
      driverLicence: _driverLicenceController.text.trim(),
    );
  }

  void _selectVehicle(BeijingPassVehicle vehicle) {
    _storeCurrentVehicleSupplement();
    _selectedVehicleId = vehicle.id;
    _carIdController.text = vehicle.id;
    _plateController.text = vehicle.licensePlate;
    _plateType = vehicle.plateType;
    final supplement = _vehicleSupplements[vehicle.id];
    _carModelController.text = supplement?.carModel.isNotEmpty == true
        ? supplement!.carModel
        : vehicle.vehicleType.isNotEmpty
        ? vehicle.vehicleType
        : _config.carModel;
    _engineNoController.text = supplement?.engineNo ?? _config.engineNo;
    _vinController.text = supplement?.vin ?? _config.vin;

    // 优先使用当前车辆已保存的补充资料，其次使用全局配置，若均为空则自动带入交警系统历史记录中的驾驶人
    final driverName = supplement?.driverName.isNotEmpty == true
        ? supplement!.driverName
        : _config.driverName.isNotEmpty
        ? _config.driverName
        : vehicle.lastDriverName;
    final driverLicence = supplement?.driverLicence.isNotEmpty == true
        ? supplement!.driverLicence
        : _config.driverLicence.isNotEmpty
        ? _config.driverLicence
        : vehicle.lastDriverLicence;

    _driverNameController.text = driverName;
    _driverLicenceController.text = driverLicence;
    _supplementExpanded = !_supplementComplete;

    final record = vehicle.activeRecord;
    if (record != null) {
      _selectedPassType = record.passType;
      _selectedApplyStartDate = record.suggestedNextStartDate;
    }
  }

  /// 将 GCJ-02 (高德/腾讯) 经纬度转换为 BD-09 (百度) 经纬度
  static (double bdLat, double bdLng) _gcj02ToBd09(
    double gcjLat,
    double gcjLng,
  ) {
    const double xPi = 3.14159265358979324 * 3000.0 / 180.0;
    final double z =
        sqrt(gcjLng * gcjLng + gcjLat * gcjLat) + 0.00002 * sin(gcjLat * xPi);
    final double theta = atan2(gcjLat, gcjLng) + 0.000003 * cos(gcjLng * xPi);
    final double bdLng = z * cos(theta) + 0.0065;
    final double bdLat = z * sin(theta) + 0.006;
    return (bdLat, bdLng);
  }

  /// 设置并同步位置名称与高德/百度坐标
  void _applyLocationAndCoordinates({
    required String name,
    required double gcjLat,
    required double gcjLng,
  }) {
    final (bdLat, bdLng) = _gcj02ToBd09(gcjLat, gcjLng);
    setState(() {
      _inBeijingAddressController.text = name;
      _sqdzgdjdController.text = gcjLng.toStringAsFixed(6);
      _sqdzgdwdController.text = gcjLat.toStringAsFixed(6);
      _sqdzbdjdController.text = bdLng.toStringAsFixed(6);
      _sqdzbdwdController.text = bdLat.toStringAsFixed(6);
    });
  }

  /// 重置为默认位置（昌平北站）
  void _resetToDefaultLocation() {
    FocusManager.instance.primaryFocus?.unfocus();
    _applyLocationAndCoordinates(
      name: '昌平北站',
      gcjLat: 40.231452,
      gcjLng: 116.231525,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已重置为默认位置（昌平北站）及对应坐标'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 唤起地点搜索弹窗
  Future<void> _openLocationSearch(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final place = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          _BeijingPassLocationSearchModal(apiService: _service.apiService),
    );

    if (place != null && mounted) {
      final name = place.name.isNotEmpty
          ? place.name
          : (place.address.isNotEmpty ? place.address : '所选位置');
      _applyLocationAndCoordinates(
        name: name,
        gcjLat: place.location.latitude,
        gcjLng: place.location.longitude,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已选中“$name”并自动更新高德/百度坐标'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  BeijingPassConfig _buildCurrentConfigFromForm() {
    _storeCurrentVehicleSupplement();
    return _config.copyWith(
      token: _tokenController.text.trim(),
      licensePlate: _plateController.text.trim().toUpperCase(),
      plateType: _plateType,
      carModel: _carModelController.text.trim(),
      engineNo: _engineNoController.text.trim(),
      vin: _vinController.text.trim(),
      carId: _carIdController.text.trim(),
      driverName: _driverNameController.text.trim(),
      driverLicence: _driverLicenceController.text.trim(),
      passType: _selectedPassType,
      entranceName: _entranceController.text.trim(),
      destination: _destinationController.text.trim(),
      isInBeijing: _isInBeijing,
      inBeijingAddress: _inBeijingAddressController.text.trim(),
      sqdzgdjd: _sqdzgdjdController.text.trim(),
      sqdzgdwd: _sqdzgdwdController.text.trim(),
      sqdzbdjd: _sqdzbdjdController.text.trim(),
      sqdzbdwd: _sqdzbdwdController.text.trim(),
      customApiBase: _customApiBaseController.text.trim(),
      vehicleSupplements: Map<String, BeijingPassVehicleSupplement>.from(
        _vehicleSupplements,
      ),
    );
  }

  Future<void> _saveConfig() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _savingConfig = true);
    final updated = _buildCurrentConfigFromForm();
    final ok = await _service.saveConfig(updated);
    if (!mounted) return;
    setState(() {
      _config = updated;
      _savingConfig = false;
      if (updated.token.isNotEmpty) {
        _isEditingToken = false;
      }
    });
    _updateTokenExpiry(updated.token);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '预填配置已保存到本地' : '保存失败，请重试'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 提交前静默保存当前表单，确保下次打开时仍保留本次预填内容。
  Future<void> _saveConfigBeforeSubmit(BeijingPassConfig config) async {
    try {
      final ok = await _service.saveConfig(config);
      if (ok) {
        _config = config;
        _updateTokenExpiry(config.token);
      }
    } catch (_) {
      // 本地保存失败不应阻断用户已经确认的提交请求。
    }
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final currentCfg = _buildCurrentConfigFromForm();
    if (!currentCfg.isTokenConfigured) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先填入北京交警 Authorization Token'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _queryingStatus = true);
    final result = await _service.fetchPassStatus(currentCfg);
    if (!mounted) return;

    setState(() {
      _lastFetchResult = result;
      _queryingStatus = false;
      if (result.vehicles.isNotEmpty) {
        final target = _preferredVehicle(result.vehicles);
        _selectVehicle(target);
      } else if (result.activeRecord != null) {
        _selectedApplyStartDate = result.activeRecord!.suggestedNextStartDate;
      }
    });

    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? Colors.green.shade700
              : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitRenewPass() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final cfg = _buildCurrentConfigFromForm();
    if (!cfg.isTokenConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写 Token 后再提交申请'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先通过 Token 加载并选择一辆车辆'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_isInBeijing && _inBeijingAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('选择“当前已在北京”时，请填写在京详细地址'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!cfg.isEssentialInfoComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedVehicle != null
              ? '请先完善驾驶人姓名与身份证/驾驶证号'
              : '请先完善车辆及驾驶人必填信息（车牌、发动机号、车架号、驾驶人信息）'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isInsideSixth = cfg.passType == BeijingPassType.insideSixth;
    final vehicle = _selectedVehicle;
    final activeRecord = vehicle?.activeRecord;

    // 续签时间提示：交警系统规定同类型进京证仅在到期前最后 1 天内允许申请顺延续签
    if (activeRecord != null &&
        activeRecord.isValidNow &&
        activeRecord.passType == cfg.passType &&
        activeRecord.remainingDays > 1) {
      final endStr = activeRecord.endDate != null
          ? _formatDate(activeRecord.endDate!)
          : '';
      final canContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('当前进京证尚未到期'),
          content: Text(
            '当前${activeRecord.passType.label}还有 ${activeRecord.remainingDays} 天有效期${endStr.isNotEmpty ? '（至 $endStr）' : ''}。\n\n'
            '交管部门规定：进京证仅可在有效期的最后一天（剩余 1 天以内）办理顺延续签，提前提交将被交警系统退回。\n\n'
            '确定仍要尝试提交吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('稍后再办'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
              ),
              child: const Text('仍然提交'),
            ),
          ],
        ),
      );
      if (canContinue != true) {
        return;
      }
      if (!mounted) return;
    }

    // 仅当当前车辆存在相同类型、且当前有效/生效中的进京证时，才传递 applyIdOld 进行顺延续签
    final applyIdOld = (activeRecord != null &&
            activeRecord.isValidNow &&
            activeRecord.passType == cfg.passType &&
            activeRecord.id.isNotEmpty)
        ? activeRecord.id
        : null;
    final vId = vehicle?.id.isNotEmpty == true ? vehicle!.id : cfg.carId;

    // 确认弹窗
    final applyDateStr =
        '${_selectedApplyStartDate.year}-${_selectedApplyStartDate.month.toString().padLeft(2, '0')}-${_selectedApplyStartDate.day.toString().padLeft(2, '0')}';
    final districtName = BeijingPassService.extractDistrict(cfg.inBeijingAddress);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认提交进京证申请'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('车牌号码：${cfg.licensePlate}'),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('证件类型：'),
                Expanded(
                  child: Text(
                    cfg.passType.label,
                    style: TextStyle(
                      color: isInsideSixth ? Colors.red.shade700 : null,
                      fontWeight: isInsideSixth
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isInsideSixth) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade400, width: 1.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ 正在办理「六环内进京证」',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '六环内进京证每辆外埠车每年最多仅可办理 12 次（每次有效期 7 天），请确认确需消耗六环内指标！',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text('生效日期：$applyDateStr (7天)'),
            const SizedBox(height: 4),
            Text('所属行政区：$districtName'),
            const SizedBox(height: 4),
            Text('进京/在京地址：${cfg.inBeijingAddress}'),
            const SizedBox(height: 4),
            Text(
              '坐标：高德(${cfg.sqdzgdjd}, ${cfg.sqdzgdwd}) · 百度(${cfg.sqdzbdjd}, ${cfg.sqdzbdwd})',
              style: TextStyle(
                fontSize: 10.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text('进京道口：${cfg.entranceName}'),
            const SizedBox(height: 4),
            Text('目的地：${cfg.destination}'),
            const SizedBox(height: 8),
            const Text(
              '提交后交警系统将进入审核流程。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: isInsideSixth
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isInsideSixth ? '确认办理六环内' : '确认提交'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submittingApply = true);
    // 先静默保存最新配置，再发起提交请求。
    await _saveConfigBeforeSubmit(cfg);

    final result = await _service.submitApplyRecord(
      config: cfg,
      applyDate: _selectedApplyStartDate,
      applyDays: 7,
      applyIdOld: applyIdOld,
      vId: vId,
    );

    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submittingApply = false);

    if (result.success) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('提交成功'),
          content: Text(result.message),
          actions: [
            FilledButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(ctx).pop();
                _refreshStatus(silent: true);
              },
              child: const Text('好的'),
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          title: const Text('申请提交失败'),
          content: Text(result.message),
          actions: [
            FilledButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(ctx).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  void _showTokenHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('如何获取 Token？'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '1. 使用抓包软件（如 Reqable、Charles、HttpCanary 或 VNET）连接手机；\n'
                '2. 打开《北京交警》App 并进入进京证相关页面；\n'
                '3. 在抓包列表中搜索域名包含 zhongchebaolian.com 或路径包含 applyRecordController 的请求；\n'
                '4. 复制 Request Header 中的 Authorization 字段完整内容（形如 Bearer eyJhbGci...）；\n'
                '5. 粘贴到下方的 Token 输入框并点击保存。',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                '提示：Token 存储在本地设备，通常可维持数周有效。若手机上退出交警账号则会失效，需重新抓取。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('北京进京证助手'),
        actions: [
          IconButton(
            tooltip: '抓包教程与帮助',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _showTokenHelpDialog();
            },
          ),
          IconButton(
            tooltip: '刷新状态',
            icon: _queryingStatus
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _queryingStatus ? null : () => _refreshStatus(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: _loadingConfig
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                  children: [
                    _buildTokenSection(theme),
                    const SizedBox(height: 10),
                    _buildVehicleSection(theme),
                    const SizedBox(height: 10),
                    _buildStatusCard(theme),
                    const SizedBox(height: 10),
                    _buildCarProfileSection(theme),
                    const SizedBox(height: 10),
                    _buildApplyPreferencesSection(theme),
                    const SizedBox(height: 10),
                    _buildSubmitSection(theme),
                    if (_lastFetchResult?.records.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      _buildHistoryRecordsSection(theme),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  /// 状态卡片
  Widget _buildStatusCard(ThemeData theme) {
    final active = _selectedActiveRecord;
    final isConfigured = _tokenController.text.trim().isNotEmpty;

    Color badgeColor;
    String statusTitle;
    IconData statusIcon;

    if (!isConfigured) {
      badgeColor = Colors.grey;
      statusTitle = '未配置 Token';
      statusIcon = Icons.link_off_rounded;
    } else if (_lastFetchResult == null) {
      badgeColor = theme.colorScheme.primary;
      statusTitle = '待查询 / 点击右上角刷新';
      statusIcon = Icons.help_outline_rounded;
    } else if (!_lastFetchResult!.success) {
      badgeColor = Colors.red.shade700;
      statusTitle = _lastFetchResult!.isTokenInvalid ? 'Token 已失效' : '查询异常';
      statusIcon = Icons.error_outline_rounded;
    } else if (active != null && active.isValidNow) {
      badgeColor = Colors.green.shade700;
      statusTitle = '有效进京证生效中';
      statusIcon = Icons.verified_rounded;
    } else if (active != null && active.status == BeijingPassStatus.reviewing) {
      badgeColor = Colors.orange.shade800;
      statusTitle = '进京证审核中';
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      badgeColor = Colors.blueGrey;
      statusTitle = '当前无生效进京证';
      statusIcon = Icons.info_outline_rounded;
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                      if (active?.licensePlate.isNotEmpty == true)
                        Text(
                          '${active!.licensePlate} · ${active.passType.shortLabel}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (active != null && active.isValidNow)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '剩余 ${active.remainingDays} 天',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            if (active != null &&
                active.startDate != null &&
                active.endDate != null) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '有效期限',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  Text(
                    '${_formatDate(active.startDate!)} 至 ${_formatDate(active.endDate!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            if (_tokenExpiry != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Token 预计到期',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  Text(
                    _formatDateTime(_tokenExpiry!),
                    style: TextStyle(
                      fontSize: 11,
                      color: _tokenExpiry!.isBefore(DateTime.now())
                          ? Colors.red
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Token 配置区域
  Widget _buildTokenSection(ThemeData theme) {
    final token = _tokenController.text.trim();
    final showMasked = !_isEditingToken && token.isNotEmpty;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.vpn_key_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '北京交警 Token 凭证',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (showMasked)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () => setState(() => _isEditingToken = true),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text(
                      '修改',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () async {
                      final data = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (!mounted) return;
                      if (data?.text != null && data!.text!.trim().isNotEmpty) {
                        _tokenController.text = data.text!.trim();
                        _updateTokenExpiry(data.text!.trim());
                        setState(() => _isEditingToken = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已从剪贴板粘贴 Token'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.paste_rounded, size: 14),
                    label: const Text(
                      '粘贴',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (showMasked)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _maskToken(token),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: token));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制 Token 到剪贴板'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        _tokenController.clear();
                        setState(() {
                          _tokenExpiry = null;
                          _isEditingToken = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.clear_rounded,
                          size: 15,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              TextField(
                controller: _tokenController,
                maxLines: 1,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '填入 Authorization: Bearer xxx 或直接粘贴 Token',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_tokenController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.check_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: '完成',
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _isEditingToken = false);
                          },
                        ),
                      if (_tokenController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 15),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _tokenController.clear();
                            setState(() => _tokenExpiry = null);
                          },
                        ),
                    ],
                  ),
                ),
                onChanged: (val) => setState(() => _updateTokenExpiry(val)),
                onSubmitted: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (_tokenController.text.trim().isNotEmpty) {
                    setState(() => _isEditingToken = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 通过 Token 自动加载的账户车辆
  Widget _buildVehicleSection(ThemeData theme) {
    final result = _lastFetchResult;
    final vehicles = result?.vehicles ?? const <BeijingPassVehicle>[];
    final selected = _selectedVehicle;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car_filled_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '账户车辆',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: _queryingStatus ? null : () => _refreshStatus(),
                  icon: const Icon(Icons.sync_rounded, size: 14),
                  label: const Text(
                    '加载车辆',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_tokenController.text.trim().isEmpty)
              Text(
                '先填入 Token，再加载账户下已绑定车辆。',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              )
            else if (result == null)
              Text(
                '点击“加载车辆”读取 Token 对应的车辆与办证状态。',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              )
            else if (!result.success)
              Text(
                result.message,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              )
            else if (vehicles.isEmpty)
              Text(
                '未查询到已绑定车辆。请确认 Token 对应的北京交警账号。',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey(selected?.id),
                initialValue: selected?.id,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: '当前办理车辆',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                items: vehicles
                    .map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle.id,
                        child: Text(
                          vehicle.displayName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final vehicle = vehicles.firstWhere((item) => item.id == id);
                  setState(() => _selectVehicle(vehicle));
                },
              ),
              if (selected != null) ...[
                const SizedBox(height: 4),
                Text(
                  selected.activeRecord?.isValidNow == true
                      ? '当前车辆有生效中的 ${selected.activeRecord!.passType.shortLabel}'
                      : '当前车辆暂无生效中的进京证',
                  style: TextStyle(
                    fontSize: 12,
                    color: selected.activeRecord?.isValidNow == true
                        ? Colors.green.shade700
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 仅用于提交申请的补充资料
  Widget _buildCarProfileSection(ThemeData theme) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _supplementExpanded = !_supplementExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedVehicle == null
                          ? '办理补充资料（请先选择车辆）'
                          : '办理补充资料（仅保存至当前车辆）',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _supplementExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_supplementExpanded) ...[
              if (_selectedVehicle != null) ...[
                const SizedBox(height: 3),
                Text(
                  '当前关联：${_selectedVehicle!.displayName}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      readOnly: _selectedVehicle != null,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _selectedVehicle != null
                            ? '车牌号（已选）'
                            : '车牌号 *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: _selectedVehicle != null ? null : '如 冀A88888',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _carModelController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '车型',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '小型普通客车',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _engineNoController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _selectedVehicle != null
                            ? '发动机号（可选）'
                            : '发动机号 *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '行驶证发动机号',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _vinController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _selectedVehicle != null
                            ? '车架号/VIN（可选）'
                            : '车架号/VIN *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: 'VIN后6位或完整',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _driverNameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '驾驶人姓名 *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '张三',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _driverLicenceController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '身份证/驾驶证号 *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '18位身份证号',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 办理偏好设置（默认折叠）
  Widget _buildApplyPreferencesSection(ThemeData theme) {
    final entrance = _entranceController.text.trim().isEmpty
        ? '其他道路'
        : _entranceController.text.trim();
    final destination = _destinationController.text.trim().isEmpty
        ? '其它'
        : _destinationController.text.trim();
    final summary =
        '${_isInBeijing ? '已在北京' : '不在北京'} · $entrance · $destination';

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _preferencesExpanded = !_preferencesExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '办证偏好',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _preferencesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_preferencesExpanded) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inBeijingAddressController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '进京/在京地址 (社区地址) *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '如 昌平北站 / 望京SOHO',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 32,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _openLocationSearch(context),
                      icon: const Icon(Icons.search_rounded, size: 15),
                      label: const Text(
                        '搜索地点',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '办证经纬度（高德 / 百度）',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _resetToDefaultLocation,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              '重置默认(昌平北站)',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sqdzgdjdController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: '高德经度 (sqdzgdjd)',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _sqdzgdwdController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: '高德纬度 (sqdzgdwd)',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sqdzbdjdController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: '百度经度 (sqdzbdjd)',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _sqdzbdwdController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: '百度纬度 (sqdzbdwd)',
                              labelStyle: const TextStyle(fontSize: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.zero,
                title: const Text('当前已在北京', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  _isInBeijing ? '将提交“已在京”' : '默认提交“未在京”',
                  style: const TextStyle(fontSize: 11),
                ),
                value: _isInBeijing,
                onChanged: (value) => setState(() => _isInBeijing = value),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _entranceController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '进京主要道路',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '如 其他道路',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _destinationController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '进京目的地',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '如 其它',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 办理信息与提交操作。
  Widget _buildSubmitSection(ThemeData theme) {
    final hasVehicle = _selectedVehicle != null;
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_mode_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '通行证办理与保存',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<BeijingPassType>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              segments: const [
                ButtonSegment(
                  value: BeijingPassType.outsideSixth,
                  label: Text('六环外 (不限次)'),
                  icon: Icon(Icons.shield_outlined, size: 16),
                ),
                ButtonSegment(
                  value: BeijingPassType.insideSixth,
                  label: Text('六环内 (限12次)'),
                  icon: Icon(Icons.location_city_outlined, size: 16),
                ),
              ],
              selected: {_selectedPassType},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) {
                  setState(() => _selectedPassType = set.first);
                }
              },
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: hasVehicle ? _pickApplyStartDate : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '生效起始：${_formatDate(_selectedApplyStartDate)}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: !hasVehicle || _submittingApply
                          ? null
                          : _submitRenewPass,
                      icon: _submittingApply
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        _submittingApply
                            ? '提交中...'
                            : '办理（${_selectedPassType.shortLabel}）',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: _savingConfig ? null : _saveConfig,
                      icon: _savingConfig
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(
                        _savingConfig ? '保存中...' : '保存预填',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 办证历史记录列表
  Widget _buildHistoryRecordsSection(ThemeData theme) {
    final selectedVehicle = _selectedVehicle;
    final records = selectedVehicle?.records ?? _lastFetchResult?.records ?? [];
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${selectedVehicle == null ? '办证历史记录' : '当前车辆办证记录'} (${records.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...records.map((r) {
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: r.isValidNow
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  child: Icon(
                    r.isValidNow ? Icons.check : Icons.receipt_long_outlined,
                    size: 14,
                    color: r.isValidNow
                        ? Colors.green.shade800
                        : Colors.grey.shade700,
                  ),
                ),
                title: Text(
                  '${r.passType.shortLabel} · ${r.statusDesc}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: r.startDate != null && r.endDate != null
                    ? Text(
                        '${_formatDate(r.startDate!)} ~ ${_formatDate(r.endDate!)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                trailing: r.isValidNow
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '生效中',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickApplyStartDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedApplyStartDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      helpText: '选择进京证生效起始日期',
    );
    if (picked != null) {
      setState(() => _selectedApplyStartDate = picked);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 进京证位置搜索 BottomSheet 弹窗
class _BeijingPassLocationSearchModal extends StatefulWidget {
  final ApiService apiService;

  const _BeijingPassLocationSearchModal({required this.apiService});

  @override
  State<_BeijingPassLocationSearchModal> createState() =>
      _BeijingPassLocationSearchModalState();
}

class _BeijingPassLocationSearchModalState
    extends State<_BeijingPassLocationSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<PlaceResult> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _searching = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final list = await widget.apiService.searchPlaces(trimmed);
      if (!mounted) return;
      setState(() {
        _results = list;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '搜索失败，请检查网络后重试';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 480,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                const Text(
                  '搜索办证位置',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: '输入地点（如 昌平北站、望京SOHO、天通苑）',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.place_outlined, size: 16),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onChanged: _performSearch,
              onSubmitted: _performSearch,
            ),
            const SizedBox(height: 8),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              )
            else if (_results.isEmpty &&
                _searchController.text.trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '未找到相关地点，请尝试其他关键词',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              )
            else if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    '输入关键词搜索北京市各区地点，选择后将自动填充地址及高德/百度坐标',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final place = _results[i];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${place.address.isNotEmpty ? '${place.address} · ' : ''}坐标: ${place.location.longitude.toStringAsFixed(4)}, ${place.location.latitude.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(place),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
