import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

// =============================================================================
// BehaviorStateCard — "一眼结论"设计
// =============================================================================
// 三层信息架构：
//   第一层（最重要）：自然语言结论 —— "今天 Biscuit 状态不错 😌"
//   第二层：综合焦虑分 + 趋势箭头
//   第三层：最多2个主要驱动因素（口语化）+ "查看详情"展开
// =============================================================================

class BehaviorStateCard extends StatefulWidget {
  final PetHealthProvider provider;
  const BehaviorStateCard({super.key, required this.provider});

  @override
  State<BehaviorStateCard> createState() => _BehaviorStateCardState();
}

class _BehaviorStateCardState extends State<BehaviorStateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final isZh = context.watch<LocaleProvider>().isZh;
    final provider = widget.provider;
    final behavior = provider.currentBehavior;
    final packet = provider.latestPacket;
    final score = provider.currentAnxietyScore;
    final petName = provider.pet.name;

    final (bgColor, accentColor, _, _) = _stateColors(behavior);

    // ── 第一层：自然语言结论 ──────────────────────────────────────────────
    final conclusion = _buildConclusion(behavior, score, petName, isZh);

    // ── 第三层：最多2个主要驱动因素（只在展开时显示） ─────────────────────
    final drivers = packet != null ? _topDrivers(packet, isZh) : <_Driver>[];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 主行：结论文字 + 焦虑分 ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 状态 emoji（大）
              Text(behavior.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              // 结论文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conclusion.headline,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conclusion.subtext,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 焦虑分圆环（辅助，不是主角）
              _AnxietyRing(score: score, color: accentColor),
            ],
          ),

          const SizedBox(height: 12),

          // ── 驱动因素预览行（始终显示，最多2个） ─────────────────────────
          if (drivers.isNotEmpty) ...[
            _DriverPillRow(drivers: drivers.take(2).toList(), accentColor: accentColor),
            const SizedBox(height: 10),
          ],

          // ── 展开/收起详情按钮 ─────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  _expanded
                      ? (isZh ? '收起详情' : 'Hide details')
                      : (isZh ? '查看所有传感器数据 ▸' : 'View sensor details ▸'),
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── 展开详情：完整6维数据 ─────────────────────────────────────
          if (_expanded && packet != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _DetailGrid(packet: packet, isZh: isZh, s: s),
          ],
        ],
      ),
    );
  }

  // ── 颜色映射（与原版一致）────────────────────────────────────────────────
  (Color, Color, String, String) _stateColors(PetBehaviorState state) {
    switch (state) {
      case PetBehaviorState.calm:
        return (AppColors.sageMuted, AppColors.sageGreen, '', '');
      case PetBehaviorState.pacing:
        return (AppColors.warmOrangeMuted, AppColors.warmOrange, '', '');
      case PetBehaviorState.stressed:
        return (const Color(0xFFFFF0E0), const Color(0xFFD97706), '', '');
      case PetBehaviorState.playing:
        return (AppColors.sageMuted, AppColors.sageGreen, '', '');
      case PetBehaviorState.shivering:
        return (AppColors.alertRedMuted, AppColors.alertRed, '', '');
      case PetBehaviorState.sleeping:
        return (const Color(0xFFF0F4FF), const Color(0xFF6B7FD4), '', '');
    }
  }

  // ── 生成自然语言结论 ─────────────────────────────────────────────────────
  _Conclusion _buildConclusion(
      PetBehaviorState state, int score, String name, bool isZh) {
    // 焦虑分等级描述
    final level = score < 20
        ? (isZh ? '很好' : 'great')
        : score < 40
            ? (isZh ? '不错' : 'good')
            : score < 60
                ? (isZh ? '偏高' : 'elevated')
                : (isZh ? '较高' : 'high');

    if (isZh) {
      switch (state) {
        case PetBehaviorState.calm:
          return _Conclusion(
            headline: '$name 现在很平静 😌',
            subtext: '焦虑分 $score / 100，状态$level',
          );
        case PetBehaviorState.playing:
          return _Conclusion(
            headline: '$name 正在健康玩耍 🎾',
            subtext: '焦虑分 $score / 100，活力充沛',
          );
        case PetBehaviorState.pacing:
          return _Conclusion(
            headline: '$name 有些焦虑，在来回踱步 😰',
            subtext: '焦虑分 $score / 100，建议安抚',
          );
        case PetBehaviorState.stressed:
          return _Conclusion(
            headline: '$name 出现应激反应 ⚠️',
            subtext: '焦虑分 $score / 100，请留意触发源',
          );
        case PetBehaviorState.shivering:
          return _Conclusion(
            headline: '$name 正在发抖，需要检查 🆘',
            subtext: '焦虑分 $score / 100，可能疼痛/寒冷/恐惧',
          );
        case PetBehaviorState.sleeping:
          return _Conclusion(
            headline: '$name 在休息睡觉 💤',
            subtext: '焦虑分 $score / 100，静息中',
          );
      }
    } else {
      switch (state) {
        case PetBehaviorState.calm:
          return _Conclusion(
            headline: '$name is calm & relaxed 😌',
            subtext: 'Anxiety $score/100 · $level',
          );
        case PetBehaviorState.playing:
          return _Conclusion(
            headline: '$name is playing happily 🎾',
            subtext: 'Anxiety $score/100 · active & healthy',
          );
        case PetBehaviorState.pacing:
          return _Conclusion(
            headline: '$name seems anxious, pacing 😰',
            subtext: 'Anxiety $score/100 · try calming',
          );
        case PetBehaviorState.stressed:
          return _Conclusion(
            headline: '$name is showing stress ⚠️',
            subtext: 'Anxiety $score/100 · check triggers',
          );
        case PetBehaviorState.shivering:
          return _Conclusion(
            headline: '$name is shivering — check now 🆘',
            subtext: 'Anxiety $score/100 · pain/cold/fear?',
          );
        case PetBehaviorState.sleeping:
          return _Conclusion(
            headline: '$name is resting 💤',
            subtext: 'Anxiety $score/100 · sleeping',
          );
      }
    }
  }

  // ── 提取前2个主要驱动因素（口语化，非技术字段）──────────────────────────
  List<_Driver> _topDrivers(BlePacket p, bool isZh) {
    final drivers = <_Driver>[];

    if (p.shivD > 0) {
      drivers.add(_Driver(
        emoji: '🫨',
        label: isZh ? '发抖 ${p.shivD}秒' : 'Shivering ${p.shivD}s',
        isAlert: true,
      ));
    }
    if (p.strC > 0) {
      drivers.add(_Driver(
        emoji: '😣',
        label: isZh ? '应激 ${p.strC}次' : 'Stress ×${p.strC}',
        isAlert: p.strC >= 3,
      ));
    }
    if (p.paceD > 10) {
      drivers.add(_Driver(
        emoji: '🚶',
        label: isZh ? '踱步 ${p.paceD}秒' : 'Pacing ${p.paceD}s',
        isAlert: p.paceD > 30,
      ));
    }
    if (p.playD > 10) {
      drivers.add(_Driver(
        emoji: '🎾',
        label: isZh ? '玩耍 ${p.playD}秒' : 'Play ${p.playD}s',
        isAlert: false,
      ));
    }
    if (drivers.isEmpty) {
      drivers.add(_Driver(
        emoji: '✅',
        label: isZh ? '无异常信号' : 'No stress signals',
        isAlert: false,
      ));
    }
    return drivers;
  }
}

// ── 焦虑分圆环（小巧辅助型）─────────────────────────────────────────────────
class _AnxietyRing extends StatelessWidget {
  final int score;
  final Color color;
  const _AnxietyRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '焦虑分',
          style: TextStyle(
            fontSize: 9,
            color: color.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── 驱动因素 Pill 行 ─────────────────────────────────────────────────────────
class _DriverPillRow extends StatelessWidget {
  final List<_Driver> drivers;
  final Color accentColor;
  const _DriverPillRow({required this.drivers, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: drivers.map((d) {
        final bg = d.isAlert
            ? AppColors.alertRedMuted
            : accentColor.withValues(alpha: 0.12);
        final fg = d.isAlert ? AppColors.alertRed : accentColor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(d.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                d.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── 展开详情：完整6维传感器数据表格 ─────────────────────────────────────────
class _DetailGrid extends StatelessWidget {
  final BlePacket packet;
  final bool isZh;
  final dynamic s;
  const _DetailGrid({required this.packet, required this.isZh, required this.s});

  @override
  Widget build(BuildContext context) {
    final items = [
      _DetailItem('😣', isZh ? '应激次数' : 'Stress Count', '${packet.strC}x'),
      _DetailItem('⏱️', isZh ? '应激时长' : 'Stress Duration', '${packet.strD}s'),
      _DetailItem('🫨', isZh ? '发抖次数' : 'Shiver Count', '${packet.shivC}x'),
      _DetailItem('⏱️', isZh ? '发抖时长' : 'Shiver Duration', '${packet.shivD}s'),
      _DetailItem('🚶', isZh ? '踱步时长' : 'Pacing', '${packet.paceD}s'),
      _DetailItem('🎾', isZh ? '玩耍时长' : 'Play', '${packet.playD}s'),
      _DetailItem('🔄', isZh ? '打滚次数' : 'Roll Count', '${packet.rollC}x'),
      _DetailItem('⚡', isZh ? '活力评分' : 'Activity', '${packet.activityScore}'),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: items.map((item) => _DetailCell(item: item)).toList(),
    );
  }
}

class _DetailCell extends StatelessWidget {
  final _DetailItem item;
  const _DetailCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            item.value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          Text(
            item.label,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ── 数据类 ───────────────────────────────────────────────────────────────────
class _Conclusion {
  final String headline;
  final String subtext;
  const _Conclusion({required this.headline, required this.subtext});
}

class _Driver {
  final String emoji;
  final String label;
  final bool isAlert;
  const _Driver({required this.emoji, required this.label, required this.isAlert});
}

class _DetailItem {
  final String emoji;
  final String label;
  final String value;
  const _DetailItem(this.emoji, this.label, this.value);
}
