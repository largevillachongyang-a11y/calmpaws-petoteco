// =============================================================================
// wifi_provision_screen.dart — 项圈配网向导
// =============================================================================
// 3步流程：
//   Step 1 — 说明 / 前置检查（项圈是否上电、是否广播 CalmPaws_Config）
//   Step 2 — 输入服务器地址（当前 Web 版本；原生版本可扩展为BLE扫描+Wi-Fi凭证）
//   Step 3 — 验证连接 / 完成
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/provisioning_service.dart';
import '../../services/wifi_config_service.dart';
import '../../theme/app_theme.dart';

class WifiProvisionScreen extends StatefulWidget {
  const WifiProvisionScreen({super.key});

  @override
  State<WifiProvisionScreen> createState() => _WifiProvisionScreenState();
}

class _WifiProvisionScreenState extends State<WifiProvisionScreen>
    with SingleTickerProviderStateMixin {
  final _prov = ProvisioningService();
  final _wifiCfg = WifiConfigService();

  int _currentStep = 0; // 0=说明, 1=输入IP, 2=结果

  // Step 2 表单
  final _serverUrlCtrl = TextEditingController();
  final _deviceIdCtrl  = TextEditingController();
  bool _obscurePass    = true;
  bool _isLoading      = false;
  String? _errorMsg;
  bool _corsLikely     = false; // 是否需要显示"强制保存"按钮

  late AnimationController _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // 预填当前保存的地址
    _serverUrlCtrl.text = _wifiCfg.serverUrl;
    _deviceIdCtrl.text  = _wifiCfg.deviceId;
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    _serverUrlCtrl.dispose();
    _deviceIdCtrl.dispose();
    _prov.reset();
    super.dispose();
  }

  // ── 步骤导航 ──────────────────────────────────────────────────────────────

  void _next() => setState(() => _currentStep++);
  void _back() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMsg   = null;
        _corsLikely = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── 核心：验证 + 保存 ─────────────────────────────────────────────────────

  Future<void> _verify() async {
    setState(() { _isLoading = true; _errorMsg = null; _corsLikely = false; });

    final result = await _prov.verify(serverUrl: _serverUrlCtrl.text.trim());

    if (!mounted) return;

    if (result.success) {
      await _saveAndConnect(result.serverUrl!);
    } else {
      setState(() {
        _isLoading  = false;
        _errorMsg   = result.errorMessage;
        _corsLikely = result.corsLikely;
      });
    }
  }

  Future<void> _forceSave() async {
    final url = _serverUrlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    if (url.isEmpty) return;
    setState(() { _isLoading = true; });
    await _saveAndConnect(url);
  }

  Future<void> _saveAndConnect(String url) async {
    final deviceId = _deviceIdCtrl.text.trim().isEmpty
        ? ProvisioningService.kDefaultDeviceId
        : _deviceIdCtrl.text.trim();

    // 保存到 SharedPreferences + 更新 ServerApiService
    await _wifiCfg.forceSave(serverUrl: url, deviceId: deviceId);

    // 通知 Provider 重连
    if (mounted) {
      final provider = context.read<PetHealthProvider>();
      if (provider.deviceConnected) {
        provider.disconnectDevice();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      provider.connectDevice();
    }

    if (!mounted) return;
    setState(() { _isLoading = false; _currentStep = 2; });
    _checkAnim.forward();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textPrimary,
          onPressed: _back,
        ),
        title: Text(
          '项圈配网',
          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 进度条
            _StepIndicator(currentStep: _currentStep),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (_currentStep) {
                  0 => _buildStep0(),
                  1 => _buildStep1(),
                  2 => _buildStep2(),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0：说明 ──────────────────────────────────────────────────────────

  Widget _buildStep0() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图示
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.sageMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sensors_rounded,
                size: 60,
                color: AppColors.sageGreen,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('开始配网前，请确认：',
              style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _CheckItem(
            icon: Icons.battery_charging_full_rounded,
            color: AppColors.sageGreen,
            title: '项圈已充电并开机',
            desc: '长按电源键 3 秒，LED 闪烁绿色即为开机',
          ),
          _CheckItem(
            icon: Icons.wifi_rounded,
            color: Colors.blue,
            title: '手机/电脑与服务器在同一网络',
            desc: '确保运行 server.py 的电脑和本设备在同一局域网',
          ),
          _CheckItem(
            icon: Icons.computer_rounded,
            color: Colors.orange,
            title: 'server.py 正在运行',
            desc: '终端应显示 "Running on http://0.0.0.0:5000"',
          ),
          _CheckItem(
            icon: Icons.info_outline_rounded,
            color: AppColors.textSecondary,
            title: '当前版本：手动输入服务器 IP',
            desc: '未来版本支持蓝牙自动配网（CalmPaws_Config）',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('下一步：输入服务器地址',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1：输入 IP ────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('服务器地址',
              style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '在运行 server.py 的电脑终端查看 IP\n'
            '示例：http://192.168.x.x:5000',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // 服务器地址输入
          _LabeledField(
            label: '服务器地址',
            hint: 'http://192.168.x.x:5000',
            controller: _serverUrlCtrl,
            keyboardType: TextInputType.url,
            prefixIcon: Icons.dns_rounded,
          ),
          const SizedBox(height: 16),

          // 设备 ID
          _LabeledField(
            label: '设备 ID',
            hint: 'collar_001',
            controller: _deviceIdCtrl,
            keyboardType: TextInputType.text,
            prefixIcon: Icons.memory_rounded,
          ),
          const SizedBox(height: 8),

          // 常见 IP 说明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningAmberMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: AppColors.warningAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '查看电脑 IP：\n'
                    'Windows：cmd → ipconfig\n'
                    'Mac/Linux：终端 → ifconfig 或 ip addr',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.warningAmber, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 错误信息
          if (_errorMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.alertRedMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: AppColors.alertRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _corsLikely ? '浏览器安全限制，无法自动验证' : '连接失败',
                          style: const TextStyle(
                              color: AppColors.alertRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _corsLikely
                        ? '网页版因浏览器限制无法直接测试连通性。\n'
                          '如果你确认 IP 正确，可以点击"直接保存"跳过验证。'
                        : _errorMsg!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.alertRed),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 按钮组
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('验证并连接',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),

          // CORS 时显示"直接保存"
          if (_corsLikely && !_isLoading) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _forceSave,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sageGreen,
                  side: const BorderSide(color: AppColors.sageGreen),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('直接保存（跳过验证）',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Step 2：完成 ──────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final savedUrl = _wifiCfg.serverUrl;
    return _buildSuccessBody(savedUrl);
  }

  Widget _buildSuccessBody(String savedUrl) {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 成功动画图标
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _checkAnim,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.sageMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 60,
                color: AppColors.sageGreen,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '配网成功！',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800, color: AppColors.sageGreen),
          ),
          const SizedBox(height: 12),
          Text(
            '已连接到服务器',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sageMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              savedUrl,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.sageGreen,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('完成，开始监测',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 子组件 ────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const steps = ['准备', '配置', '完成'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // 连接线
            final stepIdx = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepIdx < currentStep
                    ? AppColors.sageGreen
                    : AppColors.divider,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isActive   = stepIdx == currentStep;
          final isComplete = stepIdx < currentStep;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.sageGreen
                      : isActive
                          ? AppColors.sageGreen.withValues(alpha: 0.15)
                          : AppColors.divider,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isActive || isComplete)
                        ? AppColors.sageGreen
                        : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isComplete
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : Text(
                          '${stepIdx + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.sageGreen
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIdx],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? AppColors.sageGreen
                      : AppColors.textSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _CheckItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.labelMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final IconData prefixIcon;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelMedium
                .copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.cardBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.sageGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
