# 🏢 개포히치하이커스: AI 직원으로 운영되는 자율 스타트업

## 프로젝트 비전

사람이 하는 업무를 AI 에이전트가 그대로 수행하는 **자율 운영 스타트업**을
구축한다. 각 에이전트는 실제 스타트업의 직원처럼 자기 역할을 갖고, 슬랙에서
소통하며, 직접 파일을 만들고, 보고서를 올리고, 코드를 작성한다. 사장(인간)은
전략적 의사결정과 최종 컨펌만 담당한다.

---

## 0. 왜 OpenClaw인가?

### 자율 에이전트가 필요한 이유

일반적인 LLM API 호출이나 챗봇은 **"질문하면 답하는"** 수동적 도구다. 하지만
실제 직원은 다르게 행동한다:

| 실제 직원의 행동                               | 필요한 AI 능력                      |
| ---------------------------------------------- | ----------------------------------- |
| 슬랙 메시지를 보고 스스로 판단하여 업무 착수   | 메시징 플랫폼 상시 연결 + 자율 판단 |
| 파일을 열어보고, 수정하고, 저장함              | 로컬 파일시스템 접근 + 쉘 실행      |
| 필요하면 브라우저로 조사하고 자료를 정리함     | 브라우저 제어 + 정보 수집           |
| 동료에게 @멘션으로 업무를 넘기고 결과를 기다림 | 에이전트 간 비동기 통신             |
| 어제 맥락을 기억하고 오늘 이어서 작업함        | 영속적 메모리 + 세션 관리           |
| 퇴근 후에도 크론 작업이 돌아감                 | 백그라운드 스케줄링                 |

**이 모든 것을 하나의 프레임워크에서 제공하는 것이 OpenClaw이다.**

### OpenClaw 선택 근거

- **Local-first 아키텍처**: 자체 인프라에서 실행. 데이터 주권 보장, 외부 SaaS
  종속 없음.
- **멀티채널 네이티브**: Slack, Discord, Telegram 등 15개+ 메시징 플랫폼 내장
  지원. 별도 어댑터 개발 불필요.
- **멀티에이전트 라우팅**: 단일 Gateway가 `agents.list[]`와 `bindings[]`로
  채널별 에이전트에 메시지를 자동 라우팅. 에이전트별 모델, 도구, 워크스페이스
  분리 가능.
- **1급 도구 시스템**: 브라우저 제어, 쉘 실행, 파일 관리, 크론, 웹훅이 내장.
  Skills 플랫폼으로 확장 가능.
- **모델 Failover**: Primary → Fallback 자동 전환. 특정 LLM 벤더에 종속되지
  않음.
- **오픈소스 (MIT)**: 145,000+ GitHub Stars. 활발한 커뮤니티와 515명+ 기여자.

---

## 1. 아키텍처

### Docker 구성

```
┌────────────────────────────────────────────┐
│  nexus-gateway (2GB)                       │
│  - OpenClaw Gateway (단일 프로세스)        │
│  - 8개 에이전트 세션 (비동기 동시 실행)    │
│  - Slack Socket Mode 연결                  │
├────────────────────────────────────────────┤
│           ws://browser:3000                │
├────────────────────────────────────────────┤
│  nexus-browser (1GB)                       │
│  - browserless/chrome                      │
│  - 동시 세션 5개                           │
└────────────────────────────────────────────┘
```

- **단일 Gateway**: OpenClaw 1개 프로세스가 8개 에이전트를 비동기 I/O로 동시
  관리
- **브라우저 컨테이너**: Chromium을 별도 격리하여 Gateway 안정성 확보
- **설정**: `openclaw.json` (JSON5)으로 에이전트, 모델, Slack 라우팅 통합 관리

### 디렉토리 구조

```
nexus-ai/
├── Dockerfile                     # OpenClaw Gateway 컨테이너
├── docker-compose.yml             # Gateway + Browser
├── openclaw.json                  # 멀티에이전트 + Slack + 모델 설정
├── setup.sh                       # 미니PC 초기 셋업 (1회 실행)
├── .env / .env.example            # API 키 & Slack 토큰
├── workspaces/                    # 에이전트별 워크스페이스
│   ├── pm/AGENTS.md               # PM 시스템 프롬프트 + MEMORY.md
│   ├── frontend/AGENTS.md
│   ├── backend/AGENTS.md
│   ├── devops/AGENTS.md
│   ├── security/AGENTS.md
│   ├── design/AGENTS.md
│   ├── research/AGENTS.md
│   └── qa/AGENTS.md
├── shared/nexus_storage/          # 에이전트 간 공유 (git 미추적)
├── IMPLEMENTATION_PLAN.md
└── README.md
```

---

## 2. 에이전트 팀 구성 (8명)

| 에이전트              | 역할                             | 모델           | 주요 도구                      |
| --------------------- | -------------------------------- | -------------- | ------------------------------ |
| **🎯 PM_Agent**       | 전략 수립, 업무 분배, 상태 관리  | Opus 4.6       | Slack 관리, TGAA 앵커 업데이트 |
| **🖥️ Frontend_Agent** | UI 구현, 반응형, 클라이언트 로직 | Gemini 3 Flash | Browser, Shell, File I/O       |
| **⚙️ Backend_Agent**  | API, DB, 서버 사이드 로직        | Opus 4.6       | Shell, File I/O                |
| **🚀 DevOps_Agent**   | 인프라, CI/CD, 배포, 모니터링    | Sonnet 4.5     | Shell, File I/O                |
| **🔒 Security_Agent** | 보안 리뷰, 취약점 점검           | Sonnet 4.5     | Shell, File I/O                |
| **🎨 Design_Agent**   | UI/UX 설계, 에셋 생성            | Gemini 3 Flash | Browser, File I/O              |
| **🔍 Research_Agent** | 시장 조사, 경쟁 분석, 그로스     | Gemini 3 Flash | Browser, File I/O              |
| **✅ QA_Agent**       | 코드 리뷰, 테스트, 품질 관리     | Sonnet 4.5     | Shell, File I/O                |

### 모델 배정 전략

- **Opus 4.6**: 복잡한 추론이 필요한 역할 (PM, Backend)
- **Gemini 3 Flash**: 멀티모달/패턴 기반 작업 (Frontend, Design, Research)
- **Sonnet 4.5**: 체크리스트/패턴 매칭 작업 (DevOps, Security, QA)
- **테스트 단계**: Antigravity OAuth로 API 키 없이 전 모델 무료 사용

---

## 3. Slack 채널 아키텍처

| 채널             | 용도                         | 바인딩 에이전트 | requireMention |
| ---------------- | ---------------------------- | --------------- | -------------- |
| `#pm-strategy`   | 사장 ↔ PM 전략 소통          | PM_Agent        | ❌             |
| `#collab-bridge` | 에이전트 간 @mention 협업    | PM_Agent (기본) | ✅             |
| `#dev-logs`      | 개발 로그, 빌드/배포 상태    | Frontend_Agent  | ✅             |
| `#design-review` | 디자인 시안 업로드 및 피드백 | Design_Agent    | ✅             |
| `#alerts`        | 긴급 장애/에러 알림          | PM_Agent        | ❌             |

- 전용 채널: 바인딩된 에이전트가 모든 메시지 수신
- 공유 채널 (`requireMention: true`): @mention된 에이전트만 응답

### 에이전트 소통 매너

- **Reaction**: 수신 👀 → 작업 중 🔄 → 완료 ✅ / 실패 ❌
- **Thread Context**: 스레드 내 대화만 컨텍스트로 묶어 토큰 소모 방지
- **구조화된 보고**: `[상태] 제목 / 요약 / 다음 단계` 형식

---

## 4. 토큰 최적화

### A. Session Pruning — OpenClaw 내장

Anthropic 프롬프트 캐시 TTL과 연동하여, 캐시 만료 후 불필요한 도구 결과를
자동으로 잘라낸다.

### B. Memory Compaction — OpenClaw 내장

| 단계                  | 동작                                              | 효과                    |
| --------------------- | ------------------------------------------------- | ----------------------- |
| Memory Flush          | 컨텍스트 한계 전, 핵심 사실을 `MEMORY.md`에 기록  | 중요 정보 영속화        |
| Compaction            | ~40,000 토큰 도달 시 전체 세션을 요약 파일로 압축 | 컨텍스트 윈도우 초기화  |
| Session Memory Search | 과거 세션 데이터를 시맨틱 쿼리                    | 필요한 맥락만 정밀 복원 |

### C. Context Slimming — 커스텀 전략

- `AGENTS.md`, `MEMORY.md` 파일을 최소한으로 유지 → 입력 토큰 절감
- `qmd`를 통한 정밀 지식 검색 → 조회당 토큰 90% 절감

### D. TGAA (Tiered Global Anchor Architecture)

- 모든 에이전트의 `AGENTS.md` 상단에 고정된 **Global Anchor** 배치
- 현재 프로젝트 상태, 팀 구성원 목록, 진행 중인 태스크 맵 유지

---

## 5. 표준 운영 절차 (SOP)

```
사장 지시                  PM_Agent                     작업 에이전트
   │                         │                              │
   ├── #pm-strategy 지시 ──▶ │                              │
   │                         ├── TGAA 앵커 업데이트          │
   │                         ├── 업무 분석 및 분배           │
   │                         ├── #collab-bridge @mention ──▶ │
   │                         │                              ├── 👀 수신 확인
   │                         │                              ├── 🔄 작업 수행
   │                         │                              ├── ✅ 완료
   │                         │   ◀── 결과 보고 ─────────────┤
   │                         ├── 결과 검증 (→ QA)           │
   │   ◀── 컨펌 요청 ───────┤                              │
   ├── 승인/수정 ───────────▶ │                              │
```

### 자동 승인 vs 사장 컨펌

| 구분               | 예시                                                | 처리                          |
| ------------------ | --------------------------------------------------- | ----------------------------- |
| **자동 승인**      | 로그 체크, 단순 파일 정리, 정기 리포트              | PM_Agent가 자체 승인          |
| **사장 컨펌 필수** | 코드 배포, 외부 API 호출, 비용 발생 작업, 전략 변경 | `#pm-strategy`에 보고 후 대기 |

---

## 6. 에러 핸들링 및 보안

### 장애 대응

| 시나리오                   | 감지                                 | 대응                            |
| -------------------------- | ------------------------------------ | ------------------------------- |
| **에이전트 Hallucination** | QA_Agent 교차 검증                   | 결과 폐기 후 재작업 지시        |
| **무한 루프**              | 크론 하트비트로 응답 시간 모니터링   | 세션 강제 종료 + `#alerts` 알림 |
| **에이전트 간 교착 상태**  | PM_Agent가 대기 시간 임계값 모니터링 | 교착 해제 + 업무 재분배         |
| **LLM API 장애**           | Model Failover 자동 작동             | Primary → Fallback 모델 전환    |

### 보안 정책

- **Docker 격리**: Gateway + Browser 컨테이너로 호스트 직접 접근 불가
- **Slack DM 정책**: `pairing` 모드 — 인증된 사용자만 DM 가능
- **Gateway 바인딩**: `127.0.0.1:18789` loopback 전용

---

## 7. 빠른 시작

### 사전 조건

- Docker + Docker Compose 설치
- Slack App 생성 (Socket Mode, Bot Token + App Token)
- Git

### 배포

```bash
git clone git@github.com:kosuha/nexus-ai.git
cd nexus-ai
./setup.sh    # Docker 빌드 + 온보딩(Antigravity OAuth) + Gateway 기동
```

### Slack 토큰 설정

```bash
nano .env
# SLACK_BOT_TOKEN=xoxb-...
# SLACK_APP_TOKEN=xapp-...
docker compose restart
```

---

## 부록: 기술 스택

| 구성요소        | 기술                                            | 비고                      |
| --------------- | ----------------------------------------------- | ------------------------- |
| 에이전트 런타임 | OpenClaw (MIT, `github.com/openclaw/openclaw`)  | v최신                     |
| Gateway         | OpenClaw Gateway (단일 프로세스)                | loopback 바인딩           |
| 통신 채널       | Slack (Socket Mode)                             | 비공개 채널 5개           |
| 브라우저        | browserless/chrome (별도 컨테이너)              | 동시 세션 5개             |
| 컨테이너화      | Docker + Docker Compose                         | Gateway 2GB + Browser 1GB |
| 파일 공유       | 공유 볼륨 `/home/node/.openclaw/shared/`        | —                         |
| LLM 인증        | Antigravity OAuth (테스트) / API Key (프로덕션) | —                         |
