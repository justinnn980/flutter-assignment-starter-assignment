# 구현 내용

## 1. 네이버 주식 DTO 파싱

검색 자동완성, 실시간 시세, 종목 메타데이터, 일별 시세 `fromJson` 구현

- 숫자: 쉼표 제거 후 파싱
- 날짜: `yyyy.MM.dd` → `DateTime`, 내부는 `yyyyMMdd`로 정규화
- 파싱만 담당, 비즈니스 규칙은 repository에서 처리

## 2. 네이버 관심종목 데이터 연동

**클라이언트** (`naver_domestic_stock_client.dart`)

- 검색 자동완성: 국내 6자리 종목코드만 통과
- 실시간 시세: `SERVICE_ITEM:{symbol}` 쿼리
- 종목 메타데이터: 이름·거래소명 조회
- 일별 시세 HTML 파싱: `lastPage` 추출

**레포지토리** (`naver_watchlist_repository.dart`)

- canonical id: `domestic:{symbol}` 형태
- 최신 거래일 realtime 우선, 과거 날짜는 historical 기준
- 거래일 목록 lazy load·캐싱
- 선택 날짜 기준 직전 30거래일 window로 상세 차트 구성

## 3. 검색 결과 행

- 종목명·서브텍스트를 `RichText` 2개로 구성
- `splitSearchTextParts()`로 검색어 매칭 구간 `#B980FF` 하이라이트
- 하트 슬롯 24×24 → 20×20 (Figma 기준)
- 선택 시 `SearchActionBar` (뉴스 / 종목토론) 표시, 상하 8px 간격

## 4. 검색 토스트

- `ClipRRect` → `BackdropFilter(blur: 20)` → `Container`로 glass morphism 구현
- 반투명 배경 + 보라 border + glow shadow
- 하트(20×20) 위에 체크(6×4)를 `Stack`으로 우하단 오버레이 (`right: 6, top: 7`)

## 5. 날짜 선택 바텀시트

- 헤더 56px / 피커 220px / 버튼 44px (Figma 기준)
- 연·월·일 `_DateWheelPicker` 3열을 `Expanded`로 동등 분할
- 취소 → `_dismiss()`, 확인 → `_confirm()` 연결

## 6. 즐겨찾기 상태 동기화

- `build()`에서 `ref.listen(favoriteIdsControllerProvider, ...)` 연결 → 하트 탭 시 results 즉시 재매핑
- `setQuery()` 완료 시 `ref.read`로 초기 favoriteIds 적용 (listener는 이후 변화만 감지)
- `toggleFavorite()`: 추가 시 토스트 표시, 제거 시 `dismissToast()`

## 7. 날짜 변경 후 목록·상세 동기화

- `setAsOf()` → `watchlistSelectedDateProvider` 갱신 후 `fetchWatchlist` 재호출
- `_syncSelectedDetailWithSnapshot()` → detail 패널도 새 스냅샷 기준으로 갱신
- 같은 날짜 선택 시 `formatApiDate` 비교로 불필요한 재요청 차단

---

## 테스트 결과

```
flutter test    → 53 tests passed
flutter analyze → No issues found
```
