import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  // Replace with your real Shopify/independent store URL
  static const String _storeUrl = 'https://petoteco.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shop', style: AppTextStyles.headlineLarge),
                      Text('ZenBelly products', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, color: AppColors.textSecondary, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Shop content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Featured product
                    _FeaturedProductCard(),
                    const SizedBox(height: 16),
                    // Bundle offer
                    _BundleCard(),
                    const SizedBox(height: 16),
                    // All products
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('All Products', style: AppTextStyles.headlineSmall),
                    ),
                    const SizedBox(height: 12),
                    _ProductGrid(),
                    const SizedBox(height: 24),
                    // Visit full store
                    _VisitStoreButton(url: _storeUrl),
                    const SizedBox(height: 24),
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

class _FeaturedProductCard extends StatelessWidget {
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                  child: const Text('⭐ Best Seller', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                const Text('ZenBelly\nCalm Chews', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 8),
                const Text('No CBD · Probiotic-based\nAnxiety relief for dogs', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('\$34.99', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text('/bag', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _openStore(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: const Text('Shop Now', style: TextStyle(color: AppColors.sageGreen, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Text('🐕\n🌿', style: TextStyle(fontSize: 48, height: 1.4)),
        ],
      ),
    );
  }

  void _openStore(BuildContext context) {
    _showStoreDialog(context);
  }
}

class _BundleCard extends StatelessWidget {
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
                const Text('Starter Bundle', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 4),
                const Text('3x ZenBelly + Smart Collar\n6-month FREE app access', style: AppTextStyles.bodySmall),
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
            onTap: () => _showStoreDialog(context),
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

class _ProductGrid extends StatelessWidget {
  final List<_Product> products = const [
    _Product(emoji: '🦴', name: 'Calm Chews\n30ct', price: '\$34.99', tag: 'Anxiety'),
    _Product(emoji: '💊', name: 'Probiotic\nSoft Gels', price: '\$28.99', tag: 'Digestion'),
    _Product(emoji: '🧴', name: 'Calming\nSpray', price: '\$22.99', tag: 'Topical'),
    _Product(emoji: '🎗️', name: 'Smart\nCollar', price: '\$49.99', tag: 'Hardware'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: products.map((p) => _ProductCard(product: p)).toList(),
    );
  }
}

class _Product {
  final String emoji;
  final String name;
  final String price;
  final String tag;
  const _Product({required this.emoji, required this.name, required this.price, required this.tag});
}

class _ProductCard extends StatelessWidget {
  final _Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStoreDialog(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.sageMuted, borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(product.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.warmOrangeMuted, borderRadius: BorderRadius.circular(8)),
              child: Text(product.tag, style: TextStyle(fontSize: 11, color: AppColors.warmOrange, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            Text(product.name, style: AppTextStyles.labelLarge.copyWith(fontSize: 14), maxLines: 2),
            const SizedBox(height: 4),
            Text(product.price, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.warmOrange, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _VisitStoreButton extends StatelessWidget {
  final String url;
  const _VisitStoreButton({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStoreDialog(context),
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
            Text('Visit Full Store at petoteco.com', style: AppTextStyles.labelLarge.copyWith(color: AppColors.sageGreen)),
          ],
        ),
      ),
    );
  }
}

void _showStoreDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Open Petoteco Store'),
      content: const Text('This will open the full store in your browser.\n\nIn the live app, this opens your Shopify store in a seamless WebView with your login automatically synced.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Open Store')),
      ],
    ),
  );
}
