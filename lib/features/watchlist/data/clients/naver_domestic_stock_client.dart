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
    // TODO(assignment): Implement the Naver autocomplete request.
    //
    // Goal:
    // - Call https://ac.stock.naver.com/ac with Dio.
    // - Send q=<query> and target=stock,ipo,index,marketindicator.
    // - Use _defaultHeaders and ResponseType.plain because the response body
    //   may arrive as a String instead of a decoded JSON map.
    // - Decode the response with _decodeJsonObjectBody.
    // - Read the "items" array and map each entry with
    //   NaverAutocompleteItemDto.fromJson.
    //
    // Related tests:
    // - test/features/watchlist/data/naver_stock_dtos_test.dart
    // - test/features/watchlist/data/naver_watchlist_repository_test.dart
    throw UnimplementedError(
      'TODO(assignment): implement NaverDomesticStockClient.searchStocks',
    );
  }

  @override
  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    // TODO(assignment): Implement the Naver realtime quote request.
    //
    // Goal:
    // - Deduplicate the incoming symbols.
    // - Return an empty map when there is nothing to request.
    // - Build query=SERVICE_ITEM:005930,000660 style payload.
    // - Call https://polling.finance.naver.com/api/realtime.
    // - Decode the JSON body, then traverse result -> areas -> datas.
    // - Convert each realtime row with NaverRealtimeQuoteDto.fromJson.
    // - Return a map keyed by the six-digit domestic symbol.
    //
    // Note:
    // - The response body may be plain text JSON, so use ResponseType.plain.
    // - Some tests use a fake client, but the real app depends on this method.
    throw UnimplementedError(
      'TODO(assignment): implement NaverDomesticStockClient.fetchRealtimeQuotes',
    );
  }

  @override
  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol) async {
    // TODO(assignment): Implement the chart metadata request.
    //
    // Goal:
    // - Call
    //   https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/{symbol}
    // - Decode the JSON object with _decodeJsonObjectBody.
    // - Convert the payload with NaverChartMetadataDto.fromJson.
    //
    // Required fields for the DTO:
    // - symbolCode
    // - stockName
    // - stockExchangeNameKor
    throw UnimplementedError(
      'TODO(assignment): implement NaverDomesticStockClient.fetchChartMetadata',
    );
  }

  @override
  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  }) async {
    // TODO(assignment): Implement parsing for the legacy daily history page.
    //
    // Goal:
    // - Validate that page >= 1.
    // - Request https://finance.naver.com/item/sise_day.naver
    //   with code=<symbol> and page=<page>.
    // - Use ResponseType.bytes and decode the HTML with latin1.
    // - Parse one page of historical rows from the HTML table.
    // - For each row, extract:
    //   - localDate (yyyyMMdd)
    //   - closePrice
    //   - openPrice
    //   - highPrice
    //   - lowPrice
    //   - accumulatedTradingVolume
    // - Also extract lastPage from the pagination area.
    //
    // Hint:
    // - The rendered table order is close, change, open, high, low, volume.
    // - You can keep using NaverHistoricalPriceDto.fromJson to build rows.
    throw UnimplementedError(
      'TODO(assignment): implement NaverDomesticStockClient.fetchDailyHistoryPage',
    );
  }
}

double _parseDouble(String value) {
  return double.parse(value.replaceAll(',', ''));
}

int _parseInt(String value) {
  return int.parse(value.replaceAll(',', ''));
}

Map<String, String> naverDesktopLikeHeaders() =>
    Map<String, String>.unmodifiable(NaverDomesticStockClient._defaultHeaders);
