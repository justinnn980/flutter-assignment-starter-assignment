import 'dart:ui';

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
    // ClipRRect로 blur가 border-radius 바깥으로 번지지 않게 clip한 뒤
    // BackdropFilter로 배경을 흐리게 — Figma glass morphism 효과
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: SearchLayoutSpec.toastHeight,
          // Figma: 좌우 16px, 위아래 23px padding (66 - 20 = 46 / 2 = 23)
          padding: EdgeInsets.symmetric(
            horizontal: 16 * layout.horizontalScale,
            vertical: 23,
          ),
          decoration: BoxDecoration(
            // 반투명 배경으로 뒤 컨텐츠가 blur되어 비쳐 보이는 효과
            color: AppDerivedColors.searchToastBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDerivedColors.searchToastBorder),
            boxShadow: [
              BoxShadow(
                color: AppDerivedColors.searchToastGlow,
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              // 하트(20×20) 위에 check 아이콘을 Stack으로 합성
              // Figma: 하트 우하단에 작은 체크 오버레이
              SizedBox(
                key: const Key('search-toast-favorite-icon'),
                width: 20,
                height: 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAssetSlotIcon(
                      assetPath: AppAssets.favoriteHeart,
                      slotWidth: 20,
                      slotHeight: 20,
                      assetWidth: AppAssetSizes.favoriteHeart.width,
                      assetHeight: AppAssetSizes.favoriteHeart.height,
                      color: AppColors.mainAndAccent.up_f93f62,
                    ),
                    Positioned(
                      right: 1,
                      bottom: 2,
                      child: AppAssetSlotIcon(
                        key: const Key('search-toast-check-icon'),
                        assetPath: AppAssets.toastCheck,
                        slotWidth: AppAssetSizes.toastCheck.width,
                        slotHeight: AppAssetSizes.toastCheck.height,
                        assetWidth: AppAssetSizes.toastCheck.width,
                        assetHeight: AppAssetSizes.toastCheck.height,
                        color: AppColors.grays.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Figma 아이콘-텍스트 간격 12px
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
        ),
      ),
    );
  }
}
