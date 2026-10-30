---
name: verify
description: 단계를 마칠 때의 검증과 커밋. check.sh로 문법·테스트·린트·타입·비밀값을 점검하고, 핵심 경로를 실제로 실행하고, notes/PROBLEM.md의 요구사항(R)·성공 기준(S)을 증거와 대조해 notes/VERIFY.md에 기록한 뒤 커밋한다. 검증, 테스트, 됐는지 확인, 단계 완료 시 사용.
---

# verify: 증거로 확인하기

명령과 출력이라는 증거 없이 "완료"라고 하지 않는다.

1. **자동 점검**: `bash .agents/skills/verify/scripts/check.sh`
   - 프로젝트를 감지해 파이썬 문법, pytest, ruff 치명적 오류, npm test·lint·typecheck, tsc, Go 테스트, 비밀값 노출을 점검하고 결과를 `notes/VERIFY.md`에 남긴다. `.venv`나 `venv`가 있으면 그 파이썬을 쓴다.
   - 빌드까지 보려면 `--build`를 붙인다. 점검 하나의 제한 시간은 기본 180초이고, 오래 걸리는 테스트는 `CHECK_TIMEOUT=600 bash .agents/skills/verify/scripts/check.sh`처럼 늘린다.
   - pytest나 ruff가 미설치로 나오면 필요한 것만 설치하고(가상환경이 있으면 그 안에) 다시 돌린다.
2. **실패하면**: 원인을 한 줄로 진단하고 최소한으로 고친 뒤 다시 돌린다. 같은 실패가 두 번 나오면 멈추고 가설과 선택지를 보고한다. 점검 스크립트의 오탐으로 보이면 스크립트를 고치지 말고 근거를 `notes/VERIFY.md`에 적고 보고한다.
3. **테스트 보강**: 이번 변경의 핵심 로직에 테스트가 없으면 추가한다(정상 1개 + 경계·예외 1~2개). 기대값은 요구사항에서 가져오고, 통과시키려고 바꾸지 않는다.
4. **실제 실행**: 핵심 경로를 실제 명령으로 한 번 돌린다.
   - 서버: `nohup <실행 명령> > /tmp/app.log 2>&1 & echo $! > /tmp/app.pid`로 띄우고, 2~3초 뒤 `curl -sS`로 핵심 엔드포인트 1~2개를 호출한 다음 `kill "$(cat /tmp/app.pid)"`로 끈다. 실패하면 `/tmp/app.log`를 본다.
   - CLI·스크립트: 샘플 입력으로 실행하고 출력 일부를 확인한다.
   - 데이터·ML: 지표를 실제로 계산하고 단순 기준선과 비교한다.
5. **R·S 대조**: 이번 단계와 관련된 R·S마다 충족/부분/미충족과 증거(명령, 수치, 파일:줄)를 `notes/VERIFY.md`에 추가하고, `notes/PROBLEM.md`의 상태 열을 갱신한다.
6. **기록과 커밋**: `notes/PLAN.md`의 상태를 갱신한다. `git status --short`로 확인하고 의도한 파일만 add 한 뒤 커밋한다.
   `git commit -m "<type>: <단계 번호와 무엇을, 왜> (verified: <핵심 증거>)"` (push 금지)

보고(짧게): 실행한 명령과 결과 / R·S별 상태 / 남은 시간과 다음 행동 / 남은 문제.
