# codex-kit

Codex로 180분짜리 과제를 풀 때 쓰는 작업 키트. 과제 폴더에 작업 규칙(`AGENTS.md`), 스킬 6개, 기록 템플릿을 설치하고 OpenAI Docs MCP를 등록한다. 풀이 코드는 들어 있지 않다.

## 설치 (과제 시작 직후, 1분)

과제 폴더(저장소 루트)의 터미널에서:

```bash
git clone https://github.com/roundycat/codex-kit /tmp/codex-kit
bash /tmp/codex-kit/setup.sh
```

그다음 Codex를 실행하고(이미 켜져 있었으면 다시 실행) `$kickoff`.

| 옵션 | 설명 |
|---|---|
| `--no-mcp` | MCP 등록 생략 |
| `--no-commit` | 설치 파일 자동 커밋 생략 |
| `--git-init` | git 저장소가 아니면 새로 만듦 |
| `--force` | 이미 설치된 스킬과 AGENTS.md의 키트 블록을 최신으로 교체 |
| `[경로]` | 설치 대상 폴더 지정 (기본: 현재 git 루트) |

여러 번 실행해도 결과가 같다. 과제 쪽 파일은 덮어쓰지 않는다.

## 설치되는 것

| 위치 | 내용 |
|---|---|
| `AGENTS.md` | Codex가 세션마다 자동으로 읽는 작업 규칙. 과제에 이미 있으면 원문 끝에 덧붙임 |
| `.agents/skills/` | `$kickoff` `$verify` `$cross-check` `$explain` `$handoff` `$wrap-up` |
| `.agents/skills/verify/scripts/check.sh` | 문법·테스트·린트·타입·비밀키 점검을 한 번에 돌리고 `notes/VERIFY.md`에 기록 |
| `notes/` | PROBLEM · PLAN · DECISIONS · VERIFY · HANDOFF 템플릿 (기존 파일은 건드리지 않음) |
| `.gitignore` | 가상환경·캐시·`.env` 중 빠진 항목만 추가 |
| `~/.codex/config.toml` | `openaiDeveloperDocs` MCP (OpenAI 공식 문서 읽기 전용) |

설치 내용은 `chore:` 커밋 하나로 남는다. push는 하지 않는다.

## 스킬

| 스킬 | 언제 | 하는 일 |
|---|---|---|
| `$kickoff` | 시작 직후 | 정찰 → 실무자 인터뷰 질문 → 측정 가능한 성공 기준(`PROBLEM.md`) → 검증 가능한 단계(`PLAN.md`) |
| `$verify` | 단계마다 | check.sh → 테스트 보강 → 실제 실행 → 성공 기준 대조 → 커밋 |
| `$cross-check` | 약 90분, 제출 전 | 새 세션에서 독립 리뷰. 코드는 안 고치고 `REVIEW.md`에 발견만 기록 |
| `$explain` | 큰 기능 후, 마무리 전 | 구조·결정·리스크(약점 → 영향 → 탐지 → 대응)를 `DECISIONS.md`에 정리하고 브리핑 |
| `$handoff` | 맥락이 길어질 때 | `HANDOFF.md` 작성 → `/new` → "인계 받아서 이어서 진행" |
| `$wrap-up` | 160분 | 기능 동결 → 최종 검증 → README → 문서 최신화 → 최종 커밋 → 브리핑 |

## 당일 흐름 (과제 180분 기준)

| 경과 | 할 일 | 입력 |
|---|---|---|
| 0–3분 | 키트 설치, Codex 실행 | (터미널) clone + setup.sh |
| 3–25분 | 정찰 → 실무자 인터뷰 → 문제 정의·계획 | `$kickoff` → 인터뷰 답을 Codex에 전달 |
| 25–140분 | 단계 구현 → 검증 → 커밋 반복 | "PLAN 1단계 진행" → `$verify` |
| 맥락이 길 때 | 인계 후 새 세션 | `$handoff` → `/new` → "인계 받아서 이어서 진행" |
| 약 90분 | 독립 리뷰 후 H 항목 수정 | 새 터미널에서 `codex` → `$cross-check` |
| 140–160분 | 구조·결정·리스크 정리 | `$explain` |
| 160–175분 | 기능 동결, 최종 검증·README·커밋 | `$wrap-up` |
| 175–180분 | `notes/DECISIONS.md` 리스크 표와 브리핑을 **직접** 읽기 | — |

시간이 밀리면 기능을 줄이고 `$wrap-up`의 20분은 지킨다.

## 후속 서술형 (6문항 × 5분, AI 없이)

답의 틀: **어디가**(파일·함수) → **왜**(그렇게 한 이유, 또는 위험한 이유와 영향) → **다음에**(무엇을 검증·개선할지).
문항당 1분 구상, 3분 작성, 1분 점검. 내 코드와 notes에 있는 실제 이름과 수치로 답한다.

## 안내문 기준 규칙

- 과제 AI는 제공된 Codex만. 다른 모델·서비스 연결 금지
- 문제·파일·결과물 외부 전송 금지, git push 금지
- Computer Use(자동 조작), 감독·보안 설정 우회 금지
- 공개 Skill·MCP·Plugin과 GitHub 공개 도구는 허용. 외부 코드는 일부 참고만
- 서술형은 AI·복사·붙여넣기 없이 직접

키트의 `AGENTS.md`가 이 규칙을 Codex에게도 지키게 한다.

## 사전 체험(1회, 15분) 체크리스트

1. 터미널에서 clone이 되는지 (GitHub 접근)
2. `bash /tmp/codex-kit/setup.sh` 출력에 `[error]`가 없는지
3. Codex에서 `$`를 입력하면 스킬 6개가 보이는지, `/mcp`에 `openaiDeveloperDocs`가 보이는지
4. Cofa Helper에 확인: "직접 만든 공개 GitHub 레포(작업 규칙·스킬 키트, 풀이 코드 없음)를 clone해서 써도 되나요?"
5. 허용이 애매하면 키트 없이 진행: Codex 기본 스킬 `$skill-creator`로 필요한 스킬을 즉석에서 만들고, AGENTS.md는 짧게 직접 작성

## 문제 해결

| 증상 | 조치 |
|---|---|
| 스킬이 안 보임 | Codex 재시작. 과제 폴더(저장소 루트)에서 Codex를 실행했는지, `.agents/skills/<이름>/SKILL.md`가 있는지 확인 |
| MCP 연결 실패 | 무시하고 진행해도 된다(웹 검색으로 대체). 다시 하려면 Codex 재시작 후 `/mcp` |
| 커밋 실패 (작성자 정보 없음) | setup.sh가 이 저장소에만 `candidate`로 설정한다. 그래도 실패하면 `git status` 확인 |
| `AGENTS.md`가 크다는 경고 | 과제 쪽 AGENTS.md가 큰 경우. Codex 기본 한도는 32KiB라 뒷부분(키트 규칙)이 잘릴 수 있다 |
| git 저장소가 아니라는 경고 | 커밋 기록이 필요하면 `bash /tmp/codex-kit/setup.sh --git-init` |

## 구성

```
setup.sh                     설치 스크립트
kit/AGENTS.md                작업 규칙 (<!-- codex-kit:start/end --> 블록)
kit/.agents/skills/*/SKILL.md
kit/.agents/skills/verify/scripts/check.sh
kit/notes/*.md               기록 템플릿
```
