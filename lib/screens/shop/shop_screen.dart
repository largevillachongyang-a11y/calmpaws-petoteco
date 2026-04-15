import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const String _storeUrl = 'https://petoteco.com';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(top: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.shopTitle, style: AppTextStyles.headlineLarge),
                      Text(s.shopSubtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const Spacer(),
                  // 购物车按钮 — 增大触摸区域，改用 InkWell 确保点击响应
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () => _showStoreDialog(context, s),
                      borderRadius: BorderRadius.circular(24),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.shopping_cart_outlined, color: AppColors.textSecondary, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FeaturedProductCard(s: s),
                    const SizedBox(height: 16),
                    _BundleCard(s: s),
                    const SizedBox(height: 20),
                    Text(s.shopAllProducts, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 12),
                    _ProductGrid(s: s),
                    const SizedBox(height: 20),
                    _VisitStoreButton(url: _storeUrl, s: s),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 主打产品卡片（全宽横幅，两列布局）
// ─────────────────────────────────────────────────────────────────────────────
class _FeaturedProductCard extends StatelessWidget {
  final dynamic s;
  const _FeaturedProductCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7BAE8B), Color(0xFF5A9970)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.sageGreen.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧文字区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 热销徽章
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.shopBestSeller,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                // 产品名
                Text(
                  s.shopProductName,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 8),
                // 描述
                Text(
                  s.shopProductDesc,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                // 价格行
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '\$34.99',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        s.shopPerBag,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 购买按钮
                GestureDetector(
                  onTap: () => _showStoreDialog(context, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      s.shopNow,
                      style: const TextStyle(color: AppColors.sageGreen, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 右侧图标
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 16),
            child: Column(
              children: [
                Text('🐕', style: TextStyle(fontSize: 44)),
                SizedBox(height: 8),
                Text('🌿', style: TextStyle(fontSize: 36)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 套装优惠卡片
// ─────────────────────────────────────────────────────────────────────────────
class _BundleCard extends StatelessWidget {
  final dynamic s;
  const _BundleCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmOrangeMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warmOrangeLight),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.shopBundle, style: AppTextStyles.headlineSmall),
                const SizedBox(height: 4),
                Text(s.shopBundleDesc, style: AppTextStyles.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('\$99', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.warmOrange)),
                    const SizedBox(width: 8),
                    const Text('\$138', style: TextStyle(fontSize: 14, color: AppColors.textMuted, decoration: TextDecoration.lineThrough)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showStoreDialog(context, s),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.warmOrange, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 产品网格
// ─────────────────────────────────────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final dynamic s;
  const _ProductGrid({required this.s});

  @override
  Widget build(BuildContext context) {
    // 产品数据：name/tag 根据语言切换
    final products = [
      _Product(emoji: '🦴', nameEn: 'Calm Chews\n30ct',     nameZh: '舒缓软糖\n30粒',  price: '\$34.99', tagEn: 'Anxiety',  tagZh: '抗焦虑'),
      _Product(emoji: '💊', nameEn: 'Probiotic\nSoft Gels', nameZh: '益生菌\n软胶囊',  price: '\$28.99', tagEn: 'Digestion', tagZh: '消化'),
      _Product(emoji: '🧴', nameEn: 'Calming\nSpray',       nameZh: '舒缓\n喷雾',      price: '\$22.99', tagEn: 'Topical',   tagZh: '外用'),
      _Product(emoji: '🎗️', nameEn: 'Smart\nCollar',        nameZh: '智能\n项圈',       price: '\$49.99', tagEn: 'Hardware',  tagZh: '硬件'),
    ];
    final isZh = s.locale == 'zh';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.80,
      children: products
          .map((p) => _ProductCard(
                product: p,
                isZh: isZh,
                onTap: () => _showStoreDialog(context, s),
              ))
          .toList(),
    );
  }
}

class _Product {
  final String emoji;
  final String nameEn;
  final String nameZh;
  final String price;
  final String tagEn;
  final String tagZh;
  const _Product({
    required this.emoji,
    required this.nameEn,
    required this.nameZh,
    required this.price,
    required this.tagEn,
    required this.tagZh,
  });
}

class _ProductCard extends StatelessWidget {
  final _Product product;
  final bool isZh;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.isZh, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.sageMuted, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: AppColors.warmOrangeMuted, borderRadius: BorderRadius.circular(8)),
              child: Text(
                isZh ? product.tagZh : product.tagEn,
                style: const TextStyle(fontSize: 11, color: AppColors.warmOrange, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),
            // 固定高度区域显示产品名，防止 Expanded 压缩后文字不可见
            SizedBox(
              height: 38,
              child: Text(
                isZh ? product.nameZh : product.nameEn,
                style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              product.price,
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.warmOrange, fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 访问完整商城按钮
// ─────────────────────────────────────────────────────────────────────────────
class _VisitStoreButton extends StatelessWidget {
  final String url;
  final dynamic s;
  const _VisitStoreButton({required this.url, required this.s});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStoreDialog(context, s),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.sageGreen, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.open_in_new_rounded, color: AppColors.sageGreen, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                s.shopVisitStore,
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.sageGreen),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 跳转商城弹窗
// ─────────────────────────────────────────────────────────────────────────────
void _showStoreDialog(BuildContext context, dynamic s) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(s.shopOpenTitle),
      content: Text(s.shopOpenDesc),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(s.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(overlayColor: Colors.transparent, backgroundColor: AppColors.sageGreen),
          child: Text(s.shopOpenBtn, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
