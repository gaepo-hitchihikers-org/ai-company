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
- **멀티에이전트 라우팅**: Gateway가 채널/계정별로 격리된 에이전트에 메시지를
  자동 라우팅. `agents.list[]`로 에이전트별 모델, 도구, 워크스페이스 분리 가능.
- **1급 도구 시스템**: 브라우저 제어, 쉘 실행, 파일 관리, 크론, 웹훅이 내장.
  Skills 플랫폼으로 확장 가능.
- **모델 Failover**: Primary → Fallback 자동 전환. 특정 LLM 벤더에 종속되지
  않음.
- **오픈소스 (MIT)**: 145,000+ GitHub Stars. 활발한 커뮤니티와 515명+ 기여자.

---

## 1. 토큰 최적화 엔진

AI 직원을 24시간 운영하면 토큰 비용이 핵심 문제가 된다. OpenClaw 본체의 내장
기능과 커스텀 전략을 조합하여 비용을 최소화한다.

### A. Session Pruning (세션 가지치기) — OpenClaw 내장 ✅

Anthropic 프롬프트 캐시 TTL과 연동하여, 캐시 만료 후 불필요한 도구 결과를
자동으로 잘라낸다.

```yaml
# config.yaml
agent:
    contextPruning:
        mode: "cache-ttl"
        ttl: "5m"
        keepLastAssistants: 3
        softTrim:
            maxChars: 4000
            headChars: 1500
            tailChars: 1500
        hardClear:
            enabled: true
            placeholder: "[Old tool result content cleared]"
```

- **Soft-trim**: 큰 도구 결과의 head/tail만 남기고 중간 생략.
- **Hard-clear**: 오래된 결과를 placeholder로 완전 대체.
- 이미지 블록은 절대 제거하지 않음.

### B. Memory Compaction (메모리 압축) — OpenClaw 내장 ✅

| 단계                  | 동작                                              | 효과                    |
| --------------------- | ------------------------------------------------- | ----------------------- |
| Memory Flush          | 컨텍스트 한계 전, 핵심 사실을 `MEMORY.md`에 기록  | 중요 정보 영속화        |
| Compaction            | ~40,000 토큰 도달 시 전체 세션을 요약 파일로 압축 | 컨텍스트 윈도우 초기화  |
| Session Memory Search | 과거 세션 데이터를 시맨틱 쿼리                    | 필요한 맥락만 정밀 복원 |

### C. Context Slimming (컨텍스트 슬리밍) — 커스텀 전략

- `AGENTS.md`, `SOUL.md`, `MEMORY.md` 파일을 최소한으로 유지 → 입력 토큰
  **30-90%** 절감.
- `qmd`를 통한 정밀 지식 검색 → 조회당 토큰 **90%** 절감 (15,000 → 1,500).
- 실사용자 사례: 채팅 토큰 100k → 17k (**83% 절감**).

### D. Model Layering (모델 계층화) — 핵심 비용 절감 전략

성능이 필요한 에이전트(PM, Dev)는 **Claude Opus 4.6**, 루틴 업무(QA, 크론)는
**Claude Sonnet 4.5**, Design/Research는 **Gemini 3 Flash**를 사용한다.
Anthropic 프롬프트 캐싱(캐시 히트 시 입력 토큰 90% 할인)을 최대한 활용하기 위해
Claude 모델을 중심으로 통일한다.

```yaml
# config.yaml
agents:
    contextTokens: 50000 # 기본 200k → 50k 제한, 요청당 20-40% 절감
    list:
        - name: "PM_Agent"
          model:
              primary: "anthropic/claude-opus-4-6"
              fallbacks: ["anthropic/claude-sonnet-4-5"]
        - name: "Dev_Agent"
          model:
              primary: "anthropic/claude-opus-4-6"
              fallbacks: ["anthropic/claude-sonnet-4-5"]
        - name: "Design_Agent"
          model:
              primary: "google/gemini-3-flash"
              fallbacks: ["google/gemini-2.5-flash-lite"]
        - name: "Research_Agent" # Research & Growth
          model:
              primary: "google/gemini-3-flash"
              fallbacks: ["google/gemini-2.5-flash-lite"]
        - name: "QA_Agent"
          model:
              primary: "anthropic/claude-sonnet-4-5"
```

### E. TGAA (Tiered Global Anchor Architecture) — 커스텀 구현 필요

> ⚠️ TGAA는 ClawdMatrix 포크의 개념으로, OpenClaw 본체에는 미구현. 하지만
> `AGENTS.md` 시스템 프롬프트를 활용하여 동일한 효과를 구현할 수 있다.

- **목적**: 대화가 길어져도 핵심 목표와 현재 상태를 잃지 않도록 함.
- **구현**: 모든 에이전트의 `AGENTS.md` 상단에 고정된 **Global Anchor** 배치.
- **내용**: 현재 프로젝트 상태, 팀 구성원 목록, 진행 중인 태스크 맵.

### F. Cron (정기 업무 스케줄링) — OpenClaw 내장 ✅

에이전트가 사장 지시 없이도 자발적으로 수행하는 정기 업무를 등록한다.

- 상태 점검, 헬스체크, 정기 리포트 등 자동 실행.
- 정기 요청이 Anthropic 캐시를 부수적으로 warm 상태로 유지해주므로, 별도의 캐시
  전용 하트비트는 불필요.

---

## 2. 에이전트 팀 구성 (Who)

각 에이전트는 실제 스타트업의 부서/직원에 대응한다.

| 에이전트              | 역할                                | 모델 (Primary → Fallback)   | 주요 도구                      |
| --------------------- | ----------------------------------- | --------------------------- | ------------------------------ |
| **🎯 PM_Agent**       | 전략 수립, 업무 분배, 상태 관리     | Opus 4.6 → Sonnet 4.5       | Slack 관리, TGAA 앵커 업데이트 |
| **💻 Dev_Agent**      | 코드 작성, 테스트, 배포             | Opus 4.6 → Sonnet 4.5       | Shell, Git, Browser, File I/O  |
| **🎨 Design_Agent**   | UI/UX 설계, 에셋 생성               | Gemini 3 Flash → Flash-Lite | Browser, 이미지 생성, File I/O |
| **🔍 Research_Agent** | 시장 조사, 경쟁 분석, 그로스/마케팅 | Gemini 3 Flash → Flash-Lite | Browser, qmd 검색              |
| **✅ QA_Agent**       | 코드 리뷰, 테스트 실행, 품질 관리   | Sonnet 4.5                  | Shell, Git, 테스트 프레임워크  |

각 에이전트는 OpenClaw의 `agents.list[]` 설정으로 격리된 워크스페이스와 독립적인
모델/도구를 배정 받는다. 모델 배정 근거는
[1.D. Model Layering](#d-model-layering-모델-계층화--핵심-비용-절감-전략) 참조.

---

## 3. 슬랙 기반 부서별 운영 규약

에이전트들이 슬랙에서 **실제 직원처럼** 상호작용하기 위한 통신 프로토콜이다.

### 채널 아키텍처

| 채널             | 용도                                     | 접근 권한            |
| ---------------- | ---------------------------------------- | -------------------- |
| `#pm-strategy`   | 사장(인간) 지시 및 전략 컨펌             | 사장 + PM_Agent      |
| `#collab-bridge` | 에이전트 간 `@mention` 업무 이관 및 협업 | 전체 에이전트        |
| `#dev-logs`      | Dev_Agent 실행 로그, 빌드/배포 상태      | Dev_Agent + QA_Agent |
| `#design-review` | 디자인 시안 업로드 및 피드백             | Design_Agent + 사장  |
| `#alerts`        | 에러, 장애, 긴급 알림                    | 전체 에이전트 + 사장 |

### 에이전트 소통 매너

- **Reaction Trigger**: 메시지 수신 시 👀(`:eyes:`), 작업 중
  🔄(`:arrows_counterclockwise:`), 완료 시 ✅(`:white_check_mark:`), 실패 시
  ❌(`:x:`)로 진행 상태를 시각화.
- **Thread Context**: OpenClaw의 `thread_id` 추적으로 특정 스레드 내 대화만
  컨텍스트로 묶어 처리. 불필요한 cross-thread 토큰 소모 방지.
- **구조화된 보고**: 모든 보고는 `[상태] 제목 / 요약 / 다음 단계` 형식을 따름.

---

## 4. 하이브리드 파일 공유 시스템 (Local + Slack)

### 내부 데이터 처리 (Local Shared)

- **경로**: `/app/shared/nexus_storage/`
- **로직**: 에이전트 간 주고받는 원본 데이터, 소스 코드, 중간 결과물은 로컬에
  저장하고 **슬랙에는 경로명(Path)**만 텍스트로 공유.
- **OpenClaw 도구**: `list_shared_files`, `read_local_file` 스킬 장착.

### 최종 결과 보고 (Slack Upload)

- **로직**: 사장이 확인해야 할 결과물은 OpenClaw의 `upload_to_slack` 도구로
  채널에 직접 업로드.
- **대상**: UI 스크린샷, 요약 보고서 PDF, 배포 완료 알림 등.

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
   │                         │                              ├── 🔄 로컬 작업 수행
   │                         │                              ├── 공유 볼륨 파일 I/O
   │                         │                              ├── ✅ 완료
   │                         │   ◀── 결과 보고 ─────────────┤
   │                         ├── 결과 검증                   │
   │   ◀── 컨펌 요청 ───────┤                              │
   ├── 승인/수정 지시 ──────▶ │                              │
   │                         ├── 앵커 최종 업데이트          │
```

### 자동 승인 vs 사장 컨펌

| 구분               | 예시                                                | 처리                          |
| ------------------ | --------------------------------------------------- | ----------------------------- |
| **자동 승인**      | 로그 체크, 단순 파일 정리, 정기 리포트              | PM_Agent가 자체 승인          |
| **사장 컨펌 필수** | 코드 배포, 외부 API 호출, 비용 발생 작업, 전략 변경 | `#pm-strategy`에 보고 후 대기 |

---

## 6. 에러 핸들링 및 장애 대응

### 장애 시나리오별 대응

| 시나리오                   | 감지                                 | 대응                               |
| -------------------------- | ------------------------------------ | ---------------------------------- |
| **에이전트 Hallucination** | QA_Agent 교차 검증                   | 결과 폐기 후 재작업 지시           |
| **무한 루프**              | 크론 하트비트로 응답 시간 모니터링   | 세션 강제 종료 + `#alerts` 알림    |
| **Slack Rate Limit**       | HTTP 429 응답 감지                   | 지수적 백오프(Exponential Backoff) |
| **에이전트 간 교착 상태**  | PM_Agent가 대기 시간 임계값 모니터링 | 교착 해제 + 업무 재분배            |
| **LLM API 장애**           | Model Failover 자동 작동             | Primary → Fallback 모델 전환       |
| **파일 시스템 충돌**       | 파일 락(Lock) 메커니즘               | 쓰기 큐(Write Queue) 순차 처리     |

### 보안 정책

- **샌드박싱**: 각 에이전트는 Docker 컨테이너 내에서만 동작. 호스트 직접 접근
  불가.
- **Slack DM 정책**: `pairing` 모드 — 인증된 사용자만 에이전트와 DM 가능.
- **API 키 분리**: 에이전트별 별도 API 키. 한 에이전트 침해 시 다른 에이전트에
  영향 없음.
- **Gateway 바인딩**: `ws://127.0.0.1:18789` loopback 전용. 외부 접근은
  Tailscale Serve/Funnel로만 허용.

---

## 7. 실무 구현 체크리스트

### 인프라

- [ ] Docker Compose로 전체 에이전트 오케스트레이션 구성
- [ ] 모든 컨테이너가 동일한 `UID/GID`로 공유 볼륨 접근 확인
- [ ] Gateway loopback 바인딩 + Tailscale 설정
- [ ] 에이전트별 워크스페이스 디렉토리 분리

### Slack 연동

- [ ] Slack App 생성 (Socket Mode 활성화)
- [ ] Bot User OAuth Token (`xoxb-...`) 발급
- [ ] App-Level Token (`xapp-...`) 발급
- [ ] 스코프 부여: `files:write`, `reactions:read`, `reactions:write`,
      `chat:write`, `channels:history`
- [ ] 채널별 에이전트 라우팅 설정

### LLM 설정

- [ ] Anthropic API Key 설정 (Opus 4.6 / Sonnet 4.5)
- [ ] Google AI API Key 설정 (Gemini 3 Flash — Design/Research_Agent용)
- [ ] PM/Dev_Agent에 Opus 4.6, QA_Agent/크론에 Sonnet 4.5 모델 설정
- [ ] Design/Research_Agent에 Gemini 3 Flash 개별 모델 오버라이드
- [ ] `cacheControlTtl` 설정 및 Session Pruning `cache-ttl` 모드 활성화
- [ ] 컨텍스트 윈도우 50k 제한 설정 (`agent.contextTokens: 50000`)
- [ ] Anthropic 캐시 히트 동작 확인

### 에이전트 설정

- [ ] 각 에이전트의 `AGENTS.md` 시스템 프롬프트 작성
- [ ] TGAA Global Anchor 템플릿 작성
- [ ] `tools.allow` / `tools.deny`로 에이전트별 도구 제한
- [ ] 정기 업무 크론 스케줄 설정
- [ ] Session Pruning `cache-ttl` 모드 활성화

---

## 부록: 기술 스택 참조

| 구성요소        | 기술                                           | 비고                           |
| --------------- | ---------------------------------------------- | ------------------------------ |
| 에이전트 런타임 | OpenClaw (MIT, `github.com/openclaw/openclaw`) | v최신, 40+ releases            |
| Gateway         | OpenClaw Gateway (WS control plane)            | 로컬 loopback 바인딩           |
| 통신 채널       | Slack (Bolt SDK) + 내부 WebSocket              | Socket Mode                    |
| 컨테이너화      | Docker + Docker Compose                        | 공유 볼륨 마운트               |
| 파일 공유       | 로컬 공유 볼륨 `/app/shared/nexus_storage/`    | —                              |
| CI/CD           | Dev_Agent + QA_Agent 협업                      | 자동 테스트 → 사장 컨펌 → 배포 |
| 모니터링        | `#alerts` 채널 + 크론 정기 점검                | —                              |
| 원격 접근       | Tailscale Serve/Funnel                         | 선택 사항                      |
