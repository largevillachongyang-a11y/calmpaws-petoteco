import 'package:flutter/material.dart';

/// 圆形头像：支持 https 与 data:image base64。
class CirclePhoto extends StatelessWidget {
  final String? url;
  final double size;
  final String fallbackEmoji;
  final Object? rebuildKey;

  const CirclePhoto({
    super.key,
    required this.url,
    this.size = 64,
    this.fallbackEmoji = '👤',
    this.rebuildKey,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return ClipOval(
      child: hasUrl
          ? Image.network(
              url!,
              key: rebuildKey != null ? ValueKey('$rebuildKey$url') : null,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.44)),
    );
  }
}
