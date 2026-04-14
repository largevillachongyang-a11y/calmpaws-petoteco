import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isShiver ? AppColors.alertRed : AppColors.warningAmber,
          boxShadow: [
            BoxShadow(
              color: (isShiver ? AppColors.alertRed : AppColors.warningAmber)
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(
                  isShiver
                      ? Icons.warning_rounded
                      : Icons.trending_down_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
