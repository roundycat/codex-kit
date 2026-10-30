#!/usr/bin/env bash
# codex-kit 설치: 과제 저장소에 AGENTS.md, 스킬 6개, notes 템플릿을 넣고 OpenAI Docs MCP를 등록한다.
# 사용: bash setup.sh [옵션] [설치 경로]   (자세한 건 --help)
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC="$KIT_DIR/kit"
MARK_START='<!-- codex-kit:start -->'
MARK_END='<!-- codex-kit:end -->'
MCP_NAME='openaiDeveloperDocs'
MCP_URL='https://developers.openai.com/mcp'
COMMIT_MSG='chore: add Codex work kit (AGENTS.md, skills, notes templates)'
GITIGNORE_ITEMS=(.venv/ venv/ __pycache__/ .pytest_cache/ .ruff_cache/ .mypy_cache/ node_modules/ .env .DS_Store)

DO_MCP=1
DO_COMMIT=1
DO_GIT_INIT=0
FORCE=0
TARGET=''

usage() {
  cat <<'EOF'
사용: bash setup.sh [옵션] [설치 경로]

설치 경로를 생략하면 현재 git 저장소의 루트에 설치한다.
과제 폴더에서 실행할 것. 몇 번 실행해도 결과가 같고, 과제 쪽 파일은 덮어쓰지 않는다.

옵션
  --no-mcp     OpenAI Docs MCP 등록을 건너뛴다
  --no-commit  설치한 파일을 자동 커밋하지 않는다
  --git-init   git 저장소가 아니면 새로 만든다
  --force      이미 설치된 키트 스킬과 AGENTS.md의 키트 블록을 최신으로 바꾼다
  -h, --help   이 도움말
EOF
}

ok()   { printf '  [ok]   %s\n' "$*"; }
skip() { printf '  [skip] %s\n' "$*"; }
warn() { printf '  [warn] %s\n' "$*"; }
die()  { printf '[error] %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --no-mcp) DO_MCP=0 ;;
    --no-commit) DO_COMMIT=0 ;;
    --git-init) DO_GIT_INIT=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; die "알 수 없는 옵션: $1" ;;
    *) [ -z "$TARGET" ] || die "설치 경로는 하나만 지정할 수 있다"; TARGET="$1" ;;
  esac
  shift
done

[ -f "$SRC/AGENTS.md" ] && [ -d "$SRC/.agents/skills" ] && [ -d "$SRC/notes" ] \
  || die "키트 파일이 없다: $SRC (clone이 끝까지 됐는지 확인)"

# ---------- 설치 위치 ----------
if [ -z "$TARGET" ]; then
  if top="$(LC_ALL=C git rev-parse --show-toplevel 2>&1)"; then
    TARGET="$top"
  elif grep -qi 'not a git repository' <<<"$top"; then
    here="$(pwd -P)"
    case "$here" in
      /|/tmp|"$(cd "$HOME" 2>/dev/null && pwd -P)")
        die "git 저장소가 아닌 $here 에서 실행했다. 과제 폴더로 이동한 뒤 다시 실행하거나 경로를 지정: bash $KIT_DIR/setup.sh <과제 폴더>" ;;
    esac
    TARGET="$here"
  else
    die "git이 이 폴더를 읽지 못했다. 과제 폴더가 맞는지 확인할 것. git의 메시지: $(head -n 3 <<<"$top" | tr '\n' ' ')"
  fi
fi
[ -d "$TARGET" ] || die "설치 경로가 없다: $TARGET"
TARGET="$(cd "$TARGET" && pwd -P)"

[ "$TARGET" != "/" ] || die "루트(/)에는 설치하지 않는다"
case "$TARGET/" in
  "$KIT_DIR"/*) die "키트 폴더 안에서 실행했다. 과제 폴더로 이동한 뒤 실행: cd <과제 폴더> && bash $KIT_DIR/setup.sh" ;;
esac

in_git() { git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

echo "codex-kit 설치 → $TARGET"

if ! in_git && [ "$DO_GIT_INIT" -eq 1 ]; then
  git -C "$TARGET" init -q
  ok "git init"
fi

WRITTEN=()   # 이번 실행에서 만들거나 바꾼 경로(설치 폴더 기준). 이것만 커밋한다.

# ---------- 1. 스킬 ----------
echo "[1/5] 스킬 (.agents/skills)"
mkdir -p "$TARGET/.agents/skills"
for dir in "$SRC/.agents/skills"/*/; do
  name="$(basename "$dir")"
  dest="$TARGET/.agents/skills/$name"
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    skip "\$$name 이미 있음 (최신으로 바꾸려면 --force)"
    continue
  fi
  rm -rf "$dest"
  cp -R "$SRC/.agents/skills/$name" "$dest"
  WRITTEN+=(".agents/skills/$name")
  ok "\$$name"
done
chmod +x "$TARGET/.agents/skills/verify/scripts/check.sh" 2>/dev/null || true

# ---------- 2. AGENTS.md ----------
echo "[2/5] AGENTS.md"
agents_file="$TARGET/AGENTS.md"
OVERRIDE=0
if [ -s "$TARGET/AGENTS.override.md" ]; then
  OVERRIDE=1
  warn "AGENTS.override.md가 있다. Codex는 이 폴더의 AGENTS.md 대신 그 파일을 읽는다. override는 건드리지 않고 키트 규칙은 AGENTS.md에 둔다"
fi
if [ ! -e "$agents_file" ]; then
  cp "$SRC/AGENTS.md" "$agents_file"
  WRITTEN+=("AGENTS.md")
  ok "AGENTS.md 생성"
elif grep -qxF "$MARK_START" "$agents_file"; then
  if [ "$FORCE" -eq 0 ]; then
    skip "AGENTS.md에 키트 블록이 이미 있음 (최신으로 바꾸려면 --force)"
  elif ! awk -v s="$MARK_START" -v e="$MARK_END" '$0 == s { a = 1 } a && $0 == e { found = 1 } END { exit !found }' "$agents_file"; then
    warn "AGENTS.md에 키트 블록의 끝 표시($MARK_END)가 없어 교체하지 않았다. 직접 확인할 것"
  else
    block="$(mktemp)"
    tmp="$(mktemp)"
    awk -v s="$MARK_START" -v e="$MARK_END" '$0 == s { p = 1 } p { print } p && $0 == e { exit }' "$SRC/AGENTS.md" >"$block"
    awk -v s="$MARK_START" -v e="$MARK_END" -v f="$block" '
      !done && $0 == s { while ((getline line < f) > 0) print line; close(f); skipping = 1; next }
      skipping && $0 == e { skipping = 0; done = 1; next }
      !skipping { print }
    ' "$agents_file" >"$tmp"
    cat "$tmp" >"$agents_file"
    rm -f "$tmp" "$block"
    WRITTEN+=("AGENTS.md")
    ok "AGENTS.md의 키트 블록만 최신으로 교체 (나머지 내용 유지)"
  fi
else
  { printf '\n'; cat "$SRC/AGENTS.md"; } >>"$agents_file"
  WRITTEN+=("AGENTS.md")
  ok "기존 AGENTS.md 원문은 그대로 두고 끝에 키트 규칙 추가"
fi
size="$(wc -c <"$agents_file" | tr -d ' ')"
if [ "$size" -gt 28000 ]; then
  warn "AGENTS.md가 ${size}바이트다. Codex의 기본 읽기 한도(32KiB)에 가까워 뒷부분이 잘릴 수 있다"
fi

# ---------- 3. notes 템플릿 ----------
echo "[3/5] notes 템플릿"
mkdir -p "$TARGET/notes"
for f in "$SRC/notes"/*.md; do
  name="$(basename "$f")"
  if [ -e "$TARGET/notes/$name" ]; then
    skip "notes/$name 이미 있음"
  else
    cp "$f" "$TARGET/notes/$name"
    WRITTEN+=("notes/$name")
    ok "notes/$name"
  fi
done

# ---------- 4. .gitignore ----------
echo "[4/5] .gitignore"
gi="$TARGET/.gitignore"
missing=()
for item in "${GITIGNORE_ITEMS[@]}"; do
  base="${item%/}"
  if [ -f "$gi" ] && grep -qxF -e "$item" -e "$base" -e "/$base" -e "/$base/" -e "**/$base" -e "**/$base/" "$gi"; then
    continue
  fi
  missing+=("$item")
done
if [ ${#missing[@]} -eq 0 ]; then
  skip "필요한 항목이 이미 있음"
else
  sep=''
  if [ -s "$gi" ] && [ "$(tail -c 1 "$gi" | wc -l | tr -d ' ')" -eq 0 ]; then sep=$'\n'; fi
  {
    printf '%s' "$sep"
    printf '# codex-kit: 가상환경, 캐시, 비밀 설정\n'
    printf '%s\n' "${missing[@]}"
  } >>"$gi"
  WRITTEN+=(".gitignore")
  ok "추가: ${missing[*]}"
fi

# ---------- 5. OpenAI Docs MCP ----------
# 등록은 공식 명령(codex mcp add)으로만 한다. 설정 파일은 직접 고치지 않는다.
echo "[5/5] OpenAI Docs MCP ($MCP_NAME)"
if [ "$DO_MCP" -eq 0 ]; then
  skip "--no-mcp"
else
  cfg="${CODEX_HOME:-$HOME/.codex}/config.toml"
  in_config() {
    [ -f "$cfg" ] && grep -Eq "^[[:space:]]*\[[[:space:]]*mcp_servers\.\"?$MCP_NAME\"?[[:space:]]*\]" "$cfg"
  }
  in_codex_list() {
    local listed
    listed="$(timeout 15 codex mcp list </dev/null 2>/dev/null || true)"
    grep -qF "$MCP_NAME" <<<"$listed"
  }
  if in_config; then
    skip "이미 등록됨"
  elif ! command -v codex >/dev/null 2>&1; then
    warn "이 터미널에 codex 명령이 없어 건너뛴다. MCP 없이도 진행할 수 있다(문서 조회는 내장 openai-docs 스킬)"
  elif err="$(timeout 30 codex mcp add "$MCP_NAME" --url "$MCP_URL" </dev/null 2>&1)"; then
    if in_config || in_codex_list; then
      ok "codex mcp add $MCP_NAME --url $MCP_URL"
    else
      warn "codex mcp add는 끝났지만 목록에서 확인되지 않는다. Codex에서 /mcp로 확인"
    fi
  else
    warn "MCP 등록 실패: $(head -n 2 <<<"$err" | tr '\n' ' ')"
    warn "설정 파일은 직접 고치지 않는다. MCP 없이 진행해도 된다(문서 조회는 내장 openai-docs 스킬)"
  fi
fi

# ---------- git ----------
echo "[git]"
if in_git; then
  if [ -z "$(git -C "$TARGET" config user.name || true)" ]; then
    git -C "$TARGET" config user.name 'candidate'
    ok "커밋 작성자 이름이 없어 이 저장소에만 'candidate'로 설정"
  fi
  if [ -z "$(git -C "$TARGET" config user.email || true)" ]; then
    git -C "$TARGET" config user.email 'candidate@localhost'
    ok "커밋 작성자 메일이 없어 이 저장소에만 'candidate@localhost'로 설정"
  fi
  if [ "$DO_COMMIT" -eq 0 ]; then
    skip "--no-commit"
  elif [ ${#WRITTEN[@]} -eq 0 ]; then
    skip "이번 실행에서 바뀐 파일이 없어 커밋하지 않음"
  else
    added=()
    for p in "${WRITTEN[@]}"; do
      if git -C "$TARGET" check-ignore -q -- "$p" 2>/dev/null; then
        warn "$p 는 .gitignore에 걸려 있어 커밋하지 않는다"
      elif git -C "$TARGET" add -- "$p" 2>/dev/null; then
        added+=("$p")
      else
        warn "git add 실패: $p"
      fi
    done
    if [ ${#added[@]} -eq 0 ]; then
      skip "커밋할 파일 없음"
    elif (cd "$TARGET" && git diff --cached --quiet -- "${added[@]}"); then
      skip "커밋할 변경 없음"
    elif (cd "$TARGET" && git commit -q -m "$COMMIT_MSG" -- "${added[@]}"); then
      ok "커밋: $(git -C "$TARGET" log -1 --format='%h %s')"
    else
      warn "커밋 실패: git status로 확인 (설치 자체는 끝남)"
    fi
  fi
else
  warn "git 저장소가 아니다. 과제 폴더가 맞는지 먼저 확인하고, 맞는데 커밋 기록이 필요하면: bash $KIT_DIR/setup.sh --git-init"
fi

cat <<'EOF'

설치 완료. 다음 순서:
  1) Codex 실행. 이미 켜져 있었다면 종료 후 다시 실행해야 규칙·스킬·MCP가 붙는다.
  2) $ 를 입력해 스킬 6개 확인, /mcp 로 openaiDeveloperDocs 확인
  3) 첫 메시지: $kickoff 남은 시간 <타이머의 남은 분>분

흐름: $kickoff → 단계마다 $verify → 맥락이 길면 $handoff 후 /new
      → 첫 E2E 뒤 $cross-check → $explain → 종료 20분 전 $wrap-up
EOF
if [ "$OVERRIDE" -eq 1 ]; then
  cat <<'EOF'

주의: AGENTS.override.md 때문에 키트 규칙이 자동으로 읽히지 않는다.
      매 세션(/new 포함) 첫 메시지에 "AGENTS.md도 읽고 그 규칙을 따라 줘"를 함께 입력할 것.
EOF
fi
