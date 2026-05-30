// ignore_for_file: unused_element, unused_field

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/watchlist_models.dart';
import '../../domain/repositories/watchlist_repository.dart';
import '../../domain/services/watchlist_sorting.dart';
import '../clients/naver_domestic_stock_client.dart';
import '../clients/naver_stock_logo_url_resolver.dart';
import '../dtos/naver_stock_dtos.dart';
import 'favorite_ids_local_store.dart';

class NaverWatchlistRepository implements WatchlistRepository {
  NaverWatchlistRepository({
    required Dio dio,
    required FavoriteIdsLocalStore favoriteIdsLocalStore,
    NaverStockDataClient? client,
    NaverStockLogoUrlResolver? logoUrlResolver,
    this.realtimeCacheTtl = const Duration(seconds: 10),
    this.dailyHistoryFetchBatchSize = 4,
  }) : _client = client ?? NaverDomesticStockClient(dio),
       _favoriteIdsLocalStore = favoriteIdsLocalStore,
       _logoUrlResolver = logoUrlResolver ?? const NaverStockLogoUrlResolver();

  static const _historyRowsPerPage = 10;

  final NaverStockDataClient _client;
  final FavoriteIdsLocalStore _favoriteIdsLocalStore;
  final NaverStockLogoUrlResolver _logoUrlResolver;
  final Duration realtimeCacheTtl;
  final int dailyHistoryFetchBatchSize;

  final Map<String, NaverChartMetadataDto> _metadataCache = {};
  final Map<String, NaverDailyHistoryPageDto> _dailyHistoryPageCache = {};
  final Map<String, _RealtimeQuoteCacheEntry> _realtimeQuoteCache = {};

  Set<String>? _favoriteIdsCache;
  List<DateTime>? _availableDatesCache;

  @override
  Future<WatchlistSnapshot> fetchWatchlist({DateTime? asOf}) async {
    // repository는 즐겨찾기 id를 앱 화면용 snapshot으로 조립한다.
    // 최신 거래일만 realtime을 섞고, 과거 날짜는 historical 값만 사용한다.
    final favoriteIds = await loadFavoriteIds();
    final symbols = _symbolsFromFavoriteIds(favoriteIds);
    final availableDates = await fetchAvailableDates();
    final resolvedAsOf = _resolveAsOf(availableDates, asOf);

    if (symbols.isEmpty) {
      return WatchlistSnapshot(
        asOf: resolvedAsOf,
        items: const [],
        availableDates: availableDates,
      );
    }

    final latestDate = availableDates.isEmpty ? null : availableDates.first;
    final shouldUseRealtime = latestDate != null && resolvedAsOf == latestDate;
    final metadataBySymbol = await _loadMetadataBatch(symbols);
    final realtimeQuotes = shouldUseRealtime
        ? await _loadRealtimeQuotes(symbols)
        : <String, NaverRealtimeQuoteDto>{};

    final items = <WatchlistItem>[];
    for (final symbol in symbols) {
      final metadata = metadataBySymbol[symbol];
      if (metadata == null) {
        continue;
      }

      final historicalEntry = shouldUseRealtime
          ? await _loadLatestHistoricalEntry(symbol)
          : await _loadHistoricalEntryForDate(
              symbol: symbol,
              availableDates: availableDates,
              asOf: resolvedAsOf,
            );
      if (historicalEntry == null) {
        continue;
      }

      items.add(
        _buildWatchlistItem(
          symbol: symbol,
          metadata: metadata,
          historicalEntry: historicalEntry,
          realtimeQuote: realtimeQuotes[symbol],
          latestDate: latestDate,
        ),
      );
    }

    return WatchlistSnapshot(
      asOf: resolvedAsOf,
      items: items,
      availableDates: availableDates,
    );
  }

  @override
  Future<List<DateTime>> fetchAvailableDates() async {
    // 거래일 목록은 종목마다 거의 같으므로 첫 관심종목을 기준으로 읽고 캐시한다.
    // first page에서 lastPage를 알아낸 뒤 나머지는 작은 batch로 가져온다.
    final cached = _availableDatesCache;
    if (cached != null) {
      return cached;
    }

    final symbols = _symbolsFromFavoriteIds(await loadFavoriteIds());
    if (symbols.isEmpty) {
      _availableDatesCache = const [];
      return _availableDatesCache!;
    }

    final referenceSymbol = symbols.first;
    final firstPage = await _loadDailyHistoryPage(referenceSymbol, 1);
    final pages = <NaverDailyHistoryPageDto>[firstPage];

    for (
      var startPage = 2;
      startPage <= firstPage.lastPage;
      startPage += dailyHistoryFetchBatchSize
    ) {
      final endPage = math.min(
        firstPage.lastPage,
        startPage + dailyHistoryFetchBatchSize - 1,
      );
      pages.addAll(
        await Future.wait([
          for (var page = startPage; page <= endPage; page += 1)
            _loadDailyHistoryPage(referenceSymbol, page),
        ]),
      );
    }

    final seenDateKeys = <String>{};
    final dates = <DateTime>[];
    for (final page in pages) {
      for (final row in page.priceInfos) {
        final date = normalizeAsOfDate(row.localDate);
        if (seenDateKeys.add(_dateKey(date))) {
          dates.add(date);
        }
      }
    }
    dates.sort((left, right) => right.compareTo(left));

    _availableDatesCache = List<DateTime>.unmodifiable(dates);
    return _availableDatesCache!;
  }

  @override
  Future<WatchlistDetail> fetchWatchlistDetail({
    required String symbol,
    required MarketType market,
    DateTime? asOf,
  }) async {
    // 상세는 선택 날짜를 포함한 직전 30거래일 window로 만든다.
    // 최신 날짜일 때만 realtime row로 선택일 OHLCV를 보정한다.
    if (market != MarketType.domestic) {
      throw UnsupportedError('Only domestic Naver stock detail is supported.');
    }

    final normalizedSymbol = symbol.trim();
    final availableDates = await _availableDatesForDetail(normalizedSymbol);
    final selectedDate = _resolveAsOf(availableDates, asOf);
    final selectedIndex = _indexOfDate(availableDates, selectedDate);
    if (selectedIndex == null) {
      throw StateError(
        'No daily history row is available for $normalizedSymbol',
      );
    }

    final latestDate = availableDates.isEmpty ? null : availableDates.first;
    final isLatest = latestDate != null && selectedDate == latestDate;
    final windowDates = availableDates.sublist(
      selectedIndex,
      math.min(selectedIndex + 30, availableDates.length),
    );
    final rowsByDate = await _loadRowsByDateForWindow(
      symbol: normalizedSymbol,
      startIndex: selectedIndex,
      endExclusive: selectedIndex + windowDates.length,
    );

    final selectedRow = rowsByDate[_dateKey(selectedDate)];
    if (selectedRow == null) {
      throw StateError('No selected daily history row for $normalizedSymbol');
    }

    final realtimeQuote = isLatest
        ? (await _loadRealtimeQuotes([normalizedSymbol]))[normalizedSymbol]
        : null;
    final previousClose =
        realtimeQuote?.previousClose ??
        await _resolvePreviousClose(
          symbol: normalizedSymbol,
          availableDates: availableDates,
          selectedIndex: selectedIndex,
          fallbackOpenPrice: selectedRow.openPrice,
          rowsByDate: rowsByDate,
        );
    final currentPrice = realtimeQuote?.currentPrice ?? selectedRow.closePrice;
    final adjustedRowsByDate = {...rowsByDate};
    if (realtimeQuote != null) {
      adjustedRowsByDate[_dateKey(selectedDate)] = NaverHistoricalPriceDto(
        localDate: selectedDate,
        closePrice: realtimeQuote.currentPrice,
        openPrice: realtimeQuote.openPrice,
        highPrice: realtimeQuote.highPrice,
        lowPrice: realtimeQuote.lowPrice,
        accumulatedTradingVolume: realtimeQuote.accumulatedTradingVolume,
      );
    }

    return WatchlistDetail(
      itemId: canonicalDomesticFavoriteId(normalizedSymbol),
      symbol: normalizedSymbol,
      market: MarketType.domestic,
      currency: 'KRW',
      currentPrice: currentPrice,
      changeAmount: currentPrice - previousClose,
      changeRate: _percentChange(currentPrice - previousClose, previousClose),
      tradeVolume:
          realtimeQuote?.accumulatedTradingVolume ??
          selectedRow.accumulatedTradingVolume,
      volumeRatio: _volumeRatio(
        windowDatesDescending: windowDates,
        rowsByDate: adjustedRowsByDate,
      ),
      openPrice: realtimeQuote?.openPrice ?? selectedRow.openPrice,
      openChangeRate: _percentChange(
        (realtimeQuote?.openPrice ?? selectedRow.openPrice) - previousClose,
        previousClose,
      ),
      highPrice: realtimeQuote?.highPrice ?? selectedRow.highPrice,
      highChangeRate: _percentChange(
        (realtimeQuote?.highPrice ?? selectedRow.highPrice) - previousClose,
        previousClose,
      ),
      lowPrice: realtimeQuote?.lowPrice ?? selectedRow.lowPrice,
      lowChangeRate: _percentChange(
        (realtimeQuote?.lowPrice ?? selectedRow.lowPrice) - previousClose,
        previousClose,
      ),
      candles: _candles(
        windowDatesDescending: windowDates,
        rowsByDate: adjustedRowsByDate,
      ),
    );
  }

  @override
  Future<List<StockSearchItem>> searchStocks({required String query}) async {
    // 검색 결과는 국내 6자리 종목만 남기고 앱 공통 id(domestic:{symbol})로 맞춘다.
    // favoriteIds를 함께 읽어 하트 상태가 검색 결과에 바로 반영되도록 한다.
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final favoriteIds = await loadFavoriteIds();
    final seenSymbols = <String>{};
    final results = <StockSearchItem>[];
    final items = await _client.searchStocks(trimmedQuery);

    for (final item in items) {
      if (!item.isDomesticStock || !seenSymbols.add(item.code)) {
        continue;
      }

      final id = canonicalDomesticFavoriteId(item.code);
      results.add(
        StockSearchItem(
          id: id,
          market: MarketType.domestic,
          marketLabel: item.typeName,
          symbol: item.code,
          name: item.name,
          isFavorite: favoriteIds.contains(id),
          logoUrl: _logoUrlResolver.resolveDomesticStockLogoUrl(item.code),
        ),
      );
    }

    return results;
  }

  @override
  Future<Set<String>> loadFavoriteIds() async {
    // 예전 mock id나 깨진 값이 저장돼 있으면 기본 국내 관심종목으로 복구한다.
    if (_favoriteIdsCache != null) {
      return Set<String>.unmodifiable(_favoriteIdsCache!);
    }

    final rawIds = await _favoriteIdsLocalStore.loadRawIds();
    final canonicalIds = rawIds.where(_isCanonicalFavoriteId).toSet();
    final hasLegacyOrInvalidIds =
        rawIds.isNotEmpty && canonicalIds.length != rawIds.length;

    final resolvedIds = !_favoriteIdsLocalStore.hasStoredIds
        ? <String>{...defaultNaverDomesticFavoriteIds}
        : hasLegacyOrInvalidIds
        ? <String>{...defaultNaverDomesticFavoriteIds}
        : canonicalIds;

    _favoriteIdsCache = resolvedIds;

    if (!setEquals(rawIds, resolvedIds)) {
      await _favoriteIdsLocalStore.saveRawIds(resolvedIds);
    }

    return Set<String>.unmodifiable(resolvedIds);
  }

  @override
  Future<void> addFavorite({required String itemId}) async {
    final canonicalId = _requireCanonicalFavoriteId(itemId);
    final favoriteIds = {...await loadFavoriteIds(), canonicalId};
    _favoriteIdsCache = favoriteIds;
    await _favoriteIdsLocalStore.saveRawIds(favoriteIds);
  }

  @override
  Future<void> removeFavorite({required String itemId}) async {
    final canonicalId = _requireCanonicalFavoriteId(itemId);
    final favoriteIds = {...await loadFavoriteIds()}..remove(canonicalId);
    _favoriteIdsCache = favoriteIds;
    await _favoriteIdsLocalStore.saveRawIds(favoriteIds);
  }

  Future<Map<String, NaverChartMetadataDto>> _loadMetadataBatch(
    List<String> symbols,
  ) async {
    final results = <String, NaverChartMetadataDto>{};
    for (final symbol in symbols) {
      try {
        results[symbol] = await _loadMetadata(symbol);
      } catch (error, stackTrace) {
        debugPrint('Skipping Naver metadata for $symbol: $error\n$stackTrace');
      }
    }
    return results;
  }

  Future<NaverChartMetadataDto> _loadMetadata(String symbol) async {
    final cached = _metadataCache[symbol];
    if (cached != null) {
      return cached;
    }

    final metadata = await _client.fetchChartMetadata(symbol);
    _metadataCache[symbol] = metadata;
    return metadata;
  }

  Future<NaverDailyHistoryPageDto> _loadDailyHistoryPage(
    String symbol,
    int page,
  ) async {
    final cacheKey = _dailyHistoryPageCacheKey(symbol, page);
    final cached = _dailyHistoryPageCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final historyPage = await _client.fetchDailyHistoryPage(
      symbol: symbol,
      page: page,
    );
    _dailyHistoryPageCache[cacheKey] = historyPage;
    return historyPage;
  }

  Future<Map<String, NaverRealtimeQuoteDto>> _loadRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    // realtime은 자주 변하지만 같은 화면 갱신 중에는 재사용해도 충분하므로
    // 짧은 TTL 캐시를 둔다. 실패하면 historical-only 화면으로 계속 진행한다.
    final requestedSymbols = symbols.toSet();
    final now = DateTime.now();
    final missingSymbols = <String>[];
    final quotes = <String, NaverRealtimeQuoteDto>{};

    for (final symbol in requestedSymbols) {
      final cached = _realtimeQuoteCache[symbol];
      final isFresh =
          cached != null &&
          now.difference(cached.fetchedAt) <= realtimeCacheTtl;
      if (isFresh) {
        quotes[symbol] = cached.quote;
      } else {
        missingSymbols.add(symbol);
      }
    }

    if (missingSymbols.isNotEmpty) {
      try {
        final fetchedQuotes = await _client.fetchRealtimeQuotes(missingSymbols);
        final fetchedAt = DateTime.now();
        for (final entry in fetchedQuotes.entries) {
          _realtimeQuoteCache[entry.key] = _RealtimeQuoteCacheEntry(
            quote: entry.value,
            fetchedAt: fetchedAt,
          );
          quotes[entry.key] = entry.value;
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Falling back to historical-only Naver data for realtime batch: '
          '$error\n$stackTrace',
        );
      }
    }

    return quotes;
  }

  Future<_HistoricalEntry?> _loadHistoricalEntryForDate({
    required String symbol,
    required List<DateTime> availableDates,
    required DateTime asOf,
  }) async {
    final selectedIndex = _indexOfDate(availableDates, asOf);
    if (selectedIndex == null) {
      return null;
    }

    final selectedPageNumber = _pageNumberForIndex(selectedIndex);
    final selectedPage = await _loadDailyHistoryPage(
      symbol,
      selectedPageNumber,
    );
    final selectedRow = _rowForDate(selectedPage.priceInfos, asOf);
    if (selectedRow == null) {
      return null;
    }

    final previousClose = await _resolvePreviousClose(
      symbol: symbol,
      availableDates: availableDates,
      selectedIndex: selectedIndex,
      fallbackOpenPrice: selectedRow.openPrice,
      rowsByDate: {
        for (final row in selectedPage.priceInfos) _dateKey(row.localDate): row,
      },
    );

    return _HistoricalEntry(row: selectedRow, previousClose: previousClose);
  }

  Future<_HistoricalEntry?> _loadLatestHistoricalEntry(String symbol) async {
    final firstPage = await _loadDailyHistoryPage(symbol, 1);
    if (firstPage.priceInfos.isEmpty) {
      return null;
    }

    final selectedRow = firstPage.priceInfos.first;
    double previousClose = selectedRow.openPrice;
    if (firstPage.priceInfos.length > 1) {
      previousClose = firstPage.priceInfos[1].closePrice;
    } else if (firstPage.page < firstPage.lastPage) {
      final nextPageRows = (await _loadDailyHistoryPage(symbol, 2)).priceInfos;
      if (nextPageRows.isNotEmpty) {
        previousClose = nextPageRows.first.closePrice;
      }
    }

    return _HistoricalEntry(row: selectedRow, previousClose: previousClose);
  }

  Future<List<DateTime>> _availableDatesForDetail(String symbol) async {
    final availableDates = await fetchAvailableDates();
    if (availableDates.isNotEmpty) {
      return availableDates;
    }

    final firstPage = await _loadDailyHistoryPage(symbol, 1);
    final dates = [
      for (final row in firstPage.priceInfos) normalizeAsOfDate(row.localDate),
    ]..sort((left, right) => right.compareTo(left));
    return List<DateTime>.unmodifiable(dates);
  }

  Future<Map<String, NaverHistoricalPriceDto>> _loadRowsByDateForWindow({
    required String symbol,
    required int startIndex,
    required int endExclusive,
  }) async {
    final rowsByDate = <String, NaverHistoricalPriceDto>{};
    final pageNumbers = <int>{};
    for (var index = startIndex; index < endExclusive; index += 1) {
      pageNumbers.add(_pageNumberForIndex(index));
    }

    for (final pageNumber in pageNumbers) {
      final page = await _loadDailyHistoryPage(symbol, pageNumber);
      for (final row in page.priceInfos) {
        rowsByDate[_dateKey(row.localDate)] = row;
      }
    }

    return rowsByDate;
  }

  Future<double> _resolvePreviousClose({
    required String symbol,
    required List<DateTime> availableDates,
    required int selectedIndex,
    required double fallbackOpenPrice,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) async {
    if (selectedIndex >= availableDates.length - 1) {
      return fallbackOpenPrice;
    }

    final previousDate = availableDates[selectedIndex + 1];
    final previousRowFromCache = rowsByDate[_dateKey(previousDate)];
    if (previousRowFromCache != null) {
      return previousRowFromCache.closePrice;
    }

    final page = await _loadDailyHistoryPage(
      symbol,
      _pageNumberForIndex(selectedIndex + 1),
    );
    final previousRow = _rowForDate(page.priceInfos, previousDate);
    return previousRow?.closePrice ?? fallbackOpenPrice;
  }

  WatchlistItem _buildWatchlistItem({
    required String symbol,
    required NaverChartMetadataDto metadata,
    required _HistoricalEntry historicalEntry,
    required NaverRealtimeQuoteDto? realtimeQuote,
    required DateTime? latestDate,
  }) {
    final isLatest =
        latestDate != null &&
        normalizeAsOfDate(historicalEntry.row.localDate) == latestDate;
    final currentPrice = isLatest && realtimeQuote != null
        ? realtimeQuote.currentPrice
        : historicalEntry.row.closePrice;
    final changeRate = isLatest && realtimeQuote != null
        ? realtimeQuote.changeRate
        : _percentChange(
            currentPrice - historicalEntry.previousClose,
            historicalEntry.previousClose,
          );
    final tradeVolume = isLatest && realtimeQuote != null
        ? realtimeQuote.accumulatedTradingVolume
        : historicalEntry.row.accumulatedTradingVolume;
    final marketCap = realtimeQuote == null
        ? 0
        : (realtimeQuote.countOfListedStock * realtimeQuote.currentPrice)
              .round();

    return WatchlistItem(
      id: canonicalDomesticFavoriteId(symbol),
      market: MarketType.domestic,
      symbol: symbol,
      name: metadata.stockName,
      currency: 'KRW',
      currentPrice: currentPrice,
      changeRate: changeRate,
      tradeVolume: tradeVolume,
      marketCap: marketCap,
      logoUrl: _logoUrlResolver.resolveDomesticStockLogoUrl(symbol),
    );
  }

  DateTime _resolveAsOf(
    List<DateTime> availableDates,
    DateTime? requestedAsOf,
  ) {
    if (availableDates.isEmpty) {
      return normalizeAsOfDate(requestedAsOf ?? DateTime.now());
    }

    if (requestedAsOf == null) {
      return availableDates.first;
    }

    final normalizedAsOf = normalizeAsOfDate(requestedAsOf);
    for (final date in availableDates) {
      if (date == normalizedAsOf) {
        return date;
      }
    }

    return availableDates.first;
  }

  int? _indexOfDate(List<DateTime> availableDates, DateTime asOf) {
    final normalizedAsOf = normalizeAsOfDate(asOf);
    for (var index = 0; index < availableDates.length; index += 1) {
      if (availableDates[index] == normalizedAsOf) {
        return index;
      }
    }
    return null;
  }

  int _pageNumberForIndex(int index) {
    return (index ~/ _historyRowsPerPage) + 1;
  }

  NaverHistoricalPriceDto? _rowForDate(
    Iterable<NaverHistoricalPriceDto> rows,
    DateTime date,
  ) {
    final dateKey = _dateKey(date);
    for (final row in rows) {
      if (_dateKey(row.localDate) == dateKey) {
        return row;
      }
    }
    return null;
  }

  double _volumeRatio({
    required List<DateTime> windowDatesDescending,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) {
    // 거래량 비율은 선택일 거래량을 직전 최대 5거래일 평균과 비교해 표시한다.
    if (windowDatesDescending.isEmpty) {
      return 0;
    }

    final selectedRow = rowsByDate[_dateKey(windowDatesDescending.first)];
    if (selectedRow == null) {
      return 0;
    }

    final previousVolumes = <int>[];
    for (
      var index = 1;
      index < windowDatesDescending.length && previousVolumes.length < 5;
      index += 1
    ) {
      final row = rowsByDate[_dateKey(windowDatesDescending[index])];
      if (row != null) {
        previousVolumes.add(row.accumulatedTradingVolume);
      }
    }

    if (previousVolumes.isEmpty) {
      return 0;
    }

    final averageVolume =
        previousVolumes.reduce((left, right) => left + right) /
        previousVolumes.length;
    if (averageVolume == 0) {
      return 0;
    }

    return double.parse(
      (selectedRow.accumulatedTradingVolume / averageVolume).toStringAsFixed(2),
    );
  }

  List<CandlePoint> _candles({
    required List<DateTime> windowDatesDescending,
    required Map<String, NaverHistoricalPriceDto> rowsByDate,
  }) {
    // 화면 차트는 오래된 날짜에서 최신 날짜 순서로 그리기 위해 window를 뒤집는다.
    return windowDatesDescending.reversed
        .map((date) => rowsByDate[_dateKey(date)])
        .whereType<NaverHistoricalPriceDto>()
        .map(
          (item) => CandlePoint(
            time: item.localDate,
            open: item.openPrice,
            high: item.highPrice,
            low: item.lowPrice,
            close: item.closePrice,
            direction: directionFromDelta(item.closePrice - item.openPrice),
          ),
        )
        .toList(growable: false);
  }

  bool _isCanonicalFavoriteId(String itemId) {
    return domesticSymbolFromFavoriteId(itemId) != null;
  }

  List<String> _symbolsFromFavoriteIds(Iterable<String> favoriteIds) {
    final symbols = <String>[];
    for (final itemId in favoriteIds) {
      final symbol = domesticSymbolFromFavoriteId(itemId);
      if (symbol != null) {
        symbols.add(symbol);
      }
    }
    return symbols;
  }

  String _requireCanonicalFavoriteId(String itemId) {
    final symbol = domesticSymbolFromFavoriteId(itemId);
    if (symbol == null) {
      throw ArgumentError.value(
        itemId,
        'itemId',
        'Naver repository only accepts canonical domestic favorite ids',
      );
    }
    return canonicalDomesticFavoriteId(symbol);
  }

  String _dailyHistoryPageCacheKey(String symbol, int page) => '$symbol::$page';

  String _dateKey(DateTime value) => formatApiDate(value);

  double _percentChange(double delta, double base) {
    if (base == 0) {
      return 0;
    }
    return double.parse(((delta / base) * 100).toStringAsFixed(2));
  }
}

class _RealtimeQuoteCacheEntry {
  const _RealtimeQuoteCacheEntry({
    required this.quote,
    required this.fetchedAt,
  });

  final NaverRealtimeQuoteDto quote;
  final DateTime fetchedAt;
}

class _HistoricalEntry {
  const _HistoricalEntry({required this.row, required this.previousClose});

  final NaverHistoricalPriceDto row;
  final double previousClose;
}
