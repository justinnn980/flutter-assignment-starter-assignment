import 'package:flutter/material.dart';

import '../../../watchlist/domain/models/watchlist_models.dart';
import '../../../../theme/app_assets.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/services/search_text_utils.dart';
import '../layout/search_layout_spec.dart';
import 'search_action_bar.dart';

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
                        // 슬롯은 20×20: 아이콘 실제 크기(16×13)보다 약간 크게 잡아
                        // 터치 영역을 확보하면서 Figma 기준 슬롯에 맞춤
                        slotWidth: 20,
                        slotHeight: 20,
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
              // Figma 기준 액션바 위 8px 간격
              SizedBox(height: SearchLayoutSpec.expandedActionTopGap),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                // SearchActionBar에 key를 붙여 테스트에서 참조 가능하게 유지
                child: SearchActionBar(
                  key: Key('search-actions-${item.id}'),
                  layout: layout,
                  onActionTap: onActionTap,
                ),
              ),
              // Figma 기준 액션바 아래 8px 간격
              SizedBox(height: SearchLayoutSpec.expandedActionTopGap),
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
    // splitSearchTextParts로 텍스트를 일반/하이라이트 파트로 분리한 뒤
    // TextSpan 리스트로 변환해 RichText에 전달한다.
    // 하이라이트 색상은 Figma point_B980FF 기준.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: splitSearchTextParts(item.name, query)
                .map(
                  (part) => TextSpan(
                    text: part.text,
                    style: part.isHighlighted
                        ? AppTypography.searchName.copyWith(
                            color: AppColors.mainAndAccent.point_b980ff,
                          )
                        : AppTypography.searchName,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        // 서브텍스트(symbol | market)도 동일 방식으로 하이라이트 적용
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: splitSearchTextParts(buildSearchSubtitle(item), query)
                .map(
                  (part) => TextSpan(
                    text: part.text,
                    style: part.isHighlighted
                        ? AppTypography.searchMeta.copyWith(
                            color: AppColors.mainAndAccent.point_b980ff,
                          )
                        : AppTypography.searchMeta,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
