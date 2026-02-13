# 🏢 개포히치하이커스: AI 직원으로 운영되는 자율 스타트업

## 프로젝트 비전

사람이 하는 업무를 AI 에이전트가 그대로 수행하는 **자율 운영 스타트업**을
구축한다. 각 에이전트는 실제 스타트업의 직원처럼 자기 역할을 갖고, **각자 독립된
Discord 봇으로** 소통하며, 직접 파일을 만들고, 보고서를 올리고, 코드를 작성한다.
사장(인간)은 전략적 의사결정과 최종 컨펌만 담당한다.

---

## 0. 왜 이 아키텍처인가?

### Discord + 에이전트당 독립 봇

| 실제 스타트업                     | 개포히치하이커스                           |
| --------------------------------- | ------------------------------------------ |
| 8명의 직원이 Discord에서 대화     | 8개의 AI 봇이 Discord에서 대화             |
| 각자 이름과 프로필 사진이 다름    | 각 봇이 독립된 이름과 아바타를 가짐        |
| @mention으로 동료에게 업무를 넘김 | @mention으로 다른 에이전트에게 업무를 넘김 |
| 사장이 팀 채팅을 보면서 지시      | 사장이 Discord 채널을 보면서 지시          |

### OpenClaw 선택 근거

- **Local-first 아키텍처**: 자체 인프라에서 실행. 데이터 주권 보장.
- **멀티에이전트 + 멀티 어카운트**: `channels.discord.accounts`로 에이전트당
  독립 Discord Bot 지원.
- **Discord 네이티브**: `allowBots`로 봇 간 메시지 수신 → 에이전트 간 직접 소통.
- **1급 도구 시스템**: 브라우저, 쉘, 파일 관리, 크론 내장.
- **모델 Failover**: Primary → Fallback 자동 전환.
- **오픈소스 (MIT)**: 145,000+ GitHub Stars.

---

## 1. 아키텍처

### Discord 서버 구조

```
개포히치하이커스 Discord 서버
├── 📂 전략
│   └── #pm-strategy          ← 사장 ↔ PM 봇
├── 📂 협업
│   └── #collab-bridge        ← 8개 봇 전원 참여, @mention으로 소통
├── 📂 개발
│   ├── #dev-log              ← PM, Frontend, Backend, DevOps, QA 봇
│   └── #design-review        ← PM, Design, Frontend 봇
└── 📂 운영
    └── #alert                ← 전원, 긴급 알림
```

### 에이전트 ↔ 봇 매핑

```
┌──────────────────────────────────────────────────────────┐
│  OpenClaw Gateway (단일 프로세스)                         │
│                                                          │
│  Agent: pm       ←→  Discord Bot: "PM"        (Token A)  │
│  Agent: frontend ←→  Discord Bot: "Frontend"  (Token B)  │
│  Agent: backend  ←→  Discord Bot: "Backend"   (Token C)  │
│  Agent: devops   ←→  Discord Bot: "DevOps"    (Token D)  │
│  Agent: security ←→  Discord Bot: "Security"  (Token E)  │
│  Agent: design   ←→  Discord Bot: "Design"    (Token F)  │
│  Agent: research ←→  Discord Bot: "Research"  (Token G)  │
│  Agent: qa       ←→  Discord Bot: "QA"        (Token H)  │
│                                                          │
│  allowBots: true → 봇끼리 @mention으로 소통 가능          │
├──────────────────────────────────────────────────────────┤
│           ws://browser:3000                              │
├──────────────────────────────────────────────────────────┤
│  nexus-browser (browserless/chrome, 1GB)                 │
└──────────────────────────────────────────────────────────┘
```

### 소통 흐름 예시

```
#collab-bridge 채널:

👤 사장:    랜딩 페이지 만들어줘

🎯 PM:     네, 진행하겠습니다.
            @Design 랜딩 페이지 시안 만들어주세요. 모던하고 깔끔한 스타일로요.

🎨 Design: 시안 완료했습니다. [이미지 첨부]
            @Frontend 이 시안 기반으로 구현 부탁합니다.

🖥️ Frontend: 작업 시작합니다. @Backend 상품 API 필요해요. 스펙 공유해주세요.

⚙️ Backend: GET /api/products 엔드포인트입니다. 응답 형식: { id, name, price, image }

🖥️ Frontend: 구현 완료했습니다. https://localhost:3000
            @QA 검증 부탁합니다.

✅ QA:     검증 완료 ✅ 이슈 없습니다. @PM 보고드립니다.

🎯 PM:     사장님, 랜딩 페이지 완료되었습니다. 확인 부탁드립니다.
```

**각 메시지가 서로 다른 봇에서 오기 때문에, 진짜 팀원들이 대화하는 것처럼
보입니다.**

### 디렉토리 구조

```
nexus-ai/
├── Dockerfile
├── docker-compose.yml
├── openclaw.json                  # 8개 봇 + Discord 설정
├── .env / .env.example            # 서버/채널 ID + 8개 Bot Token + Gateway Token
├── workspaces/                    # 에이전트별 워크스페이스
│   ├── pm/AGENTS.md
│   ├── frontend/AGENTS.md
│   ├── backend/AGENTS.md
│   ├── devops/AGENTS.md
│   ├── security/AGENTS.md
│   ├── design/AGENTS.md
│   ├── research/AGENTS.md
│   └── qa/AGENTS.md
├── shared/nexus_storage/          # 에이전트 간 공유 파일
└── README.md
```

---

## 2. 에이전트 팀 구성 (8명 = 8개 봇)

| Discord 봇      | 역할                            | 모델          | 주요 도구      |
| --------------- | ------------------------------- | ------------- | -------------- |
| **🎯 PM**       | 전략 수립, 업무 분배, 상태 관리 | o3            | Shell, Browser |
| **🖥️ Frontend** | UI 구현, 반응형, 클라이언트     | gpt-5.1-codex | Shell, Browser |
| **⚙️ Backend**  | API, DB, 서버 사이드            | o3            | Shell          |
| **🚀 DevOps**   | 인프라, CI/CD, 배포             | o4-mini       | Shell          |
| **🔒 Security** | 보안 리뷰, 취약점 점검          | o3            | Shell          |
| **🎨 Design**   | UI/UX 설계, 에셋 생성           | gpt-5.1-codex | Browser        |
| **🔍 Research** | 시장 조사, 경쟁 분석            | gpt-5-mini    | Browser        |
| **✅ QA**       | 코드 리뷰, 테스트, 품질         | o4-mini       | Shell          |

---

## 3. Discord 채널 구조

| 채널             | 용도                       | 참여 봇                           | requireMention |
| ---------------- | -------------------------- | --------------------------------- | -------------- |
| `#pm-strategy`   | 사장 ↔ PM 전략 소통        | PM만                              | ❌             |
| `#collab-bridge` | 에이전트 간 협업, @mention | 전원(8개)                         | ✅             |
| `#dev-log`       | 개발 로그, 기술 논의       | PM, Frontend, Backend, DevOps, QA | ✅             |
| `#design-review` | 디자인 시안 리뷰           | PM, Design, Frontend              | ✅             |
| `#alert`         | 긴급 장애/에러 알림        | 전원                              | ❌             |

- **requireMention ✅**: 해당 봇이 @mention될 때만 응답
- **requireMention ❌**: 채널의 모든 메시지에 응답 (PM 전용 채널 등)
- **allowBots**: 봇이 보낸 메시지도 다른 봇이 수신 → 에이전트 간 직접 소통

---

## 4. 표준 운영 절차 (SOP)

```
사장 (#pm-strategy)          PM 봇                    다른 에이전트 봇들
        │                      │                           │
        ├── "랜딩페이지 만들어" ▶ │                           │
        │                      ├── #collab-bridge에          │
        │                      │   @Design 시안 요청 ──────▶ │
        │                      │                           ├── 🎨 시안 작업
        │                      │                           ├── @Frontend 구현 요청 ──▶
        │                      │                           │                         │
        │                      │                           │   ◀── @Backend API 요청 ─┤
        │                      │                           │   API 응답 ──────────────▶
        │                      │                           │                         │
        │                      │                           │   ◀── @QA 검증 요청 ────┤
        │                      │                           ├── ✅ 검증 통과
        │                      │                           ├── @PM 검증 통과 보고
        │                      │   ◀── 결과 수신 ──────────┤
        │   ◀── 완료 보고 ─────┤                           │
```

**핵심: 모든 소통이 Discord 채널에서 @mention으로 이루어진다. 숨겨진 내부 통신
없음.**

---

## 5. 빠른 시작

### 사전 조건

- Docker + Docker Compose
- Git
- Discord 서버

### 1단계: Discord Bot 8개 생성

[Discord Developer Portal](https://discord.com/developers/applications)에서
**8개 Application**을 생성한다:

| Application 이름 | 봇 이름  | 용도        |
| ---------------- | -------- | ----------- |
| Nexus-PM         | PM       | 매니저      |
| Nexus-Frontend   | Frontend | 프론트엔드  |
| Nexus-Backend    | Backend  | 백엔드      |
| Nexus-DevOps     | DevOps   | 인프라/배포 |
| Nexus-Security   | Security | 보안        |
| Nexus-Design     | Design   | 디자인      |
| Nexus-Research   | Research | 리서치      |
| Nexus-QA         | QA       | 품질 관리   |

각 앱에서:

1. **Bot** → Add Bot → Token 복사
2. **Privileged Gateway Intents** → Message Content Intent ✅, Server Members
   Intent ✅
3. **OAuth2** → scopes: `bot`, `applications.commands` → permissions: View
   Channels, Send Messages, Read Message History, Embed Links, Attach Files, Add
   Reactions
4. 생성된 URL로 **같은 Discord 서버**에 초대

### 2단계: 배포

```bash
git clone git@github.com:kosuha/nexus-ai.git
cd nexus-ai
cp .env.example .env
# .env에 서버/채널 ID + 8개 Bot Token + OPENCLAW_GATEWAY_TOKEN 입력
nano .env
docker compose up -d
```

### 3단계: Pairing

```bash
openclaw pairing list discord
openclaw pairing approve discord <CODE>
```

---

## 부록: 기술 스택

| 구성요소        | 기술                                     | 비고                        |
| --------------- | ---------------------------------------- | --------------------------- |
| 에이전트 런타임 | OpenClaw (MIT)                           | v최신                       |
| Gateway         | OpenClaw Gateway (단일 프로세스)         | 8개 에이전트 동시 관리      |
| 통신 채널       | Discord Bot API × 8                      | 에이전트당 독립 봇          |
| 봇 간 통신      | `allowBots: true` + Discord @mention     | 내부 도구 없이 순수 Discord |
| 브라우저        | browserless/chrome (별도 컨테이너)       | 동시 세션 5개               |
| 컨테이너화      | Docker + Docker Compose                  | Gateway 2GB + Browser 1GB   |
| 파일 공유       | 공유 볼륨 `/home/node/.openclaw/shared/` | —                           |
| LLM 인증        | OpenAI Codex OAuth (구독 기반)           | —                           |
