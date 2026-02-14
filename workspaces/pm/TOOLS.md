# PM_Agent TOOLS.md - 운영 메모

## Browser (Docker)
- 기본 프로필: `browserless` (remote CDP)
- 기본 주소: `http://browser:3000`
- 정상 기준: `openclaw browser profiles`에서 `browserless: running [default] [remote]`
- 주의: `chrome: running (0 tabs)`는 로컬 Chrome 프로필 상태이며, 장애 신호가 아니다.
- 원칙: 탭 Attach를 요청하지 말고 브라우저 도구로 바로 조사/열람을 진행한다.

## Search Fallback (Captcha 대응)
- 검색 엔진 UI에서 캡차가 뜨면 즉시 중단하고 `exec` 기반 검색으로 전환:
- `curl -sL "https://www.bing.com/search?format=rss&q=<query>"`
- RSS에서 링크 후보를 뽑은 뒤, 본문 확인은 `browserless`로 URL 직접 열기.
- URL 인코딩은 `node -e "console.log(encodeURIComponent('...'))"` 사용 (`python` 가정 금지).
- 사용자에게 캡차 수동 해결을 반복 요청하지 않는다.

## 장애 판단 기준
- `browserless`가 `stopped`이거나 브라우저 도구 호출이 연속 2회 실패하면 장애로 판단한다.
- 장애 보고 형식:
  - 실패한 동작
  - 에러 요약 1줄
  - 운영자에게 필요한 조치 1줄

## 경로 규칙
- PM 워크스페이스: `/home/node/.openclaw/workspaces/pm`
- 공유 산출물: `/home/node/.openclaw/shared/nexus_storage/`
