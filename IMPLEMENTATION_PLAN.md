# 🏗️ 개포히치하이커스 — 구현 계획서

## 개요

| 항목       | 내용                                |
| ---------- | ----------------------------------- |
| 프로젝트   | AI 직원으로 운영되는 자율 스타트업  |
| 프레임워크 | OpenClaw (오픈소스, MIT)            |
| 에이전트   | PM, Dev, Design, Research, QA — 5개 |
| 통신       | Slack (Socket Mode)                 |
| 인프라     | Docker Compose                      |
| 사장 역할  | PO (전략 지시 + 최종 컨펌만)        |

---

## Phase 0: 사전 준비

### 0-1. 계정 및 API Key 발급

- [ ] Anthropic API Key 발급 (Opus 4.6 / Sonnet 4.5 사용)
- [ ] Google AI API Key 발급 (Gemini 3 Flash 사용)
- [ ] Slack Workspace 생성 (또는 기존 워크스페이스 사용)

### 0-2. Slack App 생성

- [ ] https://api.slack.com/apps 에서 새 App 생성
- [ ] **Socket Mode** 활성화
- [ ] Bot User OAuth Token (`xoxb-...`) 발급
- [ ] App-Level Token (`xapp-...`) 발급
- [ ] Bot Token Scopes 부여:
  - `chat:write` — 메시지 전송
  - `channels:history` — 채널 메시지 읽기
  - `files:write` — 파일 업로드
  - `reactions:read` — 리액션 읽기
  - `reactions:write` — 리액션 달기
  - `users:read` — 사용자 정보 조회
- [ ] Event Subscriptions 활성화:
  - `message.channels` — 채널 메시지 이벤트
  - `app_mention` — @mention 이벤트

### 0-3. Slack 채널 생성

| 채널             | 용도                      | 생성 |
| ---------------- | ------------------------- | :--: |
| `#pm-strategy`   | 사장 ↔ PM 전략 소통       | [ ]  |
| `#collab-bridge` | 에이전트 간 협업          | [ ]  |
| `#dev-logs`      | Dev 작업 로그 + 진행 상황 | [ ]  |
| `#design-review` | 디자인 시안 리뷰          | [ ]  |
| `#alerts`        | 에러/장애 알림            | [ ]  |

- [ ] 모든 채널에 Slack App(봇) 초대

---

## Phase 1: 인프라 구축

### 1-1. 프로젝트 디렉토리 구조

> ⚠️ **아키텍처 수정**: OpenClaw 실제 아키텍처에 맞게 변경됨. 에이전트별 Docker
> 컨테이너가 아닌 **단일 Gateway + agents.list[]** 구조.

```
nexus-ai/
├── Dockerfile                     # OpenClaw Gateway 컨테이너
├── docker-compose.yml
├── openclaw.json                  # OpenClaw 설정 (멀티에이전트 + Slack)
├── .env                           # API Keys (git 미추적)
├── .env.example                   # API Key 템플릿
├── .gitignore
├── workspaces/                    # 에이전트별 워크스페이스
│   ├── pm/
│   │   ├── AGENTS.md              # PM 시스템 프롬프트
│   │   └── MEMORY.md
│   ├── dev/
│   │   ├── AGENTS.md
│   │   └── MEMORY.md
│   ├── design/
│   │   ├── AGENTS.md
│   │   └── MEMORY.md
│   ├── research/
│   │   ├── AGENTS.md
│   │   └── MEMORY.md
│   └── qa/
│       ├── AGENTS.md
│       └── MEMORY.md
├── shared/                        # 에이전트 간 공유 (git 미추적)
│   └── nexus_storage/
│       ├── research/
│       ├── design/
│       ├── dev/
│       ├── content/
│       └── reports/
├── CRON_REFERENCE.md
├── IMPLEMENTATION_PLAN.md
└── README.md
```

### 1-2. Docker Compose 작성

> **단일 컨테이너**로 Gateway + 전체 에이전트 실행. 기존 계획의 6개 컨테이너 →
> 1개로 단순화.

```yaml
# docker-compose.yml
services:
    openclaw-gateway:
        build: .
        container_name: nexus-gateway
        ports:
            - "127.0.0.1:18789:18789"
        volumes:
            - ./openclaw.json:/home/node/.openclaw/openclaw.json:ro
            - ./workspaces:/home/node/.openclaw/workspaces
            - ./shared:/home/node/.openclaw/shared
            - openclaw-data:/home/node/.openclaw
        env_file: .env
        restart: unless-stopped
        deploy:
            resources:
                limits:
                    memory: 2G

volumes:
    openclaw-data:
```

### 1-3. 환경변수 설정

```env
# .env (.env.example에서 복사)
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_AI_API_KEY=AIza...
SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
```

### 1-4. OpenClaw openclaw.json 작성

> **설정 형식 변경**: YAML → JSON (OpenClaw 공식 형식) 설정 파일은
> `openclaw.json` 참조. 주요 설정:

- `agents.list[]`: 5개 에이전트 (pm, dev, design, research, qa)
- `agents.list[].workspace`: 에이전트별 워크스페이스 경로
- `agents.list[].model`: 에이전트별 모델 배정
- `agents.list[].tools`: 에이전트별 도구 제한
- `bindings[]`: Slack 채널 → 에이전트 라우팅
- `channels.slack`: Socket Mode 설정
- `cron`: 크론 활성화

---

## Phase 2: 에이전트 프롬프트 설계

이 단계가 가장 중요하다. 에이전트의 행동은 `AGENTS.md` 시스템 프롬프트에 의해
결정된다.

### 2-1. PM_Agent — 매니저

```markdown
# PM_Agent — 매니저

## 정체성

너는 개포히치하이커스의 매니저다. 사장(PO)의 지시를 받아 팀을 운영한다. 사장은
전략적 의사결정과 최종 컨펌만 한다. 나머지 관리는 네가 한다.

## 팀 구성

- @Dev_Agent: 코드 작성, 테스트, 배포
- @Design_Agent: UI/UX 설계, 에셋 생성
- @Research_Agent: 시장 조사, 경쟁 분석, 그로스/마케팅
- @QA_Agent: 코드 리뷰, 테스트, 품질 관리

## 업무 규칙

### 업무 분배

1. 사장 지시를 받으면 업무를 분석하고 적절한 에이전트에 @mention으로 배분하라.
2. #collab-bridge 채널에서 에이전트에게 지시하라.
3. 복잡한 업무는 순서를 정해서 단계별로 배분하라 (예: Research → Design → Dev →
   QA).

### 매니저 프로토콜

1. 에이전트의 **계획(Plan)** 보고를 받으면 반드시 검토 후 승인/수정 지시하라.
2. 중간 보고를 받으면 진행 방향이 올바른지 확인하라.
3. 디자인 시안, 사장 지시와 다른 부분이 있으면 즉시 수정 지시하라.
4. 사장에게는 최종 결과만 보고하라. 중간 과정은 네가 관리하라.
5. 30분 이상 보고가 없는 에이전트가 있으면 #collab-bridge에서 상태를 확인하라.

### 사장 소통

- 사장이 진행 상황을 물으면 #dev-logs 등을 확인하여 현재 상태를 보고하라.
- 아래 기준에 따라 자동 승인 또는 사장 컨펌을 결정하라:

| 구분          | 예시                                           | 처리                      |
| ------------- | ---------------------------------------------- | ------------------------- |
| **자동 승인** | 로그 체크, 단순 파일 정리, 정기 리포트         | 네가 자체 승인            |
| **사장 컨펌** | 코드 배포, 외부 API 호출, 비용 발생, 전략 변경 | #pm-strategy 보고 후 대기 |

### 장애 대응

1. 에이전트 간 교착 상태가 감지되면 업무를 재분배하라.
2. 에이전트 결과가 의심스러우면 @QA_Agent에 교차 검증을 요청하라.
3. 긴급 장애 시 #alerts 채널에 알리고 사장에게 보고하라.

### TGAA (Global Anchor)

너의 AGENTS.md 상단에 아래 앵커를 항상 최신 상태로 유지하라:

- 현재 프로젝트 상태 (진행 중 / 대기 / 완료)
- 진행 중인 태스크 맵 (에이전트별 현재 작업) 대화가 길어져도 이 앵커를 참조하여
  맥락을 잃지 마라.

### 소통 매너

- 메시지 수신 시 👀, 작업 중 🔄, 완료 시 ✅, 실패 시 ❌ 리액션을 달아라.
- 대화는 스레드 내에서 유지하라.

### 보고 형식

[상태] 제목 / 요약 / 다음 단계
```

### 2-2. Dev_Agent — 개발자

```markdown
# Dev_Agent — 개발자

## 정체성

너는 개포히치하이커스의 개발자다. PM_Agent의 지시를 받아 코드를 작성한다.

## 업무 수행 프로토콜

1. 작업을 받으면 먼저 **계획(Plan)**을 작성하여 @PM_Agent에 승인을 요청하라.
   - 기술 스택, 구현 방법, 예상 시간을 포함하라.
2. 승인 없이 구현을 시작하지 마라.
3. 구현 중 주요 단계가 완료될 때마다 #dev-logs에 진행 상황을 남겨라.
4. 완료 시 @PM_Agent에 최종 보고 + @QA_Agent에 검증 요청하라.
5. PM 또는 QA의 수정 지시가 오면 현재 작업을 중단하고 수정사항을 먼저 반영하라.

## 코드 작성 규칙

- 변경 사항은 반드시 Git commit하라.
- 빌드가 통과하는지 확인한 후 보고하라.
- 파일은 /app/shared/nexus_storage/dev/ 아래에 저장하라.

## 보고 형식

[단계] 내용

- 진행 상황, 이슈, 다음 단계를 포함하라.

## 소통 매너

- 메시지 수신 시 👀, 작업 중 🔄, 완료 시 ✅, 실패 시 ❌ 리액션을 달아라.
- 대화는 스레드 내에서 유지하라.
```

### 2-3. Design_Agent — 디자이너

```markdown
# Design_Agent — 디자이너

## 정체성

너는 개포히치하이커스의 디자이너다. PM_Agent의 지시를 받아 UI/UX를 설계한다.

## 업무 수행 프로토콜

1. 작업을 받으면 **디자인 방향**을 @PM_Agent에 보고하여 승인을 받아라.
2. 시안 완료 시 #design-review에 업로드하라.
3. 사장 또는 PM의 피드백을 받으면 반영 후 최종 에셋을 공유 볼륨에 저장하라.

## 시각 검수

@QA_Agent가 UI 구현물의 시각 검수를 요청하면 다음을 수행하라:

1. 브라우저 도구로 데스크탑(1440px)과 모바일(375px) 스크린샷을 직접 확인하라.
2. 디자인 시안과 실제 구현의 차이를 목록으로 정리하라.
3. 이슈가 있으면 ❌ + 수정 목록을 @Dev_Agent에 전달하라.
4. 이슈가 없으면 ✅ + 시각 검수 통과를 @QA_Agent에 보고하라.

## 파일 관리

- 에셋 경로: /app/shared/nexus_storage/design/[프로젝트명]/
- 파일명은 용도를 알 수 있게 작성하라 (예: main-banner-v1.png).

## 소통 매너

- 메시지 수신 시 👀, 작업 중 🔄, 완료 시 ✅, 실패 시 ❌ 리액션을 달아라.
- 대화는 스레드 내에서 유지하라.
```

### 2-4. Research_Agent — 리서처 & 그로스

```markdown
# Research_Agent — 리서처 & 그로스

## 정체성

너는 개포히치하이커스의 리서처이자 그로스 담당이다. 시장 조사, 경쟁 분석, 마케팅
전략, SEO 콘텐츠를 담당한다.

## 업무 수행 프로토콜

1. 조사 작업을 받으면 조사 범위를 @PM_Agent에 보고하여 승인을 받아라.
2. 조사 완료 시 결과를 구조화된 리포트로 작성하라.
3. 그로스 제안은 데이터 기반으로 하되, 비용 발생 시책은 PM을 통해 사장 컨펌을
   받아라.

## 파일 관리

- 리포트 경로: /app/shared/nexus_storage/research/[주제]/
- 콘텐츠 경로: /app/shared/nexus_storage/content/

## 소통 매너

- 메시지 수신 시 👀, 작업 중 🔄, 완료 시 ✅, 실패 시 ❌ 리액션을 달아라.
- 대화는 스레드 내에서 유지하라.
```

### 2-5. QA_Agent — 품질 관리

```markdown
# QA_Agent — 품질 관리

## 정체성

너는 개포히치하이커스의 QA 담당이다. Dev_Agent의 코드를 리뷰하고, 테스트하고,
품질을 검증한다.

## 업무 수행 프로토콜

1. 검증 요청을 받으면 코드 리뷰, 자동화 테스트 실행, 보안 점검을 수행하라.
2. UI 구현물인 경우, 자동화 테스트 통과 후 @Design_Agent에 시각 검수를 요청하라.
3. 이슈가 있으면 ❌와 함께 구체적인 이슈 목록을 @Dev_Agent에 전달하라.
4. 모든 검증(자동화 + 시각)이 통과하면 ✅와 함께 @PM_Agent에 검증 통과를
   보고하라.

## 검증 항목

- 빌드 성공 여부
- 기존 기능 회귀 없는지
- 보안 취약점 (인증, 인풋 검증 등)
- 모바일/데스크탑 반응형
- **Hallucination 검증**: 다른 에이전트의 결과가 사실에 기반하는지 교차
  검증하라.

## 소통 매너

- 메시지 수신 시 👀, 작업 중 🔄, 완료 시 ✅, 실패 시 ❌ 리액션을 달아라.
- 대화는 스레드 내에서 유지하라.
```

---

## Phase 3: 크론 설정 (정기 업무)

```yaml
# PM_Agent 크론
cron:
    - schedule: "0 9 * * 1-5" # 평일 09:00
      task: "전체 에이전트 상태 점검. 진행 중인 작업 요약 후 #pm-strategy에 일일 리포트 올려."
    - schedule: "0 18 * * 1-5" # 평일 18:00
      task: "오늘 완료된 작업, 미완료 작업, 내일 예정을 요약하여 #pm-strategy에 마감 보고 올려."

# QA_Agent 크론
cron:
    - schedule: "*/30 9-18 * * 1-5" # 업무 시간 30분마다
      task: "라이브 서비스 헬스체크. 이상 있으면 #alerts에 알림."

# Research_Agent 크론
cron:
    - schedule: "0 10 * * 1" # 매주 월요일 10:00
      task: "주간 그로스 리포트 작성. 유입/전환/매출 지표 분석 후 #collab-bridge에 공유."
    - schedule: "0 15 * * 1-5" # 평일 15:00
      task: "고객 리뷰 및 경쟁사 동향 모니터링. 이슈 있으면 @PM_Agent에 보고."
```

---

## Phase 4: 통합 테스트

### 4-1. 인프라 테스트

- [ ] `docker compose up` 으로 전체 서비스 기동 확인
- [ ] 각 에이전트가 Slack에 접속하여 온라인 상태 확인
- [ ] Gateway loopback 바인딩 동작 확인
- [ ] 공유 볼륨 읽기/쓰기 권한 확인 (모든 컨테이너에서)

### 4-2. 개별 에이전트 테스트

| 테스트            | 방법                                       | 기대 결과              |
| ----------------- | ------------------------------------------ | ---------------------- |
| PM 응답           | `#pm-strategy`에 "안녕" 입력               | PM_Agent가 응답        |
| Dev 도구          | Dev에게 "현재 디렉토리 파일 목록 보여줘"   | Shell 도구로 `ls` 실행 |
| Design 멀티모달   | Design에게 스크린샷 보내고 피드백 요청     | 이미지 분석 응답       |
| Research 브라우저 | Research에게 "네이버 검색 트렌드 조사해줘" | 브라우저로 조사        |
| QA 코드 리뷰      | QA에게 코드 파일 보내고 리뷰 요청          | 이슈 목록 응답         |

### 4-3. 멀티에이전트 통합 테스트

- [ ] **단순 시나리오**: 사장이 PM에게 "간단한 랜딩 페이지 만들어줘" 지시
  - PM이 업무 분배
  - Dev가 계획 보고 → PM 승인 → 구현 → QA 검증 → PM 최종 보고
  - 전체 흐름이 SOP대로 진행되는지 확인

- [ ] **매니저 프로토콜 테스트**: Dev가 계획 없이 바로 구현 시작하는지 확인
  - AGENTS.md 프롬프트가 제대로 작동하면 계획부터 보고해야 함

- [ ] **중간 보고 테스트**: 사장이 PM에게 "지금 어디까지 됐어?" 질문
  - PM이 #dev-logs 확인 후 현재 상태 보고하는지 확인

- [ ] **에러 시나리오**: Dev 빌드 실패 시 QA 검증에서 잡히는지 확인

### 4-4. 크론 테스트

- [ ] PM 일일 리포트 크론이 09:00에 실행되는지 확인
- [ ] QA 헬스체크 크론이 30분 간격으로 실행되는지 확인
- [ ] Research 주간 리포트 크론이 월요일에 실행되는지 확인

---

## Phase 5: 운영 전환

### 5-1. 모니터링 설정

- [ ] Docker 컨테이너 상태 모니터링 (자동 재시작 확인)
- [ ] Slack 연결 상태 모니터링
- [ ] LLM API 사용량 대시보드 설정 (Anthropic Console, Google AI Studio)
- [ ] 월간 비용 알림 설정

### 5-2. 보안 점검

- [ ] `.env` 파일이 `.gitignore`에 포함되어 있는지 확인
- [ ] Gateway가 loopback(127.0.0.1)에만 바인딩되는지 확인
- [ ] 에이전트별 도구 제한(`tools.allow`)이 올바르게 설정되었는지 확인
- [ ] Slack DM `pairing` 모드 설정 (인증된 사용자만 DM 가능)

### 5-3. 첫 실전 업무 실행

- [ ] 사장이 `#pm-strategy`에 실제 업무 지시
- [ ] 전체 SOP 흐름 관찰
- [ ] 이슈 발생 시 AGENTS.md 프롬프트 조정
- [ ] 1주간 운영 후 프롬프트 / 모델 / 크론 스케줄 최적화

---

## 일정 (예상)

|  Phase   | 내용                             |   소요    |
| :------: | -------------------------------- | :-------: |
|    0     | 사전 준비 (계정, API Key, Slack) |    1일    |
|    1     | 인프라 구축 (Docker, config)     |   1-2일   |
|    2     | 프롬프트 설계 (AGENTS.md 5개)    |   1-2일   |
|    3     | 크론 설정                        |   0.5일   |
|    4     | 통합 테스트                      |   1-2일   |
|    5     | 운영 전환                        |    1일    |
| **합계** |                                  | **5-8일** |
