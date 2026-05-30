# Flutter 신입 개발자 과제 — 구현 완료

국내 주식 관심종목 앱 과제 구현 결과입니다.

Figma:
- https://www.figma.com/design/PQzKEAE10r0kUWrSceSy8F/-%EC%9D%B4%EB%93%A0%ED%81%AC%EB%A3%A8--%ED%8F%89%EA%B0%80-%EA%B3%BC%EC%A0%9C?node-id=5-27&t=x2lLEXaC2Jwc9ibX-1

---

## 실행 방법

```bash
flutter run
```

`fvm` 사용 시:

```bash
fvm flutter run
```

데모 실행:

```bash
flutter run -t test/demo/main_demo.dart
```

---

## 구현 내용

### 1. 네이버 주식 DTO 파싱 (`naver_stock_dtos.dart`)

검색 자동완성, 실시간 시세, 종목 메타데이터, 일별 시세 `fromJson`을 구현했습니다.

- 숫자 파싱: 쉼표 제거 후 `int.parse` / `double.parse`
- 날짜 파싱: `yyyy.MM.dd` → `DateTime`, 앱 내부는 `yyyyMMdd` 기준으로 정규화
- DTO가 파싱만 담당하고, 비즈니스 규칙(canonical id, 필터링)은 repository에서 처리

### 2. 네이버 관심종목 데이터 연동

**`naver_domestic_stock_client.dart`**

| 메서드 | 엔드포인트 | 설명 |
|---|---|---|
| 검색 자동완성 | `ac.stock.naver.com/ac` | 국내 6자리 종목코드만 통과 |
| 실시간 시세 | `polling.finance.naver.com/api/realtime` | `SERVICE_ITEM:{symbol}` 쿼리 |
| 종목 메타데이터 | `stock.naver.com/.../fchart/domestic/stock/{symbol}` | 이름·거래소명 |
| 일별 시세 HTML | `finance.naver.com/item/sise_day.naver` | HTML 파싱, `lastPage` 추출 |

**`naver_watchlist_repository.dart`**

- canonical id를 `domestic:{symbol}` 형태로 생성
- 최신 거래일은 realtime 값을 우선, 과거 날짜는 historical 기준으로 계산
- 거래일 목록 lazy load 및 캐싱
- 선택 날짜 기준 직전 30거래일 window로 상세 차트 데이터 구성

### 3. 검색 결과 행 UI (`search_result_row.dart`)

- 종목명·서브텍스트를 `RichText` 2개로 구성
- `splitSearchTextParts()`로 검색어 매칭 구간을 `#B980FF`로 하이라이트
- 하트 아이콘 슬롯 24×24 → 20×20 (Figma 기준)
- 선택 시 `SearchActionBar` (뉴스 / 종목토론) 표시, 상하 8px 간격

### 4. 검색 토스트 (`search_toast.dart`)

- `ClipRRect` → `BackdropFilter(blur: 20)` → `Container` 순으로 glass morphism 구현
- 반투명 배경(`#252525 70%`) + 보라 border + glow shadow
- 하트(20×20) 위에 체크 아이콘(6×4)을 `Stack`으로 우하단 오버레이 (`right: 6, top: 7`)

### 5. 날짜 선택 바텀시트 (`watchlist_date_bottom_sheet.dart`)

- Figma 기준: 헤더 56px / 피커 220px / 버튼 height 44px
- 연·월·일 `_DateWheelPicker` 3열을 `Expanded`로 동등 분할
- 각 컬럼 formatter: `'2024년'` / `'2월'` / `'14일'`
- 취소 → `_dismiss()`, 확인 → `_confirm()` 연결

### 6. 즐겨찾기 상태 동기화 (`search_controller.dart`)

- `build()`에서 `ref.listen(favoriteIdsControllerProvider, ...)` 연결
  - 하트 탭 → `favoriteIdsController` 상태 변경 → 동기 콜백 → results 재매핑
- `setQuery()` 완료 시 `ref.read(favoriteIdsControllerProvider).valueOrNull`로 초기 동기화
  - listener는 이후 변화만 감지하므로 첫 결과에는 별도 처리 필요
- `_applyFavoriteIds()`: `favoriteIds.contains(item.id)`로 각 아이템 `copyWith` 재생성
- `toggleFavorite()`: 추가 시 토스트 표시, 제거 시 `dismissToast()`

### 7. 날짜 변경 후 목록·상세 동기화 (`watchlist_screen.dart`)

- `setAsOf(selectedDate)` → `watchlistSelectedDateProvider` 갱신 후 `fetchWatchlist` 재호출
- `_syncSelectedDetailWithSnapshot()` → 확장된 detail 패널도 새 스냅샷 기준으로 갱신
- 같은 날짜 선택 시 `formatApiDate` 비교로 불필요한 재요청 차단

---

## 테스트 결과

```
flutter test  →  53 tests passed
flutter analyze  →  No issues found
```

주요 테스트 파일:

| 파일 | 내용 |
|---|---|
| `naver_stock_dtos_test.dart` | DTO 파싱 |
| `naver_watchlist_repository_test.dart` | repository mapping / 날짜 로딩 / 30거래일 상세 |
| `search_screen_test.dart` | 검색 결과 행 / 액션바 / 토스트 UI |
| `search_controller_test.dart` | favorite 상태 동기화 / toast 상태 반영 |
| `watchlist_date_bottom_sheet_test.dart` | 날짜 선택 바텀시트 UI와 선택 동작 |
| `watchlist_screen_test.dart` | 날짜 변경 후 목록/상세 동기화 |
| `search_screen_golden_test.dart` | 검색 결과·빈 상태·토스트 골든 |
| `watchlist_screen_golden_test.dart` | 관심 목록·정렬·날짜 시트 골든 |

---

## 커밋 히스토리

| 커밋 | 내용 |
|---|---|
| `f3f245d` | feat: 네이버 주식 DTO 파싱 구현 |
| `5df6d4d` | feat: 네이버 관심종목 데이터 연동 구현 |
| `985d58e` | feat: SearchResultRow Figma 기준으로 구현 |
| `d880dd1` | feat: SearchToast glass morphism 및 하트+체크 합성 구현 |
| `121db5b` | feat: 하트 즐겨찾기 상태 즉시 반영 및 체크 아이콘 위치 조정 |
| `cacdbc5` | feat: 즐겨찾기 상태 동기화 및 날짜 선택 바텀시트 구현 |

---

## 라이선스

이 저장소는 평가 목적으로만 제공됩니다.  
복사, 수정, 배포, 상업적 이용은 Edencrew의 명시적인 허가 없이 허용되지 않습니다.
