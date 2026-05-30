import 'package:flutter/material.dart';

import '../../../../theme/app_assets.dart';
import '../../../../theme/app_theme.dart';
import '../layout/search_layout_spec.dart';

class SearchToast extends StatelessWidget {
  const SearchToast({required this.layout, required this.message, super.key});

  final SearchLayoutSpec layout;
  final String message;

  @override
  Widget build(BuildContext context) {
    // TODO(assignment): Rebuild the toast shell to match Figma.
    // Expected structure:
    // - ClipRRect + BackdropFilter
    // - blurred glass background with border/shadow
    // - 20x20 heart + check composition
    // - message text styling that matches the design
    return Container(
      height: SearchLayoutSpec.toastHeight,
      padding: EdgeInsets.symmetric(horizontal: 16 * layout.horizontalScale),
      decoration: BoxDecoration(
        color: AppColors.bg.bg_2_212121,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            key: const Key('search-toast-favorite-icon'),
            width: 20,
            height: 20,
            child: AppAssetSlotIcon(
              assetPath: AppAssets.favoriteHeart,
              slotWidth: 20,
              slotHeight: 20,
              assetWidth: AppAssetSizes.favoriteHeart.width,
              assetHeight: AppAssetSizes.favoriteHeart.height,
              color: AppColors.mainAndAccent.up_f93f62,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.searchToast,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
