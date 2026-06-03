import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../theme/app_theme.dart';

/// 圆形宠物头像（只读展示），监听 [PetHealthProvider] 与 [petPhotoRevision] 实时刷新。
class PetAvatarImage extends StatelessWidget {
  final double size;
  final double borderWidth;
  final double emojiSize;

  const PetAvatarImage({
    super.key,
    this.size = 52,
    this.borderWidth = 2.5,
    this.emojiSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final photoUrl = provider.pet.photoPath;
    final revision = provider.petPhotoRevision;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.sageGreen, width: borderWidth),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                key: ValueKey('pet_avatar_${revision}_$photoUrl'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text('🐶', style: TextStyle(fontSize: emojiSize)),
                ),
              )
            : Center(
                child: Text('🐶', style: TextStyle(fontSize: emojiSize)),
              ),
      ),
    );
  }
}
