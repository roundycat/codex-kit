---
name: handoff
description: 세션 인계. 대화가 길어져 맥락이 흐려지기 전, 또는 큰 단계를 마쳤을 때 notes/HANDOFF.md에 시각·기준 커밋·목표·R·S 상태·결정·다음 단계·검증 명령을 기록해 새 세션이 바로 이어받게 한다. 인계, 새 세션, 정리하고 넘어가자 같은 요청에 사용.
---

# handoff: 새 세션이 5분 안에 이어받게

언제: 큰 단계 2~3개마다, 방향이 바뀔 때, `/status`에서 컨텍스트 사용량이 높을 때. 자동 압축에 맡기기 전에 쓴다.

## 쓰기
1. **사실 수집**: `TZ=KST-9 date +%H:%M`, `git rev-parse --short HEAD`, `git log --oneline -15`, `git status --short`, `notes/PROBLEM.md`, `notes/PLAN.md`, 최근 `notes/VERIFY.md`와 `notes/REVIEW.md`.
2. **`notes/HANDOFF.md`를 새로 쓴다** (한 화면 이내):
   - 작성 시각(한국 시간)과 기준 커밋(HEAD)
   - 목표와 R·S별 상태(충족/부분/미충족)
   - 완료한 것: 커밋 해시와 한 줄 설명
   - 진행 중인 것과 정확한 다음 3단계
   - 핵심 결정: `notes/DECISIONS.md`의 ID로 참조
   - 알려진 문제와 함정: 시도했다가 실패한 것 포함
   - 실행·검증 명령: 그대로 복사해 쓸 수 있게
   - 남은 시간 기준 우선순위
3. **커밋**: `git add notes/HANDOFF.md && git commit -m "docs: <몇 단계까지> 인계 문서 작성" -- notes/HANDOFF.md` (push 금지)
4. **안내**: 사용자에게 `/new`로 새 세션을 열고 "인계 받아서 이어서 진행"이라고 입력하라고 알려 준다.

## 이어받기
새 세션은 `AGENTS.md` 규칙에 따라 `notes/HANDOFF.md` → `notes/PLAN.md` 순으로 읽고, 기준 커밋 이후 변경을 `git log`로 확인한 뒤 현재 상태를 3줄로 요약한다. 그다음 사용자의 요청을 따른다("이어서 진행"이면 다음 단계부터).
