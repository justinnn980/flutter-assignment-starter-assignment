// ignore_for_file: unused_element

import '../../domain/services/watchlist_sorting.dart';

class NaverAutocompleteItemDto {
  const NaverAutocompleteItemDto({
    required this.code,
    required this.name,
    required this.typeCode,
    required this.typeName,
    required this.url,
    required this.nationCode,
    required this.category,
  });

  factory NaverAutocompleteItemDto.fromJson(Map<String, dynamic> json) {
    // 응답 원본 필드를 DTO에 그대로 보존하고, 국내/6자리 종목 필터링은
    // isDomesticStock과 repository 단계에서 처리해 파싱 책임을 분리한다.
    return NaverAutocompleteItemDto(
      code: _readString(json['code']),
      name: _readString(json['name']),
      typeCode: _readString(json['typeCode']),
      typeName: _readString(json['typeName']),
      url: _readString(json['url']),
      nationCode: _readString(json['nationCode']),
      category: _readString(json['category']),
    );
  }

  final String code;
  final String name;
  final String typeCode;
  final String typeName;
  final String url;
  final String nationCode;
  final String category;

  bool get isDomesticStock =>
      category == 'stock' &&
      nationCode == 'KOR' &&
      RegExp(r'^\d{6}$').hasMatch(code) &&
      url.contains('/domestic/stock/');
}

class NaverRealtimeQuoteDto {
  const NaverRealtimeQuoteDto({
    required this.symbol,
    required this.currentPrice,
    required this.previousClose,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.accumulatedTradingVolume,
    required this.countOfListedStock,
  });

  factory NaverRealtimeQuoteDto.fromJson(Map<String, dynamic> json) {
    // 네이버 realtime 응답은 축약 키를 쓰고 숫자가 문자열/num으로 섞일 수 있어
    // 공통 reader로 정규화한다. 상장주식수는 선택값이라 없으면 시총 계산만 생략한다.
    return NaverRealtimeQuoteDto(
      symbol: _readString(json['cd']),
      currentPrice: _readDouble(json['nv']),
      previousClose: _readDouble(json['pcv']),
      openPrice: _readDouble(json['ov']),
      highPrice: _readDouble(json['hv']),
      lowPrice: _readDouble(json['lv']),
      accumulatedTradingVolume: _readInt(json['aq']),
      countOfListedStock: _readNullableInt(json['countOfListedStock']) ?? 0,
    );
  }

  final String symbol;
  final double currentPrice;
  final double previousClose;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final int accumulatedTradingVolume;
  final int countOfListedStock;

  double get changeAmount => currentPrice - previousClose;

  double get changeRate {
    if (previousClose == 0) {
      return 0;
    }
    return double.parse(
      (((currentPrice - previousClose) / previousClose) * 100).toStringAsFixed(
        2,
      ),
    );
  }
}

class NaverChartMetadataDto {
  const NaverChartMetadataDto({
    required this.symbol,
    required this.stockName,
    required this.stockExchangeNameKor,
  });

  factory NaverChartMetadataDto.fromJson(Map<String, dynamic> json) {
    // 메타데이터는 화면 표시와 repository 매핑에 필요한 최소 필드만 읽는다.
    return NaverChartMetadataDto(
      symbol: _readString(json['symbolCode']),
      stockName: _readString(json['stockName']),
      stockExchangeNameKor: _readString(json['stockExchangeNameKor']),
    );
  }

  final String symbol;
  final String stockName;
  final String stockExchangeNameKor;
}

class NaverHistoricalPriceDto {
  const NaverHistoricalPriceDto({
    required this.localDate,
    required this.closePrice,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.accumulatedTradingVolume,
  });

  factory NaverHistoricalPriceDto.fromJson(Map<String, dynamic> json) {
    // JSON 차트와 HTML 파싱 결과가 같은 키를 사용하도록 맞춰 두면,
    // 과거 날짜/상세 차트 계산은 동일한 OHLCV 모델만 바라보면 된다.
    return NaverHistoricalPriceDto(
      localDate: _readLocalDate(json['localDate']),
      closePrice: _readDouble(json['closePrice']),
      openPrice: _readDouble(json['openPrice']),
      highPrice: _readDouble(json['highPrice']),
      lowPrice: _readDouble(json['lowPrice']),
      accumulatedTradingVolume: _readInt(json['accumulatedTradingVolume']),
    );
  }

  final DateTime localDate;
  final double closePrice;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final int accumulatedTradingVolume;
}

class NaverHistoricalChartDto {
  const NaverHistoricalChartDto({
    required this.symbol,
    required this.periodType,
    required this.priceInfos,
  });

  factory NaverHistoricalChartDto.fromJson(Map<String, dynamic> json) {
    // priceInfos의 각 row를 바로 도메인 모델로 넘기지 않고 DTO row로 변환해
    // 날짜 정규화와 숫자 파싱 규칙을 한곳에 모은다.
    final rawPriceInfos = json['priceInfos'];
    if (rawPriceInfos is! List) {
      throw FormatException('Naver priceInfos is not a list');
    }

    return NaverHistoricalChartDto(
      symbol: _readString(json['code']),
      periodType: _readString(json['periodType']),
      priceInfos: [
        for (final item in rawPriceInfos)
          NaverHistoricalPriceDto.fromJson(_readStringKeyedMap(item)),
      ],
    );
  }

  final String symbol;
  final String periodType;
  final List<NaverHistoricalPriceDto> priceInfos;
}

class NaverDailyHistoryPageDto {
  const NaverDailyHistoryPageDto({
    required this.symbol,
    required this.page,
    required this.lastPage,
    required this.priceInfos,
  });

  final String symbol;
  final int page;
  final int lastPage;
  final List<NaverHistoricalPriceDto> priceInfos;
}

DateTime _readLocalDate(Object? value) {
  // 내부 비교/캐시는 yyyyMMdd 기준의 날짜만 필요하므로 시간 정보는 제거한다.
  // HTML/JSON 소스 차이를 흡수하려고 구분자는 버리고 숫자 8자리만 사용한다.
  if (value is DateTime) {
    return normalizeAsOfDate(value);
  }

  final text = _readString(value);
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 8) {
    throw FormatException('Invalid Naver localDate "$text"');
  }

  return normalizeAsOfDate(
    DateTime(
      int.parse(digits.substring(0, 4)),
      int.parse(digits.substring(4, 6)),
      int.parse(digits.substring(6, 8)),
    ),
  );
}

String _readString(Object? value) {
  // 필수 응답값은 빈 문자열로 조용히 통과시키지 않고 바로 파싱 오류를 낸다.
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw FormatException('Missing string value for "$value"');
  }
  return text;
}

double _readDouble(Object? value) {
  // 네이버 숫자 응답은 180100 또는 "180,100" 형태가 섞여 들어올 수 있다.
  if (value is num) {
    return value.toDouble();
  }
  return double.parse(_readString(value).replaceAll(',', ''));
}

int _readInt(Object? value) {
  // 거래량/상장주식수처럼 정수 의미의 값은 num도 반올림해 int로 맞춘다.
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.parse(_readString(value).replaceAll(',', ''));
}

int? _readNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _readInt(value);
}

Map<String, dynamic> _readStringKeyedMap(Object? value) {
  // 테스트와 실제 JSON 디코딩 결과의 Map 타입 차이를 흡수한다.
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw FormatException('Expected Naver JSON object but found "$value"');
}
