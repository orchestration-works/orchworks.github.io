---
title: "OrchWorks — 커스텀 OpenClaw 개발 계획"
date: 2026-02-24 16:01:00 +0900
author: joseph
categories: [Collaborate, 01. OrchWorks, OW | 1. 목표 설정]
tags: [openclaw, subagent, typescript, docker-sandbox, linux, heartbeat]
---

## 1. 초기 컨셉 구체화

### 1.1 한 줄 정의

> **Openclaw = "메신저로 대화하면 LLM이 도구를 써서 일을 하고, 결과를 다시 메신저로 보내주는 자체 호스팅 AI 비서"**

### 1.2 개발 범위

OpenClaw의 기본 개념을 익히고 직접 장/단점을 파악해서 커스텀 하기 위함.<br>
일단은 전체 38만 줄을 Copy할 필요는 없다. 핵심만 뽑아서 **실제로 쓸 수 있는 최소 형태**부터 만든다.<br>
메인 에이전트가 동작하고 서브에이전트가 생성되어 작업이 수행되는 형태를 1차 목표로 한다.


| OpenClaw (Full) | OrchWorks (MVP) | 이유 |
|---|---|---|
| 20개 메신저 어댑터 | **Telegram 1개** | Webhook 기반으로 가장 쉽고, Bot API가 잘 문서화됨 |
| 25+ 도구 | **read, write, exec, web_fetch 4개** | 파일 조작 + 명령 실행 + 웹 검색이면 대부분의 작업 가능<br>추후 필요 시 추가 |
| 다중 LLM 프로바이더 + failover | **OpenAI 1개 (+ Anthropic fallback)** | 복잡한 auth profile 순환은 나중에 |
| Docker 샌드박스 | **로컬 exec + allowlist** | 먼저 동작하게 만들고, Docker 격리는 2단계에서 추가 |
| Web UI + TUI + Canvas | **TUI만 (로그/제어)** | 브라우저 UI는 코어가 안정된 뒤 |
| 플러그인 시스템 | **없음 (직접 코드 수정)** | 확장성은 3단계 |
| 서브에이전트 | **1차 개발의 주요 목표** | 메인 루프가 안정된 뒤 spawn/announce 구현 |

### 1.3 기술 스택

| 영역 | 선택 | 이유 |
|---|---|---|
| **언어** | TypeScript (Node.js) | 채널 SDK(grammY), 서버, LLM SDK 모두 TS 생태계가 강함 |
| **런타임** | Node.js 22+ (ESM) | 네이티브 ESM + top-level await |
| **패키지 매니저** | pnpm | 빠르고, workspace 구조에 유리 |
| **서버** | Fastify | Express보다 빠르고 타입 지원 우수 |
| **WebSocket** | ws | Fastify 위에 올리기 쉬움 |
| **Telegram SDK** | grammY | 타입 안전, 미들웨어 패턴 |
| **LLM SDK** | openai (공식) + @anthropic-ai/sdk | 스트리밍 지원, tool calling 표준화 |
| **스키마 검증** | Zod | 도구 파라미터 + 설정 검증 |
| **세션 저장** | SQLite (better-sqlite3) | 파일 기반이라 배포 간단, JSON 컬럼으로 이력 저장 |
| **설정** | JSON5 (openclaw.json) | 주석 허용, OpenClaw 호환 형태 |
| **로깅** | pino | 구조화 로그, 빠름 |
| **테스트** | vitest | TS 네이티브, watch 모드 |

### 1.4 프로젝트 구조 (목표)

```
orchworks/
├── src/
│   ├── gateway/              # Fastify 서버 + WS + RPC
│   │   ├── server.ts         # 부트스트랩
│   │   ├── rpc.ts            # RPC 디스패치
│   │   └── broadcast.ts      # 이벤트 push
│   ├── channels/             # 메신저 어댑터
│   │   └── telegram/
│   │       ├── adapter.ts    # grammY → 내부 메시지 변환
│   │       └── sender.ts     # 내부 → Telegram 전송
│   ├── router/               # (channel, sender) → sessionKey
│   │   └── router.ts
│   ├── agents/               # 에이전트 런타임 (핵심)
│   │   ├── runner.ts         # 메인 while 루프
│   │   ├── attempt.ts        # 단일 LLM 호출
│   │   ├── system-prompt.ts  # 프롬프트 조립
│   │   ├── compaction.ts     # 컨텍스트 압축
│   │   ├── model-selection.ts # 모델 선택/정규화
│   │   └── tool-loop-detection.ts # 무한루프 감지
│   ├── tools/                # 도구 구현
│   │   ├── types.ts          # AgentTool 인터페이스
│   │   ├── read.ts           # 파일 읽기
│   │   ├── write.ts          # 파일 쓰기
│   │   ├── exec.ts           # 명령 실행
│   │   └── web-fetch.ts      # URL 내용 가져오기
│   ├── sessions/             # 세션 관리
│   │   ├── store.ts          # SQLite CRUD
│   │   └── types.ts          # SessionEntry 타입
│   ├── config/               # 설정 로딩
│   │   ├── schema.ts         # Zod 스키마
│   │   └── loader.ts         # JSON5 파싱 + 기본값
│   ├── auto-reply/           # 메시지 전처리 파이프라인
│   │   ├── pipeline.ts       # 커맨드 감지, 미디어 처리
│   │   └── commands.ts       # /new, /model, /help
│   └── utils/                # 공통 유틸
│       ├── logger.ts
│       └── token-counter.ts
├── workspace/                # 에이전트 워크스페이스
│   ├── SOUL.md               # 성격/페르소나
│   ├── TOOLS.md              # 도구 사용 규칙
│   └── MEMORY.md             # 장기 기억
├── tests/
├── package.json
├── tsconfig.json
├── orchworks.json         # 설정 파일
└── README.md
```

---

## 2. 유저 시나리오 정의

> 각 시나리오는 "이게 되면 다음 단계로 넘어간다"는 **마일스톤** 역할을 한다.

### S1: 기본 대화 (Telegram ↔ LLM)

**배경**: 사용자가 Telegram 봇에 메시지를 보내면 AI가 답한다.

```
사용자 → [Telegram] → "오늘 날씨 어때?"
                         ↓
                    [OrchWorks Gateway]
                         ↓
                    [LLM API 호출]
                         ↓
사용자 ← [Telegram] ← "서울 현재 기온 5°C, 맑음입니다."
```

**성공 기준**:
- Telegram 봇이 메시지를 받고 응답을 보낸다
- 대화 이력이 세션에 저장된다 (3턴 이상 맥락 유지)
- `/new` 커맨드로 새 세션을 시작할 수 있다
- 스트리밍 응답이 실시간으로 Telegram에 표시된다 (편집 모드)

### S2: 도구 사용 (파일 + 명령)

**배경**: AI가 사용자 요청에 따라 파일을 읽고, 코드를 수정하고, 명령을 실행한다.

```
사용자 → "package.json 읽어서 의존성 목록 정리해줘"
  ↓
LLM → tool: read("package.json")
  ↓ (결과를 LLM에 반환)
LLM → "현재 의존성은 express, zod, ... 입니다"
```

```
사용자 → "프로젝트 빌드해줘"
  ↓
LLM → tool: exec("npm run build")
  ↓ (stdout/stderr를 LLM에 반환)
LLM → "빌드 성공. 0 errors, 2 warnings..."
```

**성공 기준**:
- LLM이 `read`, `write`, `exec`, `web_fetch` 4개 도구를 올바르게 호출한다
- 도구 실행 결과가 LLM에 반환되어 다음 응답에 반영된다
- 다중 tool-call 라운드트립이 동작한다 (도구A 실행 → 결과 → 도구B 실행 → 최종 답변)
- exec 위험 명령 차단 (allowlist/denylist)

### S3: 컨텍스트 관리 (세션 유지 + 압축)

**배경**: 대화가 길어져서 컨텍스트 윈도우를 초과할 때, 자동으로 이전 대화를 요약한다.

```
[20턴 대화 후, 컨텍스트 80% 사용]
  ↓
시스템: "컨텍스트 임계값 초과. 자동 압축 시작."
  ↓
[이전 15턴을 요약 → 요약문 1개로 대체]
  ↓
[남은 5턴 + 요약문으로 다음 LLM 호출]
```

**성공 기준**:
- 토큰 사용량을 추적하여 임계값 도달 시 자동 compaction
- 요약 후에도 핵심 맥락이 유지됨
- compaction 횟수/전후 토큰수가 로그에 기록됨

### S4: 시스템 프롬프트 + 페르소나

**배경**: 워크스페이스 파일(SOUL.md 등)로 에이전트의 성격과 규칙을 정의한다.

```
workspace/SOUL.md:
  "당신은 시니어 백엔드 개발자입니다. 한국어로 답변하세요."

workspace/TOOLS.md:
  "exec 도구를 사용할 때는 반드시 목적을 먼저 설명하세요."
```

**성공 기준**:
- SOUL.md 내용이 시스템 프롬프트에 반영됨
- TOOLS.md 규칙을 LLM이 따름
- 파일을 수정하면 다음 대화부터 즉시 반영됨 (핫 리로드)

### S5: 서브에이전트 (병렬 작업 위임)

**배경**: 메인 에이전트가 복잡한 작업을 여러 자식 에이전트에게 분업시킨다.

```
사용자 → "이 3개 파일의 버그를 각각 고쳐줘"
  ↓
메인 LLM → sessions_spawn(task: "file1.ts 버그 수정")
         → sessions_spawn(task: "file2.ts 버그 수정")
         → sessions_spawn(task: "file3.ts 버그 수정")
  ↓
[3개 서브에이전트가 병렬 실행]
  ↓
[각각 완료 시 announce → 메인에게 결과 push]
  ↓
메인 LLM → "3개 파일 모두 수정 완료. 변경 사항: ..."
```

**성공 기준**:
- `sessions_spawn` 도구로 자식 에이전트 생성
- 자식 완료 시 부모에게 결과 자동 전달 (announce)
- depth 제한 (최대 2단계) + 동시 자식 수 제한 (최대 3개)
- 자식의 도구 목록이 부모보다 제한됨 (leaf policy)

### S6: 자율 운영 (크론 + 하트비트)

**배경**: 사람이 없어도 정해진 스케줄에 AI가 자동으로 작업한다.

```
[매일 09:00]
  ↓
Cron → agent turn: "HEARTBEAT.md 읽고 할 일이 있으면 처리해"
  ↓
LLM → exec("git pull && npm test")
    → "테스트 통과. 특이사항 없음."
  ↓
[HEARTBEAT_OK → 사용자에게 전달 안 함 (조용히 처리)]
```

**성공 기준**:
- cron 표현식 / interval / one-shot 3가지 스케줄 지원
- 실행 결과를 Telegram으로 전달 (HEARTBEAT_OK이면 생략)
- 연속 오류 시 지수 백오프 (30s → 1m → 5m → ...)

---

## 3. 시나리오별 개발 필요사항

### S1 필요사항: 기본 대화

| # | 모듈 | 구현 내용 | 난이도 |
|---|------|----------|--------|
| 1-1 | `gateway/server.ts` | Fastify 서버 부트스트랩, healthcheck, graceful shutdown | ★☆☆ |
| 1-2 | `channels/telegram/adapter.ts` | grammY 봇 초기화, Webhook/Long-polling, 메시지 수신 → 내부 형식 변환 | ★★☆ |
| 1-3 | `channels/telegram/sender.ts` | 내부 응답 → Telegram 전송 (마크다운 변환, 길이 제한 chunking, 편집 모드 스트리밍) | ★★☆ |
| 1-4 | `router/router.ts` | `(channel, chatId, senderId)` → `sessionKey` 생성 규칙 | ★☆☆ |
| 1-5 | `sessions/store.ts` | SQLite로 세션 CRUD: create, get, appendMessage, listMessages, delete | ★★☆ |
| 1-6 | `agents/runner.ts` | 메인 while 루프: LLM 호출 → tool call 확인 → 도구 실행 → 재호출 ... → 최종 답변 반환 | ★★★ |
| 1-7 | `agents/attempt.ts` | 단일 LLM API 호출 (OpenAI chat.completions, stream=true, tool calling) | ★★☆ |
| 1-8 | `agents/system-prompt.ts` | 최소 시스템 프롬프트 조립 (identity + tool list + workspace files) | ★★☆ |
| 1-9 | `config/schema.ts` + `loader.ts` | Zod로 설정 스키마 정의 + JSON5 파싱 | ★☆☆ |
| 1-10 | `auto-reply/commands.ts` | `/new` (세션 리셋), `/help` (도움말) 커맨드 처리 | ★☆☆ |
| 1-11 | `utils/token-counter.ts` | tiktoken으로 메시지 토큰 수 추정 | ★☆☆ |

### S2 필요사항: 도구 사용

| # | 모듈 | 구현 내용 | 난이도 |
|---|------|----------|--------|
| 2-1 | `tools/types.ts` | `AgentTool` 인터페이스: name, description, parameters(Zod), execute() | ★☆☆ |
| 2-2 | `tools/read.ts` | 파일 읽기: path 검증, 크기 제한, 줄 범위 지정 | ★☆☆ |
| 2-3 | `tools/write.ts` | 파일 쓰기: path 검증, 디렉토리 자동 생성, 백업 옵션 | ★☆☆ |
| 2-4 | `tools/exec.ts` | 명령 실행: child_process.spawn, timeout, stdout/stderr 캡처, 출력 트렁케이션 | ★★☆ |
| 2-5 | `tools/web-fetch.ts` | URL 내용 가져오기: HTTP GET, HTML→텍스트 변환, 크기 제한 | ★★☆ |
| 2-6 | `tools/exec.ts` (보안) | allowlist/denylist 패턴 매칭, 위험 명령 차단, 승인 모드(ask) | ★★☆ |
| 2-7 | `agents/runner.ts` (확장) | tool call 결과를 history에 추가하고 다음 LLM 호출에 포함하는 라운드트립 루프 | ★★★ |
| 2-8 | `agents/tool-loop-detection.ts` | 같은 tool+params 반복 감지 (hash 비교, threshold 경고/차단) | ★★☆ |

### S3 필요사항: 컨텍스트 관리

| # | 모듈 | 구현 내용 | 난이도 |
|---|------|----------|--------|
| 3-1 | `agents/compaction.ts` | 메시지 이력을 chunk로 분할 → LLM으로 요약 → 요약문으로 대체 | ★★★ |
| 3-2 | `agents/runner.ts` (확장) | context overflow 감지 시 compaction 시도 → 재시도 루프 | ★★☆ |
| 3-3 | `utils/token-counter.ts` (확장) | 시스템 프롬프트 + 이력 + 도구 스키마의 총 토큰을 계산, 임계값 비교 | ★★☆ |
| 3-4 | `agents/runner.ts` (확장) | 도구 결과가 너무 길면 자동 트렁케이션 (oversized tool result 처리) | ★★☆ |

### S4 필요사항: 시스템 프롬프트 + 페르소나

| # | 모듈 | 구현 내용 | 난이도 |
|---|------|----------|--------|
| 4-1 | `agents/system-prompt.ts` (확장) | SOUL.md, TOOLS.md, IDENTITY.md 등 워크스페이스 파일을 섹션별로 조립 | ★★☆ |
| 4-2 | `agents/system-prompt.ts` (확장) | `full` / `minimal` 2가지 PromptMode 지원 | ★☆☆ |
| 4-3 | `config/loader.ts` (확장) | workspace 디렉토리 경로 설정, 파일 변경 감지 (fs.watch) | ★★☆ |

### S5 필요사항: 서브에이전트

| # | 모듈 | 구현 내용 | 난이도 |
|---|------|----------|--------|
| 5-1 | `agents/subagent-spawn.ts` | childSessionKey 생성, depth/children 가드레일, agent RPC 호출 | ★★★ |
| 5-2 | `agents/subagent-registry.ts` | Map 기반 run 상태 관리, lifecycle event 구독, 디스크 영속화 | ★★★ |
| 5-3 | `agents/subagent-announce.ts` | 완료 결과를 부모 세션에 push (direct → queue fallback) | ★★★ |
| 5-4 | `tools/sessions-spawn.ts` | `sessions_spawn` 도구 정의 (task, model, thinking, thread 파라미터) | ★★☆ |
| 5-5 | `agents/system-prompt.ts` (확장) | `buildSubagentSystemPrompt()`: 서브에이전트용 오버레이 (역할/금지/깊이) | ★★☆ |
| 5-6 | `agents/tool-policy.ts` | 서브에이전트 깊이별 도구 제한 (DENY_ALWAYS + DENY_LEAF) | ★★☆ |

### S6 필요사항: 자율 운영

| # | 모듈 | 구현 내용 | 난이도 |
|---|------|----------|--------|
| 6-1 | `cron/service.ts` | CronService: start/stop, add/remove job, timer loop | ★★★ |
| 6-2 | `cron/schedule.ts` | 3종 스케줄 계산 (at/every/cron 표현식) | ★★☆ |
| 6-3 | `cron/runner.ts` | due job 실행 → agent turn → 결과 전달 | ★★☆ |
| 6-4 | `heartbeat/runner.ts` | 주기적 LLM 호출, HEARTBEAT_OK 감지 시 전달 생략 | ★★☆ |
| 6-5 | `cron/store.ts` | job 상태 JSONL 파일 저장, auto-prune | ★★☆ |

---

## 4. 개발 일정

> 1인 기준, 주 20~30시간 투자 가정. 각 Sprint = 1주.

```
Sprint 0 (Day 0)     프로젝트 스캐폴딩
  │
Sprint 1 (Week 1)    S1: 기본 대화 ──────────── "텔레그램에서 3턴 대화가 된다"
  │
Sprint 2 (Week 2)    S2: 도구 사용 ──────────── "파일 읽고 쓰고 명령 실행한다"
  │
Sprint 3 (Week 3)    S3+S4: 컨텍스트+페르소나 ─ "긴 대화도 안정, 성격이 있다"
  │
Sprint 4 (Week 4)    S5: 서브에이전트 ────────── "병렬 작업 위임이 된다"
  │
Sprint 5 (Week 5)    S6: 자율 운영 ──────────── "혼자서 일한다"
  │
Sprint 6 (Week 6)    안정화 + Docker 샌드박스 ── "프로덕션에 쓸 수 있다"
```

### Sprint 0: 프로젝트 스캐폴딩 (Day 0, 2~3시간)

| 작업 | 산출물 |
|------|--------|
| pnpm init + tsconfig + vitest 설정 | `package.json`, `tsconfig.json`, `vitest.config.ts` |
| ESLint + Prettier 설정 | `.eslintrc.cjs`, `.prettierrc` |
| 디렉토리 구조 생성 | `src/` 하위 폴더 전부 |
| 기본 타입 정의 | `InternalMessage`, `SessionKey`, `AgentTool` |
| 설정 파일 스키마 + 로더 | `orchworks.json` 샘플, Zod 스키마 |

### Sprint 1: S1 기본 대화 (Week 1)

| Day | 작업 | 목표 |
|-----|------|------|
| **Day 1** | Telegram 봇 초기화 (grammY) + Webhook 수신 | 메시지 콘솔에 찍힌다 |
| **Day 2** | 라우터 + 세션 스토어 (SQLite) | sessionKey 생성 + 이력 저장/조회 |
| **Day 3** | LLM 호출 (OpenAI, 비스트리밍) + 응답 전송 | "안녕"에 "안녕하세요" 답변 |
| **Day 4** | 스트리밍 응답 (Telegram editMessageText) | 실시간 타이핑 효과 |
| **Day 5** | 시스템 프롬프트 (최소) + `/new` 커맨드 | 페르소나 + 세션 리셋 |
| **Day 6** | 토큰 카운터 + 에러 핸들링 | rate limit 대응, 타임아웃 |
| **Day 7** | 통합 테스트 + 리팩토링 | 3턴 대화 E2E 테스트 통과 |

**Sprint 1 완료 기준**: Telegram에서 3턴 대화가 맥락을 유지하며 동작한다.

### Sprint 2: S2 도구 사용 (Week 2)

| Day | 작업 | 목표 |
|-----|------|------|
| **Day 1** | `AgentTool` 인터페이스 + tool registry | 도구 등록/조회 구조 |
| **Day 2** | `read` + `write` 도구 구현 | 파일 읽기/쓰기가 된다 |
| **Day 3** | `exec` 도구 구현 (spawn + timeout + truncation) | 명령 실행 + 출력 캡처 |
| **Day 4** | `web_fetch` 도구 구현 (HTTP GET + HTML→text) | URL 내용 가져오기 |
| **Day 5** | runner 확장: tool-call 라운드트립 루프 | tool → result → tool → ... → 답변 |
| **Day 6** | exec 보안: allowlist/denylist + 루프 감지 | `rm -rf /` 차단, 10회 반복 경고 |
| **Day 7** | 통합 테스트 | "package.json 읽어서 정리해줘" E2E |

**Sprint 2 완료 기준**: LLM이 도구를 여러 번 호출해서 작업을 완료하고 결과를 보낸다.

### Sprint 3: S3+S4 컨텍스트 + 페르소나 (Week 3)

| Day | 작업 | 목표 |
|-----|------|------|
| **Day 1** | 토큰 카운터 고도화: system + history + tools 합산 | 정확한 사용량 추적 |
| **Day 2** | compaction 구현: chunk → summarize → replace | 자동 압축 |
| **Day 3** | runner 확장: overflow → compaction → retry 루프 | 복구 전략 통합 |
| **Day 4** | system-prompt 확장: SOUL.md/TOOLS.md 섹션 조립 | 페르소나 |
| **Day 5** | PromptMode (full/minimal) + 워크스페이스 핫 리로드 | 서브에이전트 준비 |
| **Day 6-7** | 통합 테스트 + 안정화 | 30턴 대화에서 compaction 정상 동작 |

**Sprint 3 완료 기준**: 긴 대화에서 자동 압축이 동작하고, 워크스페이스 파일로 성격이 바뀐다.

### Sprint 4: S5 서브에이전트 (Week 4)

| Day | 작업 | 목표 |
|-----|------|------|
| **Day 1** | `sessions_spawn` 도구 + `spawnSubagentDirect()` | child run 생성 |
| **Day 2** | subagent registry: Map + lifecycle event | 상태 관리 |
| **Day 3** | subagent announce: 완료 → 부모 push | 결과 전달 |
| **Day 4** | 가드레일: depth, maxChildren, tool policy | 안전장치 |
| **Day 5** | `buildSubagentSystemPrompt()` 오버레이 | 서브에이전트 역할 제한 |
| **Day 6-7** | 통합 테스트 | "3개 파일 각각 고쳐줘" E2E |

**Sprint 4 완료 기준**: 메인이 3개 서브에이전트를 spawn하고 결과를 합쳐 답변한다.

### Sprint 5: S6 자율 운영 (Week 5)

| Day | 작업 | 목표 |
|-----|------|------|
| **Day 1** | CronService + 3종 스케줄 계산 | 타이머 루프 |
| **Day 2** | cron job 실행 → agent turn | 자동 실행 |
| **Day 3** | 결과 전달 + HEARTBEAT_OK 필터 | 조용한 성공 |
| **Day 4** | 연속 오류 지수 백오프 + 상태 로깅 | 안정성 |
| **Day 5-7** | 통합 테스트 + 전체 안정화 | 24시간 무중단 테스트 |

**Sprint 5 완료 기준**: 크론으로 자동 실행 + 결과 Telegram 전달이 된다.

### Sprint 6: 안정화 + Docker 샌드박스 (Week 6)

| Day | 작업 | 목표 |
|-----|------|------|
| **Day 1-2** | Docker 컨테이너 exec 격리 (read-only, no-network) | 보안 실행 |
| **Day 3** | 모델 fallback (OpenAI 장애 → Anthropic) | 가용성 |
| **Day 4** | 비용 추적 (토큰 사용량 로깅) | 운영 가시성 |
| **Day 5-7** | E2E 테스트 스위트 + 문서화 + README | 릴리스 준비 |

---