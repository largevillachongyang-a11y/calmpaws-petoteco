// =============================================================================
// shop_screen.dart — 商城页面（Tab 3）
// =============================================================================
// 方案C：APP内展示产品 + 点击跳转独立站 petotecolife.com
// 包含：D2产品展示 / D1订阅套餐 / D3订单跳转
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/locale_provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../theme/app_theme.dart';

// ── URL 常量 ──────────────────────────────────────────────────────────────────
const _kProductUrl   = 'https://petotecolife.com/product/zenbelly-calming-probiotic-chews';
const _kStoreUrl     = 'https://petotecolife.com/';
const _kOrdersUrl    = 'https://petotecolife.com/my-account/orders/';
const _kSubscribeUrl = 'https://petotecolife.com/product/zenbelly-calming-probiotic-chews/#subscribe';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isZh = context.watch<LocaleProvider>().isZh;
    final provider = context.watch<PetHealthProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _ShopHeader(isZh: isZh)),

            // ── 主打产品卡片 ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _HeroProductCard(isZh: isZh, petName: provider.pet.name),
              ),
            ),

            // ── 订阅套餐（D1）────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _SubscriptionSection(isZh: isZh),
              ),
            ),

            // ── 产品亮点（成分）──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _IngredientHighlights(isZh: isZh),
              ),
            ),

            // ── 用量指南 ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _DosageGuide(isZh: isZh),
              ),
            ),

            // ── 用户评价 ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _ReviewsSection(isZh: isZh),
              ),
            ),

            // ── FAQ ──────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _FaqSection(isZh: isZh),
              ),
            ),

            // ── 底部按钮组（D3 订单跳转）────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: _BottomActions(isZh: isZh),
              ),
            ),
          ],
        ),
      ),

      // ── 悬浮购买按钮 ─────────────────────────────────────────────────────────
      bottomNavigationBar: _BuyBar(isZh: isZh),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _ShopHeader extends StatelessWidget {
  final bool isZh;
  const _ShopHeader({required this.isZh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isZh ? '商城' : 'Shop',
                style: AppTextStyles.headlineLarge,
              ),
              Text(
                isZh ? 'ZenBelly 官方产品' : 'Official ZenBelly Products',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          // 订单按钮
          GestureDetector(
            onTap: () => _openUrl(_kOrdersUrl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    isZh ? '我的订单' : 'My Orders',
                    style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 主打产品卡片 ──────────────────────────────────────────────────────────────
class _HeroProductCard extends StatelessWidget {
  final bool isZh;
  final String petName;
  const _HeroProductCard({required this.isZh, required this.petName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7BAE8B), Color(0xFF4D9267)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.sageGreen.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标签行
                      Row(
                        children: [
                          _WhiteBadge(isZh ? '🏆 热销第一' : '🏆 Best Seller'),
                          const SizedBox(width: 8),
                          _WhiteBadge('4.9 ⭐ (2,437)'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ZenBelly',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        isZh
                            ? 'Calming & Probiotic Chews'
                            : 'Calming & Probiotic Chews',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isZh
                            ? '10合1天然舒缓配方 · 无大麻 · 无镇静\n益生菌支持 · 肠道-大脑轴调节'
                            : '10-in-1 natural calming formula\nNo hemp · No sedation · Probiotic support',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 价格
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '\$29.90',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3, left: 6),
                            child: Text(
                              isZh ? '/ 瓶 · 120粒软糖' : '/ jar · 120 soft chews',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 右侧产品图（使用产品图片）
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      'https://sspark.genspark.ai/cfimages?u1=omsEPR1X15Vs996Jpac2dF5hXWy25%2FRK%2BaajQPUl3m%2FA1x4rf4%2BZsl1rLQtH4gGV8KTY%2BQjXW7FzportVYfXzxcF8vYUPpmqs644s8an7xxNjRjMARw4AA%3D%3D&u2=ytHKCPnc5derIgGW&width=400',
                      width: 110,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 110,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('💊', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 4),
                            Text('🐕', style: TextStyle(fontSize: 32)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 特性标签行
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _FeatureTag('🌿', isZh ? '无大麻' : 'Hemp-Free'),
                _FeatureTag('🌾', isZh ? '无谷物' : 'Grain-Free'),
                _FeatureTag('🦠', isZh ? '益生菌' : 'Probiotic'),
                _FeatureTag('🍗', isZh ? '鸡肉味' : 'Chicken'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteBadge extends StatelessWidget {
  final String text;
  const _WhiteBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  final String emoji;
  final String label;
  const _FeatureTag(this.emoji, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── D1 订阅套餐区域 ───────────────────────────────────────────────────────────
class _SubscriptionSection extends StatefulWidget {
  final bool isZh;
  const _SubscriptionSection({required this.isZh});

  @override
  State<_SubscriptionSection> createState() => _SubscriptionSectionState();
}

class _SubscriptionSectionState extends State<_SubscriptionSection> {
  int _selected = 1; // 默认选季度

  @override
  Widget build(BuildContext context) {
    final plans = [
      _Plan(
        labelEn: 'Monthly',      labelZh: '月订阅',
        priceEn: '\$29.90/mo',   priceZh: '\$29.90/月',
        saveEn: '',               saveZh: '',
        descEn: 'Billed monthly · Cancel anytime',
        descZh: '每月扣费 · 随时取消',
        highlight: false,
      ),
      _Plan(
        labelEn: 'Quarterly',    labelZh: '季订阅',
        priceEn: '\$25.90/mo',   priceZh: '\$25.90/月',
        saveEn: 'Save 13%',      saveZh: '省13%',
        descEn: 'Billed \$77.70 every 3 months',
        descZh: '每3个月扣费 \$77.70',
        highlight: true,
      ),
      _Plan(
        labelEn: 'Annual',       labelZh: '年订阅',
        priceEn: '\$22.90/mo',   priceZh: '\$22.90/月',
        saveEn: 'Save 23%',      saveZh: '省23%',
        descEn: 'Billed \$274.80/year',
        descZh: '每年扣费 \$274.80',
        highlight: false,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔄', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                widget.isZh ? '订阅套餐' : 'Subscribe & Save',
                style: AppTextStyles.headlineSmall,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sageGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.isZh ? '最高省23%' : 'Up to 23% off',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...plans.asMap().entries.map((e) => _PlanTile(
                plan: e.value,
                isZh: widget.isZh,
                selected: _selected == e.key,
                onTap: () => setState(() => _selected = e.key),
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _openUrl(_kSubscribeUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                widget.isZh
                    ? '立即订阅 ${plans[_selected].priceZh}'
                    : 'Subscribe Now · ${plans[_selected].priceEn}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              widget.isZh ? '🔒 随时取消 · 免费配送 · 安全结账' : '🔒 Cancel anytime · Free shipping · Secure checkout',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _Plan {
  final String labelEn, labelZh;
  final String priceEn, priceZh;
  final String saveEn, saveZh;
  final String descEn, descZh;
  final bool highlight;
  const _Plan({
    required this.labelEn, required this.labelZh,
    required this.priceEn, required this.priceZh,
    required this.saveEn,  required this.saveZh,
    required this.descEn,  required this.descZh,
    required this.highlight,
  });
}

class _PlanTile extends StatelessWidget {
  final _Plan plan;
  final bool isZh, selected;
  final VoidCallback onTap;
  const _PlanTile({required this.plan, required this.isZh, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageMuted : AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.sageGreen : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 单选圆点
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.sageGreen : AppColors.textMuted,
                  width: 2,
                ),
                color: selected ? AppColors.sageGreen : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isZh ? plan.labelZh : plan.labelEn,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: selected ? AppColors.sageGreen : AppColors.textPrimary,
                        ),
                      ),
                      if (plan.saveEn.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: plan.highlight ? AppColors.sageGreen : AppColors.successMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isZh ? plan.saveZh : plan.saveEn,
                            style: TextStyle(
                              color: plan.highlight ? Colors.white : AppColors.successGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (plan.highlight) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warmOrangeMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isZh ? '推荐' : 'Popular',
                            style: const TextStyle(
                              color: AppColors.warmOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isZh ? plan.descZh : plan.descEn,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              isZh ? plan.priceZh : plan.priceEn,
              style: AppTextStyles.labelLarge.copyWith(
                color: selected ? AppColors.sageGreen : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 成分亮点 ──────────────────────────────────────────────────────────────────
class _IngredientHighlights extends StatelessWidget {
  final bool isZh;
  const _IngredientHighlights({required this.isZh});

  @override
  Widget build(BuildContext context) {
    final ingredients = [
      _Ing('🌼', 'Chamomile',    '洋甘菊',    isZh ? '通过GABA调节快速舒缓，减少环境应激' : 'Fast-acting calm via GABA modulation'),
      _Ing('🍵', 'L-Theanine',   'L-茶氨酸',  isZh ? '促进α脑波——平静专注，无镇静效果' : 'Alpha brainwave state — calm alertness, no sedation'),
      _Ing('🌿', 'Ashwagandha',  '南非醉茄',  isZh ? '适应原，3-4周逐渐建立对日常压力的平衡反应' : 'Adaptogen — builds balanced stress response over 3–4 weeks'),
      _Ing('🦠', 'Probiotics',   '益生菌',    isZh ? '平衡肠道菌群，通过肠-脑轴支持情绪健康' : 'Gut flora balance — supports mood via gut-brain axis'),
      _Ing('🌺', 'Passion Flower','西番莲',   isZh ? '支持GABA受体活性，大脑主要抑制通路' : 'Supports GABA receptor — brain\'s primary calming pathway'),
      _Ing('🌙', 'Melatonin',    '褪黑素',    isZh ? '调节睡眠-觉醒周期，减少睡眠相关焦虑' : 'Regulates sleep-wake cycles, reduces sleep-linked anxiety'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧬', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                isZh ? '10合1核心成分' : '10-in-1 Key Ingredients',
                style: AppTextStyles.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...ingredients.map((ing) => _IngRow(ing: ing, isZh: isZh)),
        ],
      ),
    );
  }
}

class _Ing {
  final String emoji, nameEn, nameZh, descEn;
  final String descZh;
  const _Ing(this.emoji, this.nameEn, this.nameZh, this.descZh) : descEn = descZh;
  // ignore: prefer_initializing_formals
  const _Ing.full(this.emoji, this.nameEn, this.nameZh, this.descEn, this.descZh);
}

class _IngRow extends StatelessWidget {
  final _Ing ing;
  final bool isZh;
  const _IngRow({required this.ing, required this.isZh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ing.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZh ? '${ing.nameEn}（${ing.nameZh}）' : ing.nameEn,
                  style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  isZh ? ing.descZh : ing.descEn,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 用量指南 ──────────────────────────────────────────────────────────────────
class _DosageGuide extends StatelessWidget {
  final bool isZh;
  const _DosageGuide({required this.isZh});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('≤ 5 kg',           '1 chew / day',   '1粒/天'),
      ('6 – 10 kg',        '2 chews / day',  '2粒/天'),
      ('11 – 20 kg',       '3 chews / day',  '3粒/天'),
      ('≥ 20 kg',          '4 chews / day',  '4粒/天'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmOrangeMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warmOrangeLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                isZh ? '每日用量指南' : 'Daily Dosage Guide',
                style: AppTextStyles.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warmOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(r.$1,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warmOrange)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isZh ? r.$3 : r.$2,
                      style: AppTextStyles.labelMedium,
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 6),
          Text(
            isZh
                ? '💡 最大剂量 8粒/天 · 每天同一时间服用效果最佳'
                : '💡 Max 8 chews/day · Best taken at the same time daily',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.warmOrange),
          ),
        ],
      ),
    );
  }
}

// ── 用户评价 ──────────────────────────────────────────────────────────────────
class _ReviewsSection extends StatelessWidget {
  final bool isZh;
  const _ReviewsSection({required this.isZh});

  @override
  Widget build(BuildContext context) {
    final reviews = [
      _Review(
        nameEn: 'Rachel T.',
        titleEn: '"Finally something that works"',
        titleZh: '"终于找到有效的产品"',
        bodyEn: 'After trying 4 other products, this is the first one that actually changed my dog\'s behavior. Luna went from hiding under the bed during storms to just staying in her spot.',
        bodyZh: '试过4款其他产品后，这是第一款真正改变了我家狗狗行为的产品。Luna在雷雨时从躲在床下变成了只是待在她的位置。',
      ),
      _Review(
        nameEn: 'Marcus H.',
        titleEn: '"Vet visits are manageable now"',
        titleZh: '"现在去看兽医容易多了"',
        bodyEn: 'My vet recommended trying a calming supplement. I gave ZenBelly 45 minutes before and the difference was night and day. The vet tech even commented.',
        bodyZh: '兽医建议尝试舒缓补充剂。我在就诊前45分钟给了ZenBelly，效果天壤之别，连兽医助手都注意到了。',
      ),
      _Review(
        nameEn: 'Priya N.',
        titleEn: '"Separation anxiety improved significantly"',
        titleZh: '"分离焦虑明显改善"',
        bodyEn: 'Before ZenBelly: howling, pacing, destruction. After 5 weeks: she settles within 10 minutes of us leaving. This is a game changer.',
        bodyZh: '使用前：嚎叫、踱步、破坏。5周后：我们离开后10分钟内她就平静下来。这真是改变游戏规则的产品。',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isZh ? '用户评价' : 'Customer Reviews',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(width: 8),
            const Text('⭐ 4.9', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(' (2,437)', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 12),
        ...reviews.map((r) => _ReviewCard(review: r, isZh: isZh)),
      ],
    );
  }
}

class _Review {
  final String nameEn, titleEn, titleZh, bodyEn, bodyZh;
  const _Review({required this.nameEn, required this.titleEn, required this.titleZh, required this.bodyEn, required this.bodyZh});
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  final bool isZh;
  const _ReviewCard({required this.review, required this.isZh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Text(
                review.nameEn,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isZh ? review.titleZh : review.titleEn,
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            isZh ? review.bodyZh : review.bodyEn,
            style: AppTextStyles.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── FAQ ───────────────────────────────────────────────────────────────────────
class _FaqSection extends StatelessWidget {
  final bool isZh;
  const _FaqSection({required this.isZh});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      _Faq(
        qEn: 'How fast does it work?',
        qZh: '多快见效？',
        aEn: 'Some dogs calm within 30–60 min (L-Theanine & Chamomile). Full gut-brain effect builds over 3–4 weeks. Maximum results at 6–8 weeks.',
        aZh: '部分狗狗30-60分钟内平静（L-茶氨酸和洋甘菊）。完整肠-脑效果需3-4周积累，最佳效果通常在6-8周。',
      ),
      _Faq(
        qEn: 'Will my dog be sedated?',
        qZh: '狗狗会被镇静吗？',
        aEn: 'No. ZenBelly produces calm alertness, not sedation. No hemp, CBD, acepromazine, or sedating compounds.',
        aZh: '不会。ZenBelly产生平静的清醒状态，而非镇静。不含大麻、CBD、乙酰丙嗪或任何镇静成分。',
      ),
      _Faq(
        qEn: 'How long does one jar last?',
        qZh: '一瓶能用多久？',
        aEn: 'Small dog (≤5kg, 1 chew/day): 120 days. Large dog (≥20kg, 4 chews/day): 30 days. Most dogs use 2–3 chews/day (40–60 days).',
        aZh: '小型犬(≤5kg，1粒/天)：120天。大型犬(≥20kg，4粒/天)：30天。多数狗每天2-3粒(40-60天)。',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isZh ? '常见问题' : 'FAQ', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 10),
        ...faqs.map((f) => _FaqTile(faq: f, isZh: isZh)),
      ],
    );
  }
}

class _Faq {
  final String qEn, qZh, aEn, aZh;
  const _Faq({required this.qEn, required this.qZh, required this.aEn, required this.aZh});
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  final bool isZh;
  const _FaqTile({required this.faq, required this.isZh});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _open ? AppColors.sageMuted : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _open ? AppColors.sageGreen.withValues(alpha: 0.4) : AppColors.divider,
          ),
          boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isZh ? widget.faq.qZh : widget.faq.qEn,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: _open ? AppColors.sageGreen : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _open ? AppColors.sageGreen : AppColors.textMuted,
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 8),
              Text(
                widget.isZh ? widget.faq.aZh : widget.faq.aEn,
                style: AppTextStyles.bodySmall.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── D3 底部操作区 ─────────────────────────────────────────────────────────────
class _BottomActions extends StatelessWidget {
  final bool isZh;
  const _BottomActions({required this.isZh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openUrl(_kOrdersUrl),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: Text(isZh ? '查看订单' : 'My Orders'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.sageGreen,
              side: const BorderSide(color: AppColors.sageGreen),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openUrl(_kStoreUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(isZh ? '访问官网' : 'Visit Store'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 底部悬浮购买栏 ────────────────────────────────────────────────────────────
class _BuyBar extends StatelessWidget {
  final bool isZh;
  const _BuyBar({required this.isZh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          // 价格信息
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$29.90',
                style: AppTextStyles.headlineMedium.copyWith(color: AppColors.sageGreen),
              ),
              Text(
                isZh ? '/ 瓶 · 120粒' : '/ jar · 120 chews',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // 购买按钮
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _openUrl(_kProductUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isZh ? '立即购买' : 'Buy Now',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
