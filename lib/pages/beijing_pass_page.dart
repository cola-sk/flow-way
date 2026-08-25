import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/beijing_pass_model.dart';
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
    _customApiBaseController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigAndInit() async {
    setState(() => _loadingConfig = true);
    final cfg = await _service.loadConfig();
    _config = cfg;

    _tokenController.text = cfg.token;
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
    _inBeijingAddressController.text = cfg.inBeijingAddress;
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

  BeijingPassVehicle? get _selectedVehicle {
    final vehicles = _lastFetchResult?.vehicles ?? const <BeijingPassVehicle>[];
    if (vehicles.isEmpty) return null;
    for (final vehicle in vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle;
    }
    return vehicles.first;
  }

  BeijingPassRecord? get _selectedActiveRecord =>
      _selectedVehicle?.activeRecord;

  bool get _supplementComplete =>
      _plateController.text.trim().isNotEmpty &&
      _carModelController.text.trim().isNotEmpty &&
      _engineNoController.text.trim().isNotEmpty &&
      _vinController.text.trim().isNotEmpty &&
      _driverNameController.text.trim().isNotEmpty &&
      _driverLicenceController.text.trim().isNotEmpty;

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
    _driverNameController.text = supplement?.driverName ?? _config.driverName;
    _driverLicenceController.text =
        supplement?.driverLicence ?? _config.driverLicence;
    _supplementExpanded = !_supplementComplete;

    final record = vehicle.activeRecord;
    if (record != null) {
      _selectedPassType = record.passType;
      _selectedApplyStartDate = record.suggestedNextStartDate;
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
      customApiBase: _customApiBaseController.text.trim(),
      vehicleSupplements: Map<String, BeijingPassVehicleSupplement>.from(
        _vehicleSupplements,
      ),
    );
  }

  Future<void> _saveConfig() async {
    setState(() => _savingConfig = true);
    final updated = _buildCurrentConfigFromForm();
    final ok = await _service.saveConfig(updated);
    if (!mounted) return;
    setState(() {
      _config = updated;
      _savingConfig = false;
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
        final target = result.vehicles.firstWhere(
          (vehicle) => vehicle.id == _selectedVehicleId,
          orElse: () => result.vehicles.first,
        );
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
        const SnackBar(
          content: Text('请先完善车辆及驾驶人必填信息（车牌、发动机号、车架号、驾驶人信息）'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 确认弹窗
    final applyDateStr =
        '${_selectedApplyStartDate.year}-${_selectedApplyStartDate.month.toString().padLeft(2, '0')}-${_selectedApplyStartDate.day.toString().padLeft(2, '0')}';
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
            Text('证件类型：${cfg.passType.label}'),
            const SizedBox(height: 4),
            Text('生效日期：$applyDateStr (7天)'),
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
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _submittingApply = true);
    // 先静默保存最新配置，再发起提交请求。
    await _saveConfigBeforeSubmit(cfg);

    final result = await _service.submitApplyRecord(
      config: cfg,
      applyDate: _selectedApplyStartDate,
      applyDays: 7,
    );

    if (!mounted) return;
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
              onPressed: () => Navigator.of(ctx).pop(),
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
            onPressed: _showTokenHelpDialog,
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
      body: _loadingConfig
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
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
                  Icons.vpn_key_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '北京交警 Token 凭证',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (!mounted) return;
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      _tokenController.text = data.text!.trim();
                      _updateTokenExpiry(data.text!.trim());
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已从剪贴板粘贴 Token'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.paste_rounded, size: 14),
                  label: const Text('粘贴', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _tokenController,
              maxLines: 2,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              decoration: InputDecoration(
                isDense: true,
                hintText: '填入 Authorization: Bearer xxx 或直接粘贴 Token',
                hintStyle: const TextStyle(fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                suffixIcon: _tokenController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _tokenController.clear();
                          setState(() => _tokenExpiry = null);
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _updateTokenExpiry(val)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car_filled_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '账户车辆',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _queryingStatus ? null : () => _refreshStatus(),
                  icon: const Icon(Icons.sync_rounded, size: 14),
                  label: const Text('加载车辆', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
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
                const SizedBox(height: 6),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _supplementExpanded = !_supplementExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 18,
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
                      ),
                    ),
                  ),
                  Icon(
                    _supplementExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_supplementExpanded) ...[
              if (_selectedVehicle != null) ...[
                const SizedBox(height: 4),
                Text(
                  '当前关联：${_selectedVehicle!.displayName}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
              const SizedBox(height: 8),
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
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _engineNoController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '发动机号 *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: '行驶证对应发动机号',
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _vinController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '车架号/VIN *',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: 'VIN后6位或完整',
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () =>
                  setState(() => _preferencesExpanded = !_preferencesExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
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
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _preferencesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_preferencesExpanded) ...[
              const SizedBox(height: 6),
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
              if (_isInBeijing) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _inBeijingAddressController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: '在京详细地址 *',
                    labelStyle: const TextStyle(fontSize: 12),
                    hintText: '如 昌平区回龙观街道 xx 小区 xx 号楼',
                    hintStyle: const TextStyle(fontSize: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
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
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<BeijingPassType>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12),
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
                      style: const TextStyle(fontSize: 12),
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
                        style: const TextStyle(fontSize: 12),
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
                          fontSize: 12,
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
                    fontSize: 12,
                  ),
                ),
                subtitle: r.startDate != null && r.endDate != null
                    ? Text(
                        '${_formatDate(r.startDate!)} ~ ${_formatDate(r.endDate!)}',
                        style: const TextStyle(fontSize: 10),
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
                            fontSize: 10,
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
