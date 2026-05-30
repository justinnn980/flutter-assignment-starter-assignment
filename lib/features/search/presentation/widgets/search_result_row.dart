import 'package:flutter/material.dart';

import '../../../watchlist/domain/models/watchlist_models.dart';
import '../../../../theme/app_assets.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/services/search_text_utils.dart';
import '../layout/search_layout_spec.dart';

class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    required this.item,
    required this.query,
    required this.isSelected,
    required this.layout,
    required this.onTap,
    required this.onHeartTap,
    required this.onActionTap,
    super.key,
  });

  final StockSearchItem item;
  final String query;
  final bool isSelected;
  final SearchLayoutSpec layout;
  final VoidCallback onTap;
  final VoidCallback onHeartTap;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('search-result-${item.id}'),
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              key: Key('search-result-row-${item.id}'),
              height: SearchLayoutSpec.resultRowHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchTextColumn(item: item, query: query),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      key: Key('search-heart-${item.id}'),
                      onTap: onHeartTap,
                      behavior: HitTestBehavior.opaque,
                      child: AppAssetSlotIcon(
                        key: Key('search-heart-icon-${item.id}'),
                        assetPath: AppAssets.favoriteHeart,
                        // TODO(assignment): Match the exact Figma slot size.
                        // This starter keeps the slot slightly oversized so
                        // the related widget test can guide the fix.
                        slotWidth: 24,
                        slotHeight: 24,
                        assetWidth: AppAssetSizes.favoriteHeart.width,
                        assetHeight: AppAssetSizes.favoriteHeart.height,
                        color: item.isFavorite
                            ? AppColors.mainAndAccent.up_f93f62
                            : AppColors.darkTheme.c_424242,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 0),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Container(
                  key: Key('search-actions-${item.id}'),
                  height: SearchLayoutSpec.expandedActionHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bg.bg_2_212121,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border.border_5_3b3e53),
                  ),
                  child: InkWell(
                    onTap: () => onActionTap('TODO'),
                    child: Center(
                      child: Text(
                        'TODO(assignment): SearchActionBar를 Figma 기준으로 재구성하세요.',
                        style: AppTypography.searchMeta,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchTextColumn extends StatelessWidget {
  const _SearchTextColumn({required this.item, required this.query});

  final StockSearchItem item;
  final String query;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    // TODO(assignment): Rebuild this text block to match Figma.
    // Expected shape:
    // - title + subtitle as two RichText widgets
    // - query highlight using splitSearchTextParts()
    // - typography and ellipsis should match the design
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: hasQuery
              ? AppTypography.searchName.copyWith(
                  decoration: TextDecoration.none,
                )
              : AppTypography.searchName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          buildSearchSubtitle(item),
          style: AppTypography.searchMeta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
