# 🏗️ 개포히치하이커스 — 구현 계획서

## 개요

| 항목       | 내용                                                                |
| ---------- | ------------------------------------------------------------------- |
| 프로젝트   | AI 직원으로 운영되는 자율 스타트업                                  |
| 프레임워크 | OpenClaw (오픈소스, MIT)                                            |
| 에이전트   | 8개 (PM, Frontend, Backend, DevOps, Security, Design, Research, QA) |
| 통신       | Discord Bot API × 8 (에이전트당 독립 봇)                            |
| 소통 방식  | Discord @mention (순수 Discord, 내부 도구 없음)                     |
| 인프라     | Docker Compose                                                      |
| 사장 역할  | PO (전략 지시 + 최종 컨펌만)                                        |

---

## Phase 0: 사전 준비

### 0-1. 계정 및 API Key 발급

- [ ] Anthropic API Key 발급 (Sonnet 4.5 사용)
- [ ] Google AI API Key 발급 (Gemini 3 Pro 사용)
- [ ] Discord 서버 생성

### 0-2. Discord Bot App 8개 생성

[Discord Developer Portal](https://discord.com/developers/applications)에서
에이전트당 1개 Application 생성:

| # | Application 이름 | 봇 이름  | 생성 |
| - | ---------------- | -------- | :--: |
| 1 | Nexus-PM         | PM       | [ ]  |
| 2 | Nexus-Frontend   | Frontend | [ ]  |
| 3 | Nexus-Backend    | Backend  | [ ]  |
| 4 | Nexus-DevOps     | DevOps   | [ ]  |
| 5 | Nexus-Security   | Security | [ ]  |
| 6 | Nexus-Design     | Design   | [ ]  |
| 7 | Nexus-Research   | Research | [ ]  |
| 8 | Nexus-QA         | QA       | [ ]  |

각 앱에서:

- [ ] **Bot** → Add Bot → **Token 복사** → `.env`에 저장
- [ ] **Privileged Gateway Intents** 활성화:
  - ✅ Message Content Intent (필수)
  - ✅ Server Members Intent (권장)
- [ ] **OAuth2** URL Generator:
  - scopes: `bot`, `applications.commands`
  - permissions: View Channels, Send Messages, Read Message History, Embed
    Links, Attach Files, Add Reactions
- [ ] 생성된 OAuth2 URL로 **같은** Discord 서버에 봇 초대

### 0-3. Discord 채널 생성

| 채널             | 용도                  | 참여 봇                           | 생성 |
| ---------------- | --------------------- | --------------------------------- | :--: |
| `#pm-strategy`   | 사장 ↔ PM 전략 소통   | PM만                              | [ ]  |
| `#collab-bridge` | 에이전트 간 협업      | 전원 (8개)                        | [ ]  |
| `#dev-log`       | 개발 로그 + 기술 논의 | PM, Frontend, Backend, DevOps, QA | [ ]  |
| `#design-review` | 디자인 시안 리뷰      | PM, Design, Frontend              | [ ]  |
| `#alert`         | 에러/장애 알림        | 전원                              | [ ]  |

- [ ] 각 채널에 해당 봇만 초대 (채널 권한으로 관리)
- [ ] 각 채널의 **Channel ID** 복사 (개발자 모드 → 우클릭 → Copy Channel ID)
- [ ] **Guild(서버) ID** 복사 (서버명 우클릭 → Copy Server ID)

### 0-4. openclaw.json에 실제 ID 입력

`openclaw.json`의 다음 플레이스홀더를 실제 ID로 교체:

| 플레이스홀더               | 교체할 값              |
| -------------------------- | ---------------------- |
| `GUILD_ID`                 | Discord 서버 ID        |
| `PM_STRATEGY_CHANNEL_ID`   | #pm-strategy 채널 ID   |
| `COLLAB_BRIDGE_CHANNEL_ID` | #collab-bridge 채널 ID |
| `DEV_LOG_CHANNEL_ID`       | #dev-log 채널 ID       |
| `DESIGN_REVIEW_CHANNEL_ID` | #design-review 채널 ID |
| `ALERT_CHANNEL_ID`         | #alert 채널 ID         |

---

## Phase 1: 인프라 구축

### 1-1. 환경변수 설정

```env
# .env
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_AI_API_KEY=AIza...

# Discord Bot Tokens (8개)
DISCORD_BOT_TOKEN_PM=...
DISCORD_BOT_TOKEN_FRONTEND=...
DISCORD_BOT_TOKEN_BACKEND=...
DISCORD_BOT_TOKEN_DEVOPS=...
DISCORD_BOT_TOKEN_SECURITY=...
DISCORD_BOT_TOKEN_DESIGN=...
DISCORD_BOT_TOKEN_RESEARCH=...
DISCORD_BOT_TOKEN_QA=...
```

### 1-2. Docker Compose

기존 `docker-compose.yml` 사용. Gateway 1개 + Browser 1개.

### 1-3. openclaw.json 핵심 설정

- `channels.discord.accounts`: 8개 봇 계정
- `bindings`: `accountId`로 에이전트 ↔ 봇 1:1 매핑
- `allowBots: true`: 봇 간 메시지 수신 (에이전트 간 Discord 소통의 핵심)
- `guilds.*.channels.*`: 채널별 접근 제어
- `requireMention: true`: 기본적으로 @mention 시에만 응답
- `agentToAgent: false`: 내부 세션 간 통신 비활성화 (Discord로만 소통)

---

## Phase 2: 에이전트 프롬프트 설계

### 핵심 원칙

1. **순수 Discord 소통**: `sessions_spawn`/`sessions_send` 사용 안 함
2. **@mention = 유일한 소통 수단**: 에이전트 간 소통은 Discord @mention
3. **독립된 봇 아이덴티티**: 각 에이전트가 자기 이름과 아바타로 Discord에 게시
4. **채널 활용**: 적절한 채널에서 소통 (#collab-bridge, #dev-log 등)

### 에이전트별 소통 매트릭스

| 발신 ↓ \ 수신 → | PM | Frontend | Backend | DevOps | Security | Design | Research | QA |
| --------------- | -- | -------- | ------- | ------ | -------- | ------ | -------- | -- |
| **PM**          | —  | ✅       | ✅      | ✅     | ✅       | ✅     | ✅       | ✅ |
| **Frontend**    | ✅ | —        | ✅      |        |          | ✅     |          | ✅ |
| **Backend**     | ✅ | ✅       | —       | ✅     | ✅       |        |          | ✅ |
| **DevOps**      | ✅ |          | ✅      | —      | ✅       |        |          |    |
| **Security**    | ✅ |          | ✅      | ✅     | —        |        |          |    |
| **Design**      | ✅ | ✅       |         |        |          | —      |          | ✅ |
| **Research**    | ✅ |          | ✅      |        |          | ✅     | —        |    |
| **QA**          | ✅ | ✅       | ✅      | ✅     | ✅       | ✅     |          | —  |

---

## Phase 3: 크론 설정

```yaml
# PM 크론
- schedule: "0 9 * * 1-5"
  task: "전체 에이전트 상태 점검. #pm-strategy에 일일 리포트."
- schedule: "0 18 * * 1-5"
  task: "오늘 완료/미완료 작업 요약. #pm-strategy에 마감 보고."

# QA 크론
- schedule: "*/30 9-18 * * 1-5"
  task: "라이브 서비스 헬스체크. 이상 시 #alert에 알림."

# Research 크론
- schedule: "0 10 * * 1"
  task: "주간 그로스 리포트. #collab-bridge에 공유."
- schedule: "0 15 * * 1-5"
  task: "고객 리뷰/경쟁사 동향 모니터링. 이슈 시 @PM 보고."
```

---

## Phase 4: 통합 테스트

### 4-1. 인프라 테스트

- [ ] `docker compose up` 전체 서비스 기동
- [ ] 8개 봇 모두 Discord에서 온라인 상태 확인
- [ ] Gateway loopback 바인딩 동작 확인

### 4-2. 개별 봇 테스트

| 테스트   | 방법                                   | 기대 결과          |
| -------- | -------------------------------------- | ------------------ |
| PM 응답  | #pm-strategy에 "안녕" 입력             | PM 봇이 응답       |
| Frontend | #collab-bridge에 "@Frontend 안녕" 입력 | Frontend 봇이 응답 |
| Backend  | #collab-bridge에 "@Backend 안녕" 입력  | Backend 봇이 응답  |
| Design   | #design-review에 "@Design 안녕" 입력   | Design 봇이 응답   |
| Research | #collab-bridge에 "@Research 안녕" 입력 | Research 봇이 응답 |
| QA       | #collab-bridge에 "@QA 안녕" 입력       | QA 봇이 응답       |

### 4-3. 봇 간 소통 테스트

- [ ] #collab-bridge에서 PM 봇이 "@Frontend 테스트 작업" 메시지 → Frontend 봇이
      수신하여 응답하는지 확인 (`allowBots: true` 동작 검증)
- [ ] Frontend 봇이 "@Backend API 필요" → Backend 봇이 응답하는지 확인
- [ ] 봇 A → 봇 B → 봇 A 연쇄 소통이 무한 루프 없이 정상 동작하는지 확인

### 4-4. 전체 시나리오 테스트

- [ ] 사장이 #pm-strategy에 "랜딩 페이지 만들어줘" 지시
  - PM → @Design → @Frontend → @QA → PM 보고
  - 전체 흐름이 Discord 채널에서 가시적으로 진행되는지 확인

### 4-5. 크론 테스트

- [ ] PM 일일 리포트 크론 실행 확인
- [ ] QA 헬스체크 크론 실행 확인
- [ ] Research 주간 리포트 크론 실행 확인

---

## Phase 5: 운영 전환

### 5-1. 모니터링

- [ ] Docker 컨테이너 상태 모니터링
- [ ] Discord 8개 봇 연결 상태 확인
- [ ] LLM API 사용량 대시보드

### 5-2. 보안 점검

- [ ] `.env` (8개 Bot Token) 이 `.gitignore`에 포함 확인
- [ ] Gateway loopback 바인딩 확인
- [ ] Discord DM `pairing` 모드 설정

### 5-3. 첫 실전 업무

- [ ] 사장이 #pm-strategy에 실제 업무 지시
- [ ] Discord에서 에이전트 간 자연스러운 협업 흐름 관찰
- [ ] 프롬프트 최적화 (1주간)

---

## 일정 (예상)

|  Phase   | 내용                                 |   소요    |
| :------: | ------------------------------------ | :-------: |
|    0     | 사전 준비 (API Key, Discord Bot 8개) |    1일    |
|    1     | 인프라 구축 (Docker, config)         |   1-2일   |
|    2     | 프롬프트 설계 (AGENTS.md 8개)        |   1-2일   |
|    3     | 크론 설정                            |   0.5일   |
|    4     | 통합 테스트 (봇 간 소통 포함)        |   1-2일   |
|    5     | 운영 전환                            |    1일    |
| **합계** |                                      | **5-8일** |
