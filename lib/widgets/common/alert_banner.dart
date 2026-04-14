import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 预警横幅：紧凑布局，收起顶部 SafeArea 避免占用太多空间
class AlertBanner extends StatelessWidget {
  final String message;
  final String alertType;
  final VoidCallback onDismiss;

  const AlertBanner({
    super.key,
    required this.message,
    required this.alertType,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isShiver = alertType == 'shiver';
    final bannerColor = isShiver ? AppColors.alertRed : AppColors.warningAmber;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: bannerColor,
        // ⚠️ 关键修复：不在 AlertBanner 内使用 SafeArea，
        // 而是由父级 Stack 定位在 SafeArea 内部 —— 避免重复叠加顶部安全区
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isShiver ? Icons.warning_rounded : Icons.trending_down_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
