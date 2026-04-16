// =============================================================================
// notification_center_screen.dart — 通知中心页面
// =============================================================================
// 职责：展示应用内所有历史通知，支持标记已读、左滑删除、全部清除。
//
// 入口：Dashboard 右上角铃铛图标（带未读数角标）
//
// 功能列表：
//   • 按时间倒序展示所有通知（最新在顶部）
//   • 未读通知高亮显示（浅色背景 + 左侧彩色边框）
//   • 进入页面自动标记全部已读（角标清零）
//   • 左滑单条通知删除
//   • 右上角「清除全部」按钮
//   • 空状态提示（无通知时）
//   • 通知类型标签（紧急预警 / 喂食记录 / 日志提醒 / 系统通知）
//
// 设计说明：
//   • 使用 Dismissible 实现左滑删除，符合 iOS/Android 通用手势规范
//   • 进入页面即标记全部已读，符合用户预期（打开即表示看到了）
//   • 通知详情不单独开页，点击时跳转对应功能页（如 Dashboard）
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    // 进入页面后延迟标记全部已读（确保 Widget 已挂载）
    // 延迟 300ms 让用户先看到未读状态，再清除角标，视觉上更自然
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          context.read<NotificationProvider>().markAllAsRead();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isZh = context.watch<LocaleProvider>().isZh;
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        // 顶部标题栏
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isZh ? '消息通知' : 'Notifications',
          style: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimary),
        ),
        // 右上角「全部清除」按钮（只有有通知时显示）
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context, isZh, provider),
              child: Text(
                isZh ? '全部清除' : 'Clear All',
                style: TextStyle(
                  color: AppColors.alertRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: provider.isLoading
          // 加载中状态
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              // 空状态
              ? _buildEmptyState(isZh)
              // 通知列表
              : _buildNotificationList(context, isZh, provider, notifications),
    );
  }

  // ── 通知列表 ─────────────────────────────────────────────────────────────
  Widget _buildNotificationList(
    BuildContext context,
    bool isZh,
    NotificationProvider provider,
    List<AppNotification> notifications,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.divider,
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final notif = notifications[index];
        return _buildNotifItem(context, isZh, provider, notif);
      },
    );
  }

  // ── 单条通知卡片 ─────────────────────────────────────────────────────────
  Widget _buildNotifItem(
    BuildContext context,
    bool isZh,
    NotificationProvider provider,
    AppNotification notif,
  ) {
    // 左滑删除（Dismissible）
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart, // 从右向左滑动删除
      onDismissed: (_) => provider.deleteNotification(notif.id),
      // 滑动时显示红色删除背景
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.alertRed.withValues(alpha: 0.9),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: InkWell(
        // 点击通知：标记已读 + 路由跳转
        onTap: () {
          provider.markAsRead(notif.id);
          // [TODO] 根据 notif.actionRoute 跳转到对应页面
          // 例如：if (notif.actionRoute == 'dashboard') Navigator.pop(context);
          Navigator.pop(context); // 暂时返回上一页
        },
        child: Container(
          // 未读通知有浅色背景高亮
          color: notif.isRead
              ? Colors.transparent
              : NotificationProvider.typeColor(notif.type).withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 左侧类型图标 ──────────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NotificationProvider.typeColor(notif.type)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  NotificationProvider.typeIcon(notif.type),
                  color: NotificationProvider.typeColor(notif.type),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // ── 右侧文字内容 ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行：通知标题 + 时间
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700, // 未读加粗
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 时间标签
                        Text(
                          NotificationProvider.timeAgo(notif.createdAt, isZh),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        // 未读圆点
                        if (!notif.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: NotificationProvider.typeColor(notif.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 通知正文
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: notif.isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 类型标签（小标签）
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: NotificationProvider.typeColor(notif.type)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        NotificationProvider.typeLabel(notif.type, isZh),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: NotificationProvider.typeColor(notif.type),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 空状态界面 ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isZh) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 空状态插图（使用内置图标模拟）
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.sageMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: AppColors.sageGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isZh ? '暂无通知' : 'No Notifications',
            style: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            isZh
                ? '当 Biscuit 状态异常时\n我们会第一时间通知你'
                : 'We\'ll notify you immediately\nif your pet needs attention',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── 确认清除全部对话框 ────────────────────────────────────────────────────
  void _confirmClearAll(
      BuildContext context, bool isZh, NotificationProvider provider) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(isZh ? '清除全部通知' : 'Clear All Notifications'),
        content: Text(
          isZh ? '确定要清除所有通知记录吗？此操作无法撤销。' : 'Are you sure? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isZh ? '取消' : 'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              overlayColor: Colors.transparent,
            ),
            child: Text(
              isZh ? '清除' : 'Clear',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
