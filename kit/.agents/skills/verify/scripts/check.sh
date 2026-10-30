#!/usr/bin/env bash
# check.sh: 프로젝트를 감지해 가능한 점검을 모두 돌리고 결과를 요약한다.
# 사용: bash .agents/skills/verify/scripts/check.sh [--build] [--no-log]
#   --build   package.json의 build 스크립트도 실행한다
#   --no-log  notes/VERIFY.md에 기록하지 않는다
# 종료 코드: FAIL이 하나라도 있으면 1, 없으면 0
# 환경 변수: CHECK_TIMEOUT = 점검 하나당 제한 시간(초, 기본 600)
set -uo pipefail

BUILD=0
LOG=1
for arg in "$@"; do
  case "$arg" in
    --build) BUILD=1 ;;
    --no-log) LOG=0 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $arg (--help 참고)" >&2; exit 2 ;;
  esac
done

# 이 스크립트는 <저장소>/.agents/skills/verify/scripts/에 있다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$ROOT" || exit 2

LIMIT="${CHECK_TIMEOUT:-600}"
export CI=true                  # 테스트 러너가 watch 모드로 멈추지 않게
export PYTHONDONTWRITEBYTECODE=1
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

IN_GIT=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then IN_GIT=1; fi

PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done

PRUNE=(-name .git)
for d in node_modules .venv venv __pycache__ build dist .tox .mypy_cache .pytest_cache \
         .ruff_cache site-packages .next .ipynb_checkpoints .agents; do
  PRUNE+=(-o -name "$d")
done
# 이름과 상관없이 가상환경(pyvenv.cfg가 있는 폴더)은 모든 점검에서 뺀다
VENV_DIRS=()
while IFS= read -r f; do
  VENV_DIRS+=("$(dirname "${f#./}")")
done < <(find . -maxdepth 4 \( -name .git -o -name node_modules \) -prune -o -type f -name pyvenv.cfg -print 2>/dev/null)
for v in ${VENV_DIRS[@]+"${VENV_DIRS[@]}"}; do PRUNE+=(-o -path "./$v"); done

first_match() { find . \( "${PRUNE[@]}" \) -prune -o -type f \( "$@" \) -print -quit 2>/dev/null; }
count_match() { find . \( "${PRUNE[@]}" \) -prune -o -type f \( "$@" \) -print 2>/dev/null | wc -l | tr -d ' '; }

ROWS=()     # 상태<TAB>이름<TAB>설명
FAILED=()   # 이름<TAB>출력 파일
NFAIL=0
NWARN=0
add() {
  ROWS+=("$1"$'\t'"$2"$'\t'"$3")
  case "$1" in
    FAIL) NFAIL=$((NFAIL + 1)) ;;
    WARN) NWARN=$((NWARN + 1)) ;;
  esac
}
keep_log() { FAILED+=("$1"$'\t'"$2"); }
run() { # run <출력 파일> <명령...>
  local out="$1"
  shift
  timeout "$LIMIT" "$@" >"$out" 2>&1
  local rc=$?
  if [ "$rc" -eq 124 ]; then echo "(시간 초과: ${LIMIT}초)" >>"$out"; fi
  return "$rc"
}
safe_name() { printf '%s' "$1" | tr -c 'A-Za-z0-9' '_'; }

LANG_FOUND=0

# ---------- Python ----------
if [ -n "$(first_match -name '*.py')" ]; then
  LANG_FOUND=1
  if [ -z "$PY" ]; then
    add SKIP python "python 인터프리터 없음"
  else
    out="$TMPD/py-syntax"
    run "$out" "$PY" - <<'PYEOF'
import os
import sys

SKIP = {".git", "node_modules", ".venv", "venv", "__pycache__", "build", "dist", ".tox",
        ".mypy_cache", ".pytest_cache", ".ruff_cache", "site-packages", ".next",
        ".ipynb_checkpoints", ".agents"}
n, bad = 0, []
for root, dirs, files in os.walk("."):
    # 가상환경(pyvenv.cfg가 있는 폴더)은 이름과 상관없이 건너뛴다
    dirs[:] = [d for d in dirs
               if d not in SKIP and not os.path.exists(os.path.join(root, d, "pyvenv.cfg"))]
    for name in files:
        if not name.endswith(".py"):
            continue
        path = os.path.join(root, name)
        n += 1
        try:
            with open(path, "rb") as fh:
                compile(fh.read(), path, "exec", dont_inherit=True)
        except SyntaxError as e:
            bad.append(f"{path}:{e.lineno}: {e.msg}")
        except Exception as e:  # 인코딩 오류, 널 바이트 등
            bad.append(f"{path}: {type(e).__name__}: {e}")
print(f"{n} files, {len(bad)} errors")
for line in bad:
    print(line)
sys.exit(1 if bad else 0)
PYEOF
    rc=$?
    summary="$(grep -m1 ' files, ' "$out")"
    if [ "$rc" -eq 0 ]; then
      add PASS py-syntax "$summary"
    else
      add FAIL py-syntax "${summary:-exit $rc}"
      keep_log py-syntax "$out"
    fi

    if [ -z "$(first_match -name 'test_*.py' -o -name '*_test.py')" ]; then
      add WARN pytest "테스트 파일 없음(test_*.py): 핵심 로직 테스트를 추가할 것"
    elif ! "$PY" -c 'import pytest' >/dev/null 2>&1; then
      add SKIP pytest "미설치: $PY -m pip install pytest"
    else
      out="$TMPD/pytest"
      PYTEST_IGNORE=()
      for v in ${VENV_DIRS[@]+"${VENV_DIRS[@]}"}; do PYTEST_IGNORE+=("--ignore=$v"); done
      run "$out" "$PY" -m pytest -q -p no:cacheprovider ${PYTEST_IGNORE[@]+"${PYTEST_IGNORE[@]}"}
      rc=$?
      summary="$(grep -E '[0-9]+ (passed|failed|errors?|skipped)|no tests ran' "$out" | tail -n 1 | tr -d '=' | sed 's/^ *//; s/ *$//')"
      case "$rc" in
        0) add PASS pytest "${summary:-ok}" ;;
        5) add WARN pytest "수집된 테스트 없음" ;;
        *) add FAIL pytest "${summary:-exit $rc}"; keep_log pytest "$out" ;;
      esac
    fi

    RUFF=()
    if command -v ruff >/dev/null 2>&1; then
      RUFF=(ruff)
    elif "$PY" -m ruff --version >/dev/null 2>&1; then
      RUFF=("$PY" -m ruff)
    fi
    if [ ${#RUFF[@]} -eq 0 ]; then
      add SKIP ruff "미설치(선택): $PY -m pip install ruff"
    else
      out="$TMPD/ruff"
      RUFF_EXCLUDE=()
      if [ ${#VENV_DIRS[@]} -gt 0 ]; then
        RUFF_EXCLUDE=(--extend-exclude "$(IFS=,; echo "${VENV_DIRS[*]}")")
      fi
      run "$out" "${RUFF[@]}" check --no-cache ${RUFF_EXCLUDE[@]+"${RUFF_EXCLUDE[@]}"} \
        --select E9,F63,F7,F82 --output-format concise .
      rc=$?
      n="$(grep -cE ':[0-9]+:[0-9]+: ' "$out")"
      case "$rc" in
        0) add PASS ruff "치명적 오류 없음(문법, 정의 안 된 이름)" ;;
        1) add FAIL ruff "치명적 오류 ${n}개(문법, 정의 안 된 이름 등)"; keep_log ruff "$out" ;;
        *) add WARN ruff "실행 오류(exit $rc)"; keep_log ruff "$out" ;;
      esac
    fi
  fi
fi

nb="$(count_match -name '*.ipynb')"
if [ "$nb" -gt 0 ]; then
  LANG_FOUND=1
  add INFO notebook "노트북 ${nb}개: 핵심 로직은 .py로 빼서 테스트하는 것을 권장"
fi

# ---------- Node ----------
PKG_DIRS=()
while IFS= read -r f; do
  PKG_DIRS+=("$(dirname "$f")")
done < <(find . -maxdepth 3 \( -name node_modules -o -name .git \) -prune -o -type f -name package.json -print 2>/dev/null | sort)

if [ ${#PKG_DIRS[@]} -gt 0 ]; then
  LANG_FOUND=1
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    add SKIP node "node 또는 npm 없음"
  else
    for d in "${PKG_DIRS[@]}"; do
      label="node"
      if [ "$d" != "." ]; then label="node:${d#./}"; fi
      if [ ! -d "$d/node_modules" ]; then
        add SKIP "$label" "node_modules 없음: (cd $d && npm install) 후 다시 실행"
        continue
      fi
      if ! scripts="$(node -e '
        const p = require(process.argv[1]);
        const s = p.scripts || {};
        const out = [];
        for (const k of ["test", "typecheck", "lint", "build"]) {
          if (!s[k]) continue;
          if (k === "test" && /no test specified/.test(s[k])) continue;
          out.push(k);
        }
        console.log(out.join(" "));' "$ROOT/$d/package.json" 2>&1)"; then
        add FAIL "$label" "package.json을 읽지 못함"
        continue
      fi
      if [ -z "$scripts" ]; then
        add WARN "$label" "test 스크립트 없음: package.json에 test를 추가할 것"
      fi
      for s in $scripts; do
        if [ "$s" = "build" ] && [ "$BUILD" -eq 0 ]; then continue; fi
        out="$TMPD/$(safe_name "$label-$s")"
        run "$out" npm --prefix "$d" run -s "$s"
        rc=$?
        if [ "$rc" -eq 0 ]; then
          add PASS "$label $s" "npm run $s"
        elif [ "$s" = "lint" ]; then
          add WARN "$label $s" "npm run lint 실패(exit $rc)"
          keep_log "$label $s" "$out"
        else
          add FAIL "$label $s" "npm run $s 실패(exit $rc)"
          keep_log "$label $s" "$out"
        fi
      done
      case " $scripts " in
        *" typecheck "*) ;;
        *)
          if [ -f "$d/tsconfig.json" ] && [ -x "$d/node_modules/.bin/tsc" ]; then
            out="$TMPD/$(safe_name "$label-tsc")"
            run "$out" "$d/node_modules/.bin/tsc" --noEmit -p "$d"
            rc=$?
            if [ "$rc" -eq 0 ]; then
              add PASS "$label tsc" "타입 오류 없음"
            else
              add FAIL "$label tsc" "타입 오류 $(grep -c 'error TS' "$out")개"
              keep_log "$label tsc" "$out"
            fi
          fi
          ;;
      esac
    done
  fi
fi

# ---------- Go ----------
if [ -f go.mod ]; then
  LANG_FOUND=1
  if ! command -v go >/dev/null 2>&1; then
    add SKIP go "go 없음"
  else
    out="$TMPD/go-test"
    run "$out" go test ./...
    rc=$?
    if [ "$rc" -eq 0 ]; then
      add PASS go-test "go test ./..."
    else
      add FAIL go-test "go test 실패(exit $rc)"
      keep_log go-test "$out"
    fi
  fi
fi

if [ "$LANG_FOUND" -eq 0 ]; then
  add INFO lang "Python/Node/Go 프로젝트를 찾지 못함: 프로젝트의 테스트 명령을 직접 실행할 것"
fi

# ---------- 비밀키 노출 ----------
STRONG='sk-(proj-|svcacct-|admin-)?[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{30,}|xox[abprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
GENERIC="(api[_-]?key|secret|token|passw(or)?d)[\"']?[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9_./+=-]{16,}[\"']"
GG_EXCLUDE=(':(exclude).agents' ':(exclude)*.lock' ':(exclude)*-lock.json' ':(exclude)*.min.js')
GREP_EXCLUDE=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv
              --exclude-dir=__pycache__ --exclude-dir=.agents)
for v in ${VENV_DIRS[@]+"${VENV_DIRS[@]}"}; do
  GG_EXCLUDE+=(":(exclude)$v")
  GREP_EXCLUDE+=("--exclude-dir=$(basename "$v")")
done
scan() { # scan <정규식> [grep 옵션...] → "파일:줄" 목록 (값은 출력하지 않는다)
  local re="$1"
  shift
  if [ "$IN_GIT" -eq 1 ]; then
    git grep --untracked -I -n -E "$@" -e "$re" -- . "${GG_EXCLUDE[@]}" 2>/dev/null | cut -d: -f1,2
  else
    grep -rIn -E "$@" "${GREP_EXCLUDE[@]}" -e "$re" . 2>/dev/null | cut -d: -f1,2
  fi
}
hits="$(scan "$STRONG" | head -n 10 | tr '\n' ' ')"
if [ -n "$hits" ]; then
  add FAIL secrets "키 형태 문자열 발견(값은 숨김): $hits"
else
  ghits="$(scan "$GENERIC" -i | head -n 10 | tr '\n' ' ')"
  if [ -n "$ghits" ]; then
    add WARN secrets "하드코딩 의심: $ghits"
  else
    add PASS secrets "키 노출 패턴 없음"
  fi
fi
if [ "$IN_GIT" -eq 1 ]; then
  envs="$(git ls-files -- '.env' '*/.env' '.env.*' '*/.env.*' 2>/dev/null | grep -vE '\.(example|sample|template)$' | head -n 5 | tr '\n' ' ')"
  if [ -n "$envs" ]; then
    add FAIL env-file "커밋된 환경 파일: $envs→ git rm --cached <파일>"
  fi
fi

# ---------- git ----------
HEAD_ID="-"
if [ "$IN_GIT" -eq 1 ]; then
  HEAD_ID="$(git rev-parse --short HEAD 2>/dev/null || echo 'no-commit')"
  n="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$n" -eq 0 ]; then
    add INFO git "작업 트리 깨끗함"
  else
    add INFO git "커밋 안 된 변경 ${n}개"
  fi
fi

# ---------- 요약 ----------
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
echo
echo "== check.sh  $STAMP  HEAD $HEAD_ID =="
for r in ${ROWS[@]+"${ROWS[@]}"}; do
  IFS=$'\t' read -r st nm de <<<"$r"
  printf '%-5s %-18s %s\n' "$st" "$nm" "$de"
done
echo "-> FAIL $NFAIL, WARN $NWARN"

for f in ${FAILED[@]+"${FAILED[@]}"}; do
  IFS=$'\t' read -r nm path <<<"$f"
  echo
  echo "---- $nm: 출력 마지막 40줄 ----"
  tail -n 40 "$path"
done

if [ "$LOG" -eq 1 ] && [ -d notes ]; then
  {
    echo
    echo "### $STAMP · check.sh · HEAD $HEAD_ID"
    for r in ${ROWS[@]+"${ROWS[@]}"}; do
      IFS=$'\t' read -r st nm de <<<"$r"
      echo "- $st $nm: $de"
    done
  } >>notes/VERIFY.md
  echo
  echo "(notes/VERIFY.md에 기록함)"
fi

[ "$NFAIL" -eq 0 ]
