import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildSubscriptionCard(context)),
            SliverToBoxAdapter(child: _buildMenuSection(context, provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.sageGreen, Color(0xFF5A9970)]),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('👤', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alex Johnson', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text('alex@petoteco.com', style: AppTextStyles.bodySmall),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.sageMuted, borderRadius: BorderRadius.circular(20)),
                  child: Text('✅ Pro Subscriber', style: AppTextStyles.labelSmall.copyWith(color: AppColors.sageGreen, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.cream, shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8845A), Color(0xFFD4694A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.warmOrange.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Text('Subscription', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SubStat(label: 'Plan', value: 'Pro · \$4.99/mo'),
              _SubStat(label: 'Next Billing', value: 'Aug 14, 2025'),
              _SubStat(label: 'ZenBelly', value: '23 days left'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showManageSubscription(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Manage', style: TextStyle(color: AppColors.warmOrange, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Reorder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, PetHealthProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          _MenuItem(icon: Icons.receipt_long_rounded, iconColor: AppColors.sageGreen, label: 'Order History', onTap: () => _showOrderHistory(context)),
          _Divider(),
          _MenuItem(icon: Icons.support_agent_rounded, iconColor: AppColors.warmOrange, label: 'Customer Support', badge: 'Chat', onTap: () => _showSupport(context)),
          _Divider(),
          _MenuItem(icon: Icons.help_outline_rounded, iconColor: AppColors.sageGreen, label: 'Device Setup Guide', onTap: () => _showDeviceGuide(context)),
          _Divider(),
          _MenuItem(icon: Icons.bar_chart_rounded, iconColor: const Color(0xFF6B7FD4), label: 'Health Reports', onTap: () => _showHealthReports(context, provider)),
          _Divider(),
          _MenuItem(icon: Icons.notifications_none_rounded, iconColor: AppColors.warmOrange, label: 'Notifications', onTap: () {}),
          _Divider(),
          _MenuItem(icon: Icons.privacy_tip_outlined, iconColor: AppColors.textMuted, label: 'Privacy & Data', onTap: () {}),
          _Divider(),
          _MenuItem(icon: Icons.logout_rounded, iconColor: AppColors.alertRed, label: 'Sign Out', onTap: () => _showSignOut(context)),
        ],
      ),
    );
  }

  void _showManageSubscription(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      backgroundColor: AppColors.cream,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Manage Subscription', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text("You're making a difference for ${context.read<PetHealthProvider>().pet.name}'s wellbeing 🐾", style: AppTextStyles.bodyMedium),
            const SizedBox(height: 20),
            // Health data retention warning (anti-churn)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.sageMuted, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 Your Health Progress This Month', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 8),
                  _ProgressRow(label: 'Anxiety events reduced', value: '↓ 34%', color: AppColors.sageGreen),
                  _ProgressRow(label: 'Time to calm improved', value: '↓ 18%', color: AppColors.sageGreen),
                  _ProgressRow(label: 'Sleep quality increased', value: '↑ 12%', color: AppColors.sageGreen),
                  const SizedBox(height: 8),
                  Text('Pausing now means losing 34 days of behavioral baseline data.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.alertRed, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                label: const Text('Pause for 1 Month Instead'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warmOrange,
                  side: const BorderSide(color: AppColors.warmOrangeLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel Subscription', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Order History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OrderRow(date: 'Jul 14, 2025', item: 'ZenBelly 3-Pack', status: 'Delivered', amount: '\$99.00'),
            _OrderRow(date: 'Apr 08, 2025', item: 'ZenBelly Refill', status: 'Delivered', amount: '\$34.99'),
            _OrderRow(date: 'Jan 02, 2025', item: 'Starter Bundle', status: 'Delivered', amount: '\$99.00'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(children: [Text('💬 '), Text('Customer Support')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('In the live app, this opens Crisp or Intercom live chat embedded inside the app, with your account pre-loaded.', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            const Text('Response time: Usually < 2 hours', style: AppTextStyles.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Start Chat')),
        ],
      ),
    );
  }

  void _showDeviceGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('📡 Device Setup Guide'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideStep(step: 1, text: 'Charge the ZenBelly collar for 2 hours before first use'),
              _GuideStep(step: 2, text: 'Enable Bluetooth on your phone'),
              _GuideStep(step: 3, text: 'Hold your phone within 30cm of the collar'),
              _GuideStep(step: 4, text: 'Tap "Connect Device" in the My Pet tab'),
              _GuideStep(step: 5, text: 'Attach collar to pet — not too tight, 2-finger gap'),
              _GuideStep(step: 6, text: 'Data will begin syncing within 30 seconds'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it!'))],
      ),
    );
  }

  void _showHealthReports(BuildContext context, PetHealthProvider provider) {
    final sessions = provider.sessionHistory;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('📈 Health Reports'),
        content: sessions.isEmpty
            ? const Text('No feeding sessions recorded yet.\nStart tracking with the ZenBelly timer on the Health tab.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: sessions.take(5).map((s) => _SessionReportRow(session: s)).toList(),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Sign Out', style: TextStyle(color: AppColors.alertRed))),
        ],
      ),
    );
  }
}

class _SubStat extends StatelessWidget {
  final String label;
  final String value;
  const _SubStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w400)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.iconColor, required this.label, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.sageMuted, borderRadius: BorderRadius.circular(8)),
              child: Text(badge!, style: TextStyle(fontSize: 11, color: AppColors.sageGreen, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 68, endIndent: 20);
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ProgressRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final String date;
  final String item;
  final String status;
  final String amount;
  const _OrderRow({required this.date, required this.item, required this.status, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: AppTextStyles.labelLarge.copyWith(fontSize: 14)),
                Text(date, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: AppTextStyles.labelLarge.copyWith(fontSize: 14)),
              Text(status, style: TextStyle(fontSize: 12, color: AppColors.sageGreen, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int step;
  final String text;
  const _GuideStep({required this.step, required this.text});

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
            decoration: BoxDecoration(color: AppColors.sageGreen, shape: BoxShape.circle),
            child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _SessionReportRow extends StatelessWidget {
  final dynamic session;
  const _SessionReportRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final secs = session.timeToCalm as int? ?? 0;
    final mins = (secs / 60).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_timeAgo(session.feedTime), style: AppTextStyles.bodySmall),
          Text('$mins min to calm', style: AppTextStyles.labelLarge.copyWith(fontSize: 14, color: AppColors.sageGreen)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    return 'Today';
  }
}
