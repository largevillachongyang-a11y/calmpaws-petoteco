// =============================================================================
// debug_panel.dart — 调试面板（长按版本号触发）
// =============================================================================
// 功能：
//   1. 状态注入：直接切换项圈行为状态（calm/playing/pacing/stressed/shivering/sleep）
//   2. 通知测试：手动触发各类告警通知
//   3. 焦虑分调节：原有演示滑块迁移至此
//   4. 服务器快速切换：显示当前IP，一键进配网向导
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../setup/wifi_provision_screen.dart';

/// 长按版本号弹出调试面板入口
Future<void> showDebugPanel(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _DebugPanel(),
  );
}

class _DebugPanel extends StatefulWidget {
  const _DebugPanel();

  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动条
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report_rounded, color: Color(0xFFCBA6F7), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '🔧 CalmPaws 调试面板',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // 内容
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  children: [

                    // ── 当前状态显示 ─────────────────────────────────────────
                    _SectionTitle('当前状态'),
                    _StatusRow(provider: provider),
                    const SizedBox(height: 20),

                    // ── 注入行为状态 ─────────────────────────────────────────
                    _SectionTitle('注入行为状态'),
                    const SizedBox(height: 4),
                    Text(
                      '直接切换 APP 显示的状态（不影响服务器数据）',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StateChip(label: '😌 平静', state: PetBehaviorState.calm, provider: provider),
                        _StateChip(label: '🎾 玩耍', state: PetBehaviorState.playing, provider: provider),
                        _StateChip(label: '😰 踱步', state: PetBehaviorState.pacing, provider: provider),
                        _StateChip(label: '⚠️ 应激', state: PetBehaviorState.stressed, provider: provider),
                        _StateChip(label: '🆘 发抖', state: PetBehaviorState.shivering, provider: provider),
                        _StateChip(label: '💤 睡眠', state: PetBehaviorState.sleepNormal, provider: provider),
                        _StateChip(label: '⛔ 昏睡', state: PetBehaviorState.sleepAbnormal, provider: provider),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 焦虑分调节 ───────────────────────────────────────────
                    _SectionTitle('焦虑分调节'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.psychology_rounded, color: Color(0xFFFAB387), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '当前焦虑分：${(provider.anxietyLevel * 100).round()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: const SliderThemeData(
                        activeTrackColor: Color(0xFFFAB387),
                        inactiveTrackColor: Color(0xFF45475A),
                        thumbColor: Color(0xFFFAB387),
                      ),
                      child: Slider(
                        value: provider.anxietyLevel,
                        onChanged: (v) => provider.anxietyLevel = v,
                        min: 0,
                        max: 1,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 通知测试 ─────────────────────────────────────────────
                    _SectionTitle('触发通知测试'),
                    const SizedBox(height: 10),
                    _NotifButton(
                      icon: '🆘',
                      label: '发抖告警（持续3分钟）',
                      color: const Color(0xFFED8796),
                      onTap: () => provider.injectAlertForTest(
                        type: 'shiver',
                        message: '⚠️ ${provider.petName} 已持续发抖超3分钟，请检查是否疼痛、寒冷或恐惧。',
                      ),
                    ),
                    _NotifButton(
                      icon: '⚠️',
                      label: '应激频繁告警',
                      color: const Color(0xFFF38BA8),
                      onTap: () => provider.injectAlertForTest(
                        type: 'stress_frequent',
                        message: '⚠️ ${provider.petName} 今日已应激 10 次，请关注其情绪状态。',
                      ),
                    ),
                    _NotifButton(
                      icon: '⛔',
                      label: '药物昏睡检测',
                      color: const Color(0xFFCBA6F7),
                      onTap: () => provider.injectAlertForTest(
                        type: 'lethargy',
                        message: '⚠️ ${provider.petName} 白天已持续静止 3 小时，疑似药物性昏睡。',
                      ),
                    ),
                    _NotifButton(
                      icon: '🎾',
                      label: '活动量偏低提醒',
                      color: const Color(0xFFA6E3A1),
                      onTap: () => provider.injectAlertForTest(
                        type: 'activity',
                        message: '⚠️ ${provider.petName} 今日玩耍时间仅 5 分钟，建议至少 30 分钟。',
                      ),
                    ),
                    _NotifButton(
                      icon: '📊',
                      label: '触发每日总结',
                      color: const Color(0xFF89DCEB),
                      onTap: () {
                        provider.triggerDailySummaryForTest();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('每日总结已触发'), backgroundColor: Color(0xFF89DCEB)),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── 服务器配置 ───────────────────────────────────────────
                    _SectionTitle('服务器配置'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.dns_rounded, color: Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.serverBaseUrl,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await Navigator.of(context).push<bool>(
                                MaterialPageRoute(builder: (_) => const WifiProvisionScreen()),
                              );
                            },
                            child: const Text('修改', style: TextStyle(color: Color(0xFF89B4FA))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 数据源切换
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: Colors.white38, size: 16),
                        const SizedBox(width: 8),
                        const Text('数据源：', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(width: 8),
                        _ToggleChip(
                          label: '真实服务器',
                          active: provider.useRealServer,
                          activeColor: const Color(0xFFA6E3A1),
                          onTap: () => provider.setDataSource(useRealServer: true),
                        ),
                        const SizedBox(width: 8),
                        _ToggleChip(
                          label: 'Mock模拟',
                          active: !provider.useRealServer,
                          activeColor: const Color(0xFFFAB387),
                          onTap: () => provider.setDataSource(useRealServer: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 辅助组件 ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF89B4FA),
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final PetHealthProvider provider;
  const _StatusRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.currentBehaviorState;
    final stateLabel = switch (state) {
      PetBehaviorState.calm         => '😌 平静',
      PetBehaviorState.playing      => '🎾 玩耍',
      PetBehaviorState.pacing       => '😰 踱步',
      PetBehaviorState.stressed     => '⚠️ 应激',
      PetBehaviorState.shivering    => '🆘 发抖',
      PetBehaviorState.sleepNormal  => '💤 正常睡眠',
      PetBehaviorState.sleepAbnormal=> '⛔ 异常昏睡',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(stateLabel, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            provider.deviceConnected
                ? (provider.serverConnectionStatus == 'connected' ? '🟢 在线' : '🟡 ${provider.serverConnectionStatus}')
                : '⚪ 离线',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text('🔋 ${provider.battery}%', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String label;
  final PetBehaviorState state;
  final PetHealthProvider provider;
  const _StateChip({required this.label, required this.state, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isActive = provider.currentBehaviorState == state;
    return GestureDetector(
      onTap: () => provider.injectStateForTest(state),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF89B4FA).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF89B4FA) : Colors.white24,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF89B4FA) : Colors.white70,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NotifButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
              Icon(Icons.play_arrow_rounded, color: color.withValues(alpha: 0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? activeColor : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? activeColor : Colors.white38,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
