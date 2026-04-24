// =============================================================================
// edge_impulse_screen.dart — E1 数据采集工具 + E2 模型训练说明
// =============================================================================
// 功能：
//   E1 - 行为标注界面：查看当前 BLE 数据包，手动为每个数据窗口打标签
//        (calm / pacing / stressed / playing / shivering)
//        标注完成后可导出为 Edge Impulse CSV 格式
//   E2 - 模型训练说明：引导用户将 CSV 上传到 Edge Impulse，完成训练、
//        部署并拿到 .tflite 文件返回嵌入固件
// =============================================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 数据结构：一条标注样本
// 每个样本 = 一个 5s BLE 数据窗口 + 用户手动打的标签
// CSV 格式兼容 Edge Impulse 上传规范
// ─────────────────────────────────────────────────────────────────────────────
class _LabeledSample {
  final DateTime timestamp;
  final String label; // calm / pacing / stressed / playing / shivering
  final double strC;
  final double strD;
  final double paceD;
  final double playD;
  final double rollC;
  final double shivC;
  final double shivD;
  final int anxietyScore;

  const _LabeledSample({
    required this.timestamp,
    required this.label,
    required this.strC,
    required this.strD,
    required this.paceD,
    required this.playD,
    required this.rollC,
    required this.shivC,
    required this.shivD,
    required this.anxietyScore,
  });

  /// 生成 Edge Impulse CSV 格式的一行
  /// 格式: timestamp,label,str_c,str_d,pace_d,play_d,roll_c,shiv_c,shiv_d,anxiety_score
  String toCsvRow() {
    return '${timestamp.millisecondsSinceEpoch},$label,'
        '${strC.toStringAsFixed(2)},${strD.toStringAsFixed(2)},'
        '${paceD.toStringAsFixed(2)},${playD.toStringAsFixed(2)},'
        '${rollC.toStringAsFixed(2)},${shivC.toStringAsFixed(2)},'
        '${shivD.toStringAsFixed(2)},$anxietyScore';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 主屏幕
// ─────────────────────────────────────────────────────────────────────────────
class EdgeImpulseScreen extends StatefulWidget {
  const EdgeImpulseScreen({super.key});

  @override
  State<EdgeImpulseScreen> createState() => _EdgeImpulseScreenState();
}

class _EdgeImpulseScreenState extends State<EdgeImpulseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<_LabeledSample> _samples = [];
  String _selectedLabel = 'calm';
  bool _isCapturing = false;

  static const _labels = [
    ('calm', '😌', '平静'),
    ('pacing', '🚶', '走动'),
    ('stressed', '😰', '应激'),
    ('playing', '🎾', '玩耍'),
    ('shivering', '🥶', '颤抖'),
  ];

  static const String _csvHeader =
      'timestamp,label,str_c,str_d,pace_d,play_d,roll_c,shiv_c,shiv_d,anxiety_score';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── 从当前 BLE 数据包采集一条样本 ──────────────────────────────────────────
  void _captureCurrentSample(PetHealthProvider provider) {
    final pkt = provider.latestPacket;
    if (pkt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 暂无 BLE 数据包，请先连接设备')),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
      _samples.add(_LabeledSample(
        timestamp: DateTime.now(),
        label: _selectedLabel,
        strC: pkt.strC.toDouble(),
        strD: pkt.strD.toDouble(),
        paceD: pkt.paceD.toDouble(),
        playD: pkt.playD.toDouble(),
        rollC: pkt.rollC.toDouble(),
        shivC: pkt.shivC.toDouble(),
        shivD: pkt.shivD.toDouble(),
        anxietyScore: provider.currentAnxietyScore,
      ));
    });

    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isCapturing = false);
    });
  }

  // ── 生成完整 CSV 字符串 ───────────────────────────────────────────────────
  String _buildCsv() {
    final buf = StringBuffer();
    buf.writeln(_csvHeader);
    for (final s in _samples) {
      buf.writeln(s.toCsvRow());
    }
    return buf.toString();
  }

  // ── 复制 CSV 到剪贴板（Web 平台替代文件下载）──────────────────────────────
  Future<void> _exportCsv() async {
    if (_samples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 还没有任何标注样本')),
      );
      return;
    }
    final csv = _buildCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ CSV 已复制到剪贴板（${_samples.length} 条样本）'),
        backgroundColor: AppColors.sageGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── 预览 CSV 内容 ─────────────────────────────────────────────────────────
  void _previewCsv() {
    if (_samples.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('CSV 预览（前 10 行）',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              '${_csvHeader}\n${_samples.take(10).map((s) => s.toCsvRow()).join('\n')}',
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportCsv();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sageGreen),
            child: const Text('复制全部', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 删除所有样本 ──────────────────────────────────────────────────────────
  void _clearSamples() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清空所有标注？',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('将删除 ${_samples.length} 条样本，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _samples.clear());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.alertRed),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final isZh = context.watch<LocaleProvider>().isZh;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 数据工具',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text('Edge Impulse · 行为标注 & 模型',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.sageGreen,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.sageGreen,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '📡 采集'),
            Tab(text: '📋 样本库'),
            Tab(text: '🧠 模型训练'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CaptureTab(
            provider: provider,
            labels: _labels,
            selectedLabel: _selectedLabel,
            isCapturing: _isCapturing,
            sampleCount: _samples.length,
            onLabelChanged: (l) => setState(() => _selectedLabel = l),
            onCapture: () => _captureCurrentSample(provider),
          ),
          _SampleListTab(
            samples: _samples,
            onExport: _exportCsv,
            onPreview: _previewCsv,
            onClear: _clearSamples,
          ),
          const _ModelTrainingTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1：实时采集
// =============================================================================
class _CaptureTab extends StatelessWidget {
  final PetHealthProvider provider;
  final List<(String, String, String)> labels;
  final String selectedLabel;
  final bool isCapturing;
  final int sampleCount;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onCapture;

  const _CaptureTab({
    required this.provider,
    required this.labels,
    required this.selectedLabel,
    required this.isCapturing,
    required this.sampleCount,
    required this.onLabelChanged,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final pkt = provider.latestPacket;
    final hasData = pkt != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 连接状态 ──────────────────────────────────────────────────────────
        _StatusBanner(hasData: hasData),
        const SizedBox(height: 16),

        // ── 当前 BLE 数据窗口 ─────────────────────────────────────────────────
        _CurrentPacketCard(pkt: pkt, provider: provider),
        const SizedBox(height: 16),

        // ── 行为标签选择 ──────────────────────────────────────────────────────
        _buildLabelSelector(context),
        const SizedBox(height: 20),

        // ── 采集按钮 ──────────────────────────────────────────────────────────
        _CaptureButton(
          isCapturing: isCapturing,
          hasData: hasData,
          sampleCount: sampleCount,
          onCapture: onCapture,
        ),
        const SizedBox(height: 12),

        // ── 采集提示 ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.sageGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.sageGreen.withValues(alpha: 0.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.tips_and_updates_rounded,
                    color: AppColors.sageGreen, size: 16),
                const SizedBox(width: 6),
                Text('采集指南',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.sageGreen,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              ...[
                '建议每种行为至少采集 50 个样本',
                '采集时确保宠物处于对应行为状态',
                '每 5 秒点一次「标注此数据窗口」',
                '完成后在「样本库」tab 导出 CSV',
              ].map((tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: AppColors.sageGreen, fontSize: 13)),
                        Expanded(
                          child: Text(tip,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabelSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择当前行为标签',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: labels.map((l) {
            final (key, emoji, zhName) = l;
            final isSelected = selectedLabel == key;
            return GestureDetector(
              onTap: () => onLabelChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.sageGreen
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.sageGreen
                        : AppColors.divider,
                    width: isSelected ? 0 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.sageGreen.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      zhName,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── 连接状态横幅 ──────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final bool hasData;
  const _StatusBanner({required this.hasData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasData
            ? AppColors.sageGreen.withValues(alpha: 0.1)
            : AppColors.alertRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasData
              ? AppColors.sageGreen.withValues(alpha: 0.3)
              : AppColors.alertRed.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasData
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_disabled_rounded,
            color: hasData ? AppColors.sageGreen : AppColors.alertRed,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasData ? 'BLE 已连接 · 正在接收数据' : '未检测到 BLE 数据 · Mock 模式下可正常标注',
              style: TextStyle(
                color: hasData ? AppColors.sageGreen : AppColors.alertRed,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hasData ? AppColors.sageGreen : AppColors.alertRed,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 当前数据包卡片 ─────────────────────────────────────────────────────────────
class _CurrentPacketCard extends StatelessWidget {
  final BlePacket? pkt;
  final PetHealthProvider provider;
  const _CurrentPacketCard({required this.pkt, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors_rounded,
                  color: AppColors.sageGreen, size: 18),
              const SizedBox(width: 6),
              Text('当前数据窗口（5s 累积）',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.sageGreen,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Anxiety ${provider.currentAnxietyScore}',
                  style: const TextStyle(
                      color: AppColors.sageGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pkt == null)
            const Center(
              child: Text('等待数据包…',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FieldChip('str_c', pkt!.strC),
                _FieldChip('str_d', pkt!.strD),
                _FieldChip('pace_d', pkt!.paceD),
                _FieldChip('play_d', pkt!.playD),
                _FieldChip('roll_c', pkt!.rollC),
                _FieldChip('shiv_c', pkt!.shivC),
                _FieldChip('shiv_d', pkt!.shivD),
              ],
            ),
        ],
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  final String name;
  final num value;
  const _FieldChip(this.name, this.value);

  @override
  Widget build(BuildContext context) {
    final isActive = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.sageGreen.withValues(alpha: 0.12)
            : AppColors.sageMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppColors.sageGreen.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$name ',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: value.toStringAsFixed(value is int ? 0 : 1),
              style: TextStyle(
                color: isActive ? AppColors.sageGreen : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 采集按钮 ──────────────────────────────────────────────────────────────────
class _CaptureButton extends StatelessWidget {
  final bool isCapturing;
  final bool hasData;
  final int sampleCount;
  final VoidCallback onCapture;

  const _CaptureButton({
    required this.isCapturing,
    required this.hasData,
    required this.sampleCount,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onCapture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCapturing
                ? [AppColors.textMuted, AppColors.textMuted]
                : [AppColors.sageGreen, const Color(0xFF4D9267)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: isCapturing
              ? []
              : [
                  BoxShadow(
                    color: AppColors.sageGreen.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCapturing
                  ? Icons.check_circle_rounded
                  : Icons.fiber_manual_record_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              isCapturing ? '✅ 已标注！' : '📌 标注此数据窗口',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sampleCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$sampleCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 2：样本库
// =============================================================================
class _SampleListTab extends StatelessWidget {
  final List<_LabeledSample> samples;
  final VoidCallback onExport;
  final VoidCallback onPreview;
  final VoidCallback onClear;

  const _SampleListTab({
    required this.samples,
    required this.onExport,
    required this.onPreview,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // 各标签计数
    final counts = <String, int>{};
    for (final s in samples) {
      counts[s.label] = (counts[s.label] ?? 0) + 1;
    }

    return Column(
      children: [
        // ── 操作栏 ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('共 ${samples.length} 个样本',
                  style: AppTextStyles.headlineSmall
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (samples.isNotEmpty) ...[
                _ActionBtn(
                  icon: Icons.preview_rounded,
                  label: '预览',
                  onTap: onPreview,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.copy_rounded,
                  label: '导出 CSV',
                  onTap: onExport,
                  color: AppColors.sageGreen,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: '清空',
                  onTap: onClear,
                  color: AppColors.alertRed,
                ),
              ],
            ],
          ),
        ),

        // ── 标签分布统计 ─────────────────────────────────────────────────────
        if (samples.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _LabelDistribution(counts: counts),
          ),

        // ── 样本列表 ─────────────────────────────────────────────────────────
        Expanded(
          child: samples.isEmpty
              ? _EmptyState(
                  icon: Icons.dataset_outlined,
                  title: '还没有标注样本',
                  subtitle: '在「采集」Tab 标注数据后，样本会显示在这里',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: samples.length,
                  itemBuilder: (ctx, i) {
                    final s = samples[samples.length - 1 - i]; // 最新的在最前
                    return _SampleRow(sample: s, index: samples.length - i);
                  },
                ),
        ),
      ],
    );
  }
}

class _LabelDistribution extends StatelessWidget {
  final Map<String, int> counts;
  const _LabelDistribution({required this.counts});

  static const _labelEmoji = {
    'calm': '😌',
    'pacing': '🚶',
    'stressed': '😰',
    'playing': '🎾',
    'shivering': '🥶',
  };

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('标签分布',
              style: AppTextStyles.labelSmall
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...counts.entries.map((e) {
            final ratio = e.value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${_labelEmoji[e.key] ?? ''} ${e.key}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor:
                            AppColors.sageGreen.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.sageGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SampleRow extends StatelessWidget {
  final _LabeledSample sample;
  final int index;
  const _SampleRow({required this.sample, required this.index});

  static const _labelEmoji = {
    'calm': '😌',
    'pacing': '🚶',
    'stressed': '😰',
    'playing': '🎾',
    'shivering': '🥶',
  };

  static const _labelColor = {
    'calm': AppColors.sageGreen,
    'pacing': AppColors.warningAmber,
    'stressed': AppColors.warmOrange,
    'playing': Color(0xFF6B7FD4),
    'shivering': AppColors.alertRed,
  };

  @override
  Widget build(BuildContext context) {
    final color = _labelColor[sample.label] ?? AppColors.textMuted;
    final emoji = _labelEmoji[sample.label] ?? '•';
    final time =
        '${sample.timestamp.hour.toString().padLeft(2, '0')}:${sample.timestamp.minute.toString().padLeft(2, '0')}:${sample.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          // 序号
          SizedBox(
            width: 28,
            child: Text('#$index',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ),
          // 标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$emoji ${sample.label}',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          // 关键字段
          Expanded(
            child: Text(
              'strC:${sample.strC.toStringAsFixed(0)} '
              'paceD:${sample.paceD.toStringAsFixed(0)} '
              'playD:${sample.playD.toStringAsFixed(0)} '
              'shivD:${sample.shivD.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 时间
          Text(time,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 3：模型训练说明（E2）
// =============================================================================
class _ModelTrainingTab extends StatelessWidget {
  const _ModelTrainingTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 训练流程 ─────────────────────────────────────────────────────────
        _SectionCard(
          icon: '🧠',
          title: '模型训练流程',
          child: Column(
            children: [
              ...[
                ('1', '采集 & 标注', '在「采集」Tab 为每种行为采集 ≥50 个样本，共 5 种标签', AppColors.sageGreen),
                ('2', '导出 CSV', '在「样本库」Tab 点击「导出 CSV」复制到剪贴板', AppColors.sageGreen),
                ('3', '上传 Edge Impulse', '打开 edgeimpulse.com，创建项目，导入 CSV', const Color(0xFF6B7FD4)),
                ('4', '设计特征', '选择 Spectral Analysis 或 Raw 特征提取', const Color(0xFF6B7FD4)),
                ('5', '训练分类器', '使用 NN Classifier，目标准确率 ≥85%', AppColors.warningAmber),
                ('6', '导出 .tflite', 'Deploy → TensorFlow Lite (int8)，下载 zip', AppColors.warningAmber),
                ('7', '嵌入固件', '将 .tflite 文件放入硬件项目 data/ 目录', AppColors.warmOrange),
              ].map((step) {
                final (num, title, desc, color) = step;
                return _StepRow(
                    num: num, title: title, desc: desc, color: color);
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 输入特征说明 ─────────────────────────────────────────────────────
        _SectionCard(
          icon: '📐',
          title: '输入特征（7维）',
          child: Column(
            children: [
              ...[
                ('str_c', '应激计数', '5s 内 ISM330 应激触发次数'),
                ('str_d', '应激时长', '5s 内应激持续秒数'),
                ('pace_d', '走动时长', '5s 内走动持续秒数'),
                ('play_d', '玩耍时长', '5s 内玩耍持续秒数'),
                ('roll_c', '翻滚次数', '5s 内翻滚检测次数'),
                ('shiv_c', '颤抖计数', '5s 内颤抖触发次数'),
                ('shiv_d', '颤抖时长', '5s 内颤抖持续秒数'),
              ].map((f) {
                final (field, name, desc) = f;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.sageGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(field,
                            style: const TextStyle(
                                color: AppColors.sageGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: Text(name,
                            style: AppTextStyles.labelSmall
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(desc,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 输出标签 ─────────────────────────────────────────────────────────
        _SectionCard(
          icon: '🏷️',
          title: '输出标签（5类）',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ('😌 calm', AppColors.sageGreen),
              ('🚶 pacing', AppColors.warningAmber),
              ('😰 stressed', AppColors.warmOrange),
              ('🎾 playing', const Color(0xFF6B7FD4)),
              ('🥶 shivering', AppColors.alertRed),
            ].map((item) {
              final (label, color) = item;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // ── 目标指标 ─────────────────────────────────────────────────────────
        _SectionCard(
          icon: '🎯',
          title: '目标指标',
          child: Column(
            children: [
              _MetricRow('训练集准确率', '≥ 90%', AppColors.sageGreen),
              _MetricRow('验证集准确率', '≥ 85%', AppColors.sageGreen),
              _MetricRow('推理时间 (M4)', '< 5ms', const Color(0xFF6B7FD4)),
              _MetricRow('模型大小', '< 50KB', const Color(0xFF6B7FD4)),
              _MetricRow('量化格式', 'int8 TFLite', AppColors.warningAmber),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 快速链接 ─────────────────────────────────────────────────────────
        _SectionCard(
          icon: '🔗',
          title: '相关链接',
          child: Column(
            children: [
              _LinkRow(
                  'Edge Impulse 控制台', 'https://studio.edgeimpulse.com/'),
              _LinkRow('CSV 导入文档',
                  'https://docs.edgeimpulse.com/docs/tools/edge-impulse-cli/cli-uploader'),
              _LinkRow('TFLite 导出指南',
                  'https://docs.edgeimpulse.com/docs/deployment/arduino-library'),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String num;
  final String title;
  final String desc;
  final Color color;
  const _StepRow(
      {required this.num,
      required this.title,
      required this.desc,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(num,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.labelSmall
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String url;
  const _LinkRow(this.label, this.url);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.open_in_new_rounded,
              size: 14, color: Color(0xFF6B7FD4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7FD4),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 公共 Widget
// =============================================================================
class _SectionCard extends StatelessWidget {
  final String icon;
  final String title;
  final Widget child;
  const _SectionCard(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(title,
                  style: AppTextStyles.headlineSmall
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.headlineSmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(subtitle,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
