// ignore_for_file: unused_element, unused_field

import 'dart:convert';

import 'package:dio/dio.dart';

import '../dtos/naver_stock_dtos.dart';

abstract interface class NaverStockDataClient {
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query);

  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  );

  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol);

  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  });
}

class NaverDomesticStockClient implements NaverStockDataClient {
  const NaverDomesticStockClient(this._dio);

  final Dio _dio;

  static const Map<String, String> _defaultHeaders = {
    'accept': 'application/json, text/plain, */*',
    'referer': 'https://m.stock.naver.com/',
    'accept-language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/123.0.0.0 Safari/537.36',
  };

  static Map<String, dynamic> _decodeJsonObjectBody(
    Object? data,
    String contextLabel,
  ) {
    if (data == null) {
      throw FormatException('$contextLabel response body is empty');
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is List<int>) {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel response body has unsupported shape');
  }

  static Map<String, dynamic> _asStringKeyedMap(
    Object? value,
    String contextLabel,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel is not a JSON object');
  }

  @override
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query) async {
    // client는 네이버 응답을 DTO로 바꾸는 역할만 맡고,
    // 국내/6자리 종목 필터링은 repository에서 앱 정책으로 처리한다.
    final response = await _dio.get<Object?>(
      'https://ac.stock.naver.com/ac',
      queryParameters: {
        'q': query,
        'target': 'stock,ipo,index,marketindicator',
      },
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final body = _decodeJsonObjectBody(response.data, 'Naver autocomplete');
    final rawItems = body['items'];
    if (rawItems is! List) {
      throw const FormatException('Naver autocomplete items is not a list');
    }

    return [
      for (final item in _flattenAutocompleteItems(rawItems))
        NaverAutocompleteItemDto.fromJson(item),
    ];
  }

  @override
  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    // realtime API는 SERVICE_ITEM에 여러 symbol을 묶어 요청할 수 있으므로
    // 중복과 잘못된 코드를 먼저 제거해 불필요한 네트워크 호출을 줄인다.
    final requestedSymbols = symbols
        .map((symbol) => symbol.trim())
        .where((symbol) => RegExp(r'^\d{6}$').hasMatch(symbol))
        .toSet()
        .toList(growable: false);
    if (requestedSymbols.isEmpty) {
      return const {};
    }

    final response = await _dio.get<Object?>(
      'https://polling.finance.naver.com/api/realtime',
      queryParameters: {'query': 'SERVICE_ITEM:${requestedSymbols.join(',')}'},
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final body = _decodeJsonObjectBody(response.data, 'Naver realtime');
    final result = _asStringKeyedMap(body['result'], 'Naver realtime result');
    final areas = result['areas'];
    if (areas is! List) {
      throw const FormatException('Naver realtime areas is not a list');
    }

    final quotes = <String, NaverRealtimeQuoteDto>{};
    for (final area in areas) {
      final areaMap = _asStringKeyedMap(area, 'Naver realtime area');
      final datas = areaMap['datas'];
      if (datas is! List) {
        continue;
      }

      for (final row in datas) {
        final quote = NaverRealtimeQuoteDto.fromJson(
          _asStringKeyedMap(row, 'Naver realtime row'),
        );
        // repository에서 최신 시세를 바로 찾을 수 있도록 symbol을 key로 둔다.
        quotes[quote.symbol] = quote;
      }
    }

    return quotes;
  }

  @override
  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol) async {
    final response = await _dio.get<Object?>(
      'https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/$symbol',
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final body = _decodeJsonObjectBody(response.data, 'Naver chart metadata');
    // 실제 응답이 루트 객체로 오거나 result/data에 감싸져 오는 경우를 같이 흡수한다.
    final payload = body.containsKey('symbolCode')
        ? body
        : _asStringKeyedMap(
            body['result'] ?? body['data'],
            'Naver chart metadata payload',
          );
    return NaverChartMetadataDto.fromJson(payload);
  }

  @override
  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  }) async {
    // 일별 시세는 HTML 기반 legacy 페이지라 JSON DTO로 바로 받을 수 없다.
    // 여기서 표를 읽어 DTO row로 맞춰 두면 repository는 데이터 출처를 몰라도 된다.
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'page must be 1 or greater');
    }

    final response = await _dio.get<Object?>(
      'https://finance.naver.com/item/sise_day.naver',
      queryParameters: {'code': symbol, 'page': page},
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.bytes,
      ),
    );

    final html = switch (response.data) {
      final List<int> bytes => latin1.decode(bytes),
      final String text => text,
      final Object? value => value?.toString() ?? '',
    };

    return NaverDailyHistoryPageDto(
      symbol: symbol,
      page: page,
      lastPage: _extractLastPage(html, fallbackPage: page),
      priceInfos: _extractHistoricalRows(html),
    );
  }
}

Iterable<Map<String, dynamic>> _flattenAutocompleteItems(
  List<Object?> items,
) sync* {
  // 자동완성 items는 카테고리별 중첩 리스트로 올 수 있어 row 단위로 평탄화한다.
  for (final item in items) {
    if (item is Map<String, dynamic>) {
      yield item;
    } else if (item is Map) {
      yield item.map((key, value) => MapEntry(key.toString(), value));
    } else if (item is List) {
      yield* _flattenAutocompleteItems(item);
    }
  }
}

List<NaverHistoricalPriceDto> _extractHistoricalRows(String html) {
  final rows = <NaverHistoricalPriceDto>[];
  final rowPattern = RegExp(
    r'<tr[^>]*>(.*?)</tr>',
    caseSensitive: false,
    dotAll: true,
  );
  final cellPattern = RegExp(
    r'<td[^>]*>(.*?)</td>',
    caseSensitive: false,
    dotAll: true,
  );
  final datePattern = RegExp(r'\d{4}[.\-/]\d{2}[.\-/]\d{2}|\d{8}');

  for (final rowMatch in rowPattern.allMatches(html)) {
    final rowHtml = rowMatch.group(1) ?? '';
    final cells = [
      for (final cellMatch in cellPattern.allMatches(rowHtml))
        _plainHtmlText(cellMatch.group(1) ?? ''),
    ];
    if (cells.length < 7 || !datePattern.hasMatch(cells.first)) {
      continue;
    }

    rows.add(
      NaverHistoricalPriceDto.fromJson({
        'localDate': cells[0],
        'closePrice': cells[1],
        // 네이버 표 순서: 날짜, 종가, 전일비, 시가, 고가, 저가, 거래량.
        // 전일비는 앱 계산에 직접 쓰지 않아 건너뛴다.
        'openPrice': cells[3],
        'highPrice': cells[4],
        'lowPrice': cells[5],
        'accumulatedTradingVolume': cells[6],
      }),
    );
  }

  return rows;
}

int _extractLastPage(String html, {required int fallbackPage}) {
  var lastPage = fallbackPage;
  // 페이지 링크 전체에서 가장 큰 page 값을 마지막 페이지로 본다.
  for (final match in RegExp(r'(?:[?&]|&amp;)page=(\d+)').allMatches(html)) {
    final page = int.tryParse(match.group(1) ?? '');
    if (page != null && page > lastPage) {
      lastPage = page;
    }
  }
  return lastPage;
}

String _plainHtmlText(String html) {
  return html
      .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), ' ')
      .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double _parseDouble(String value) {
  return double.parse(value.replaceAll(',', ''));
}

int _parseInt(String value) {
  return int.parse(value.replaceAll(',', ''));
}

Map<String, String> naverDesktopLikeHeaders() =>
    Map<String, String>.unmodifiable(NaverDomesticStockClient._defaultHeaders);
