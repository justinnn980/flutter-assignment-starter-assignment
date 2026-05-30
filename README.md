# Flutter 신입 개발자 과제

국내 주식 관심종목 앱을 구현하는 과제입니다.  
제공된 Figma와 현재 코드베이스를 바탕으로, 비어 있는 구현을 완성해 주세요.

이 문서에는 과제를 진행하는 데 필요한 정보만 정리되어 있습니다.

Figma:

- https://www.figma.com/design/PQzKEAE10r0kUWrSceSy8F/-%EC%9D%B4%EB%93%A0%ED%81%AC%EB%A3%A8--%ED%8F%89%EA%B0%80-%EA%B3%BC%EC%A0%9C?node-id=5-27&t=x2lLEXaC2Jwc9ibX-1

AI 도구를 활용해도 괜찮습니다.  
다만 과제 제출로 끝나는 것이 아니라, 이후 기술 면접에서 구현한 내용에 대해 구체적으로 질문할 예정입니다.  
직접 작성한 코드라고 설명할 수 있을 정도로 이해하고, 왜 그렇게 구현했는지 답변할 수 있어야 합니다.

## 과제에서 구현할 내용

이번 과제는 크게 3가지 영역으로 나뉩니다.

1. Naver 데이터를 가져오고 파싱하는 데이터 연동
2. Figma 기준으로 맞추는 UI 구현
3. 화면 상태와 즐겨찾기 상태를 동기화하는 로직

코드 안에는 `TODO(assignment)` 주석이 남아 있습니다.  
과제 대상 파일을 찾을 때 가장 먼저 참고해도 좋습니다.

## 바로 실행하기

앱 실행:

```bash
flutter run
```

`fvm`을 사용한다면:

```bash
fvm flutter run
```

정적 분석:

```bash
flutter analyze
```

전체 테스트:

```bash
flutter test
```

처음에는 일부 테스트가 실패하는 것이 정상입니다.  
실패한 테스트 이름과 메시지를 보면 어떤 기능이 비어 있는지 확인할 수 있습니다.

## 구현해야 할 기능

### 1. 데이터 연동

아래 기능을 구현해야 합니다.

- 검색어로 국내 종목을 조회합니다.
- 실시간 시세를 조회합니다.
- 종목 메타데이터를 조회합니다.
- 일별 시세 HTML 페이지를 파싱합니다.
- DTO를 작성하고, repository에서 앱 모델로 변환합니다.
- 관심종목 목록, 거래일 목록, 상세 30거래일 데이터를 구성합니다.

### 2. UI 구현

아래 화면 요소를 Figma 기준으로 구현해야 합니다.

- 검색 결과 행
  - 종목명/서브텍스트 2줄
  - 검색어 하이라이트
  - 하트 버튼
  - 선택 시 액션 버튼 영역
- 검색 토스트
  - blur, 배경, 보더, 그림자
  - 하트 + 체크 아이콘 조합
  - 토스트 문구 구조
- 날짜 선택 바텀시트
  - 연/월/일 선택 영역
  - 선택 상태 스타일
  - 취소/확인 버튼
- 날짜 변경 후 관심종목 목록과 상세가 함께 갱신되는 흐름

### 3. 상태 동기화

아래 상태 동기화를 구현해야 합니다.

- 즐겨찾기 상태가 바뀌면 검색 결과의 하트 상태도 함께 바뀝니다.
- 검색 직후에도 현재 즐겨찾기 상태가 결과에 반영됩니다.
- 즐겨찾기 추가 시 토스트가 보이고, 제거 시 토스트가 사라집니다.

## 과제 대상 파일

아래 파일들을 중심으로 구현하면 됩니다.

### 데이터 연동

- `lib/features/watchlist/data/clients/naver_domestic_stock_client.dart`
  - 검색 API 호출
  - realtime API 호출
  - 종목 메타데이터 API 호출
  - 일별 시세 HTML 파싱

- `lib/features/watchlist/data/dtos/naver_stock_dtos.dart`
  - DTO `fromJson`
  - 숫자/날짜 파싱

- `lib/features/watchlist/data/repositories/naver_watchlist_repository.dart`
  - 검색 결과 변환
  - 관심종목 목록 구성
  - 거래일 목록 lazy load
  - 상세 30거래일 window 계산

### UI 구현

- `lib/features/search/presentation/widgets/search_result_row.dart`
- `lib/features/search/presentation/widgets/search_toast.dart`
- `lib/features/watchlist/presentation/widgets/watchlist_date_bottom_sheet.dart`
- `lib/features/watchlist/presentation/screens/watchlist_screen.dart`

### 상태 동기화

- `lib/features/search/presentation/providers/search_controller.dart`

## Naver 데이터 연동 가이드

이번 과제는 endpoint를 직접 추적하는 과제가 아닙니다.  
어떤 API를 써야 하는지는 아래에 정리되어 있습니다.  
대신 요청, 파싱, DTO 작성, repository 연결은 직접 구현해야 합니다.

### 1. 검색 자동완성

무엇을 가져오나:

- 검색어로 종목 후보를 조회합니다.

요청:

```text
GET https://ac.stock.naver.com/ac
```

주요 query parameter:

- `q`: 검색어
- `target`: `stock,ipo,index,marketindicator`

응답에서 주로 사용하는 필드:

- `code`
- `name`
- `typeCode`
- `typeName`
- `url`
- `nationCode`
- `category`

과제에서 구현해야 하는 처리:

- 국내 주식만 남깁니다.
- 6자리 종목코드만 통과시킵니다.
- canonical id를 `domestic:{symbol}` 형태로 만듭니다.
- `StockSearchItem`으로 변환합니다.

### 2. 실시간 시세

무엇을 가져오나:

- 현재가, 전일 종가, 시가/고가/저가, 거래량 같은 실시간 수치를 조회합니다.

요청:

```text
GET https://polling.finance.naver.com/api/realtime
```

주요 query parameter:

- `query`: `SERVICE_ITEM:005930,000660` 같은 형태

응답에서 주로 사용하는 필드:

- `cd`: symbol
- `nv`: current price
- `pcv`: previous close
- `ov`: open
- `hv`: high
- `lv`: low
- `aq`: accumulated trading volume
- `countOfListedStock`

과제에서 구현해야 하는 처리:

- symbol 기준으로 빠르게 찾을 수 있는 형태로 정리합니다.
- 최신 날짜일 때만 realtime 값을 우선 사용합니다.
- 과거 날짜는 historical 데이터 기준으로 계산합니다.

### 3. 종목 메타데이터

무엇을 가져오나:

- 종목명, 거래소명 같은 기본 정보를 조회합니다.

요청:

```text
GET https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/{symbol}
```

응답에서 주로 사용하는 필드:

- `symbolCode`
- `stockName`
- `stockExchangeNameKor`

과제에서 구현해야 하는 처리:

- 이름과 거래소명을 search/watchlist UI 모델에 연결합니다.

### 4. 일별 시세 HTML

무엇을 가져오나:

- 날짜별 종가, 시가, 고가, 저가, 거래량과 마지막 페이지 정보를 가져옵니다.

요청:

```text
GET https://finance.naver.com/item/sise_day.naver
```

주요 query parameter:

- `code`: 6자리 종목코드
- `page`: 1 이상

이 API는 JSON이 아니라 HTML을 반환합니다.

파싱해서 추출해야 하는 값:

- `localDate`
- `closePrice`
- `openPrice`
- `highPrice`
- `lowPrice`
- `accumulatedTradingVolume`
- `lastPage`

구현할 때 주의할 점:

- 표의 숫자 순서는 `종가, 전일비, 시가, 고가, 저가, 거래량` 입니다.
- 날짜는 앱 내부에서 `yyyyMMdd` 기준으로 정규화해서 사용합니다.
- 상세 차트는 선택한 날짜를 포함해 **직전 30거래일** 데이터를 써야 합니다.
- `lastPage`를 읽어야 전체 거래일 목록을 끝까지 가져올 수 있습니다.

## 테스트와 자가 점검

### 1. 정적 분석

```bash
flutter analyze
```

### 2. 전체 테스트

```bash
flutter test
```

`flutter test`를 실행하면 일부 테스트가 실패할 수 있습니다.  
실패 메시지를 보면 어떤 기능이 아직 비어 있는지 확인할 수 있습니다.

대표적으로 확인하면 좋은 테스트:

- `test/features/watchlist/data/naver_stock_dtos_test.dart`
  - DTO 파싱
- `test/features/watchlist/data/naver_watchlist_repository_test.dart`
  - repository mapping / 날짜 로딩 / 30거래일 상세
- `test/features/search/presentation/search_screen_test.dart`
  - 검색 결과 행 / 선택 액션바 / 토스트 UI
- `test/features/search/presentation/providers/search_controller_test.dart`
  - favorite 상태 동기화 / toast 상태 반영
- `test/features/watchlist/presentation/watchlist_date_bottom_sheet_test.dart`
  - 날짜 선택 바텀시트 UI와 선택 동작
- `test/features/watchlist/presentation/watchlist_screen_test.dart`
  - 날짜 변경 후 목록/상세 동기화

### 3. 골든 테스트

골든 테스트는 현재 화면을 저장된 기준 이미지와 비교하는 테스트입니다.  

관련 파일:

- `test/features/search/presentation/goldens/search_screen_golden_test.dart`
- `test/features/watchlist/presentation/goldens/watchlist_screen_golden_test.dart`

## 데모 사용 방법

데모는 mock 데이터 전용입니다.

```bash
flutter run -t test/demo/main_demo.dart
```

`fvm`을 사용한다면:

```bash
fvm flutter run -t test/demo/main_demo.dart
```

데모에서 확인할 수 있는 것:

- 검색 동기화 흐름
- 관심 상세 흐름
- 재생 / 일시정지 / 이전 / 다음 / 재시작

데모는 구현 결과를 눈으로 확인하는 용도입니다.  
테스트를 통과시키는 과정과 함께 사용하면 진행 상황을 확인하기 좋습니다.

선택 실행: desktop integration

```bash
./test/tools/run_desktop_integration_tests.sh
```

Windows PowerShell:

```powershell
./test/tools/run_desktop_integration_tests.ps1
```

desktop integration은 선택 실행 항목입니다.  
기본 구현을 마친 뒤 마지막 점검 용도로 실행하는 것을 권장합니다.

## 진행 순서 추천

막히지 않고 진행하려면 아래 순서를 추천합니다.

1. `flutter test`를 먼저 실행해 어떤 테스트가 실패하는지 확인합니다.
2. `naver_stock_dtos.dart`부터 구현해 DTO 파싱 테스트를 맞춥니다.
3. `naver_domestic_stock_client.dart`와 `naver_watchlist_repository.dart`를 구현합니다.
4. search/watchlist 관련 테스트가 의미 있게 동작하는지 다시 확인합니다.
5. `SearchResultRow`, `SearchToast`, `WatchlistDateBottomSheet`를 Figma 기준으로 맞춥니다.
6. `SearchController`와 `watchlist_screen.dart`의 상태 동기화를 마무리합니다.
7. 골든 테스트와 데모로 최종 확인합니다.

구현을 진행할 때는 과제마다 짧은 주석이나 메모를 함께 남겨 주세요.  
예를 들어 아래 정도면 충분합니다.

- 이 코드를 어떤 방식으로 구현했는지
- 왜 그 방식으로 구현했는지
- 파싱 규칙, 상태 동기화 방식, UI 배치 기준에서 어떤 판단을 했는지

길게 작성할 필요는 없습니다.  
다만 다른 사람이 코드를 읽었을 때 구현 의도를 바로 이해할 수 있을 정도로는 남겨 주세요.

## 중점 확인 포인트

아래 항목을 특히 신경 써 주세요.

- Figma와 최대한 가깝게 UI를 구현했는지
- Naver 데이터를 안정적으로 파싱하고 앱 모델에 연결했는지
- favorite, 날짜 변경, 상세 패널 동기화가 자연스럽게 동작하는지
- 테스트와 데모를 활용해 스스로 검증했는지
- 기존 구조와 네이밍을 해치지 않고 코드를 정리했는지

## 제출 안내

제출 시 아래 내용을 함께 정리해 주세요.

- 구현한 코드
- `flutter analyze` 결과
- `flutter test` 결과
- 필요하다면 간단한 구현 메모
  - 어떤 순서로 구현했는지
  - 어떤 가정을 두었는지
  - 아직 남은 이슈가 있다면 무엇인지
- 과제별 구현 설명
  - 어떤 방식으로 구현했는지
  - 왜 그렇게 구현했는지
  - 코드 안에 짧은 주석으로 남기거나, 별도 메모로 정리해도 됩니다

## 라이선스

이 저장소는 평가 목적으로만 제공됩니다.  
복사, 수정, 배포, 상업적 이용은 Edencrew의 명시적인 허가 없이 허용되지 않습니다.

자세한 내용은 루트의 `LICENSE` 파일을 확인해 주세요.
