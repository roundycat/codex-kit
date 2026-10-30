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

설치 경로를 생략하면 현재 git 저장소의 루트(git이 아니면 현재 폴더)에 설치한다.
과제 폴더에서 실행할 것. 몇 번 실행해도 결과가 같다.

옵션
  --no-mcp     OpenAI Docs MCP 등록을 건너뛴다
  --no-commit  설치한 파일을 자동 커밋하지 않는다
  --git-init   git 저장소가 아니면 새로 만든다
  --force      이미 설치된 키트 스킬과 AGENTS.md의 키트 블록을 최신으로 덮어쓴다
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

if [ -z "$TARGET" ]; then
  TARGET="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
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
  ok "\$$name"
done
chmod +x "$TARGET/.agents/skills/verify/scripts/check.sh" 2>/dev/null || true

# ---------- 2. AGENTS.md ----------
echo "[2/5] AGENTS.md"
agents_file="$TARGET/AGENTS.md"
if [ -s "$TARGET/AGENTS.override.md" ]; then
  agents_file="$TARGET/AGENTS.override.md"
  warn "AGENTS.override.md가 있으면 Codex는 같은 폴더의 AGENTS.md를 읽지 않는다 → 키트 규칙을 AGENTS.override.md 끝에 붙인다"
fi
agents_name="$(basename "$agents_file")"
if [ ! -e "$agents_file" ]; then
  cp "$SRC/AGENTS.md" "$agents_file"
  ok "$agents_name 생성"
elif grep -qF "$MARK_START" "$agents_file"; then
  if [ "$FORCE" -eq 1 ]; then
    tmp="$(mktemp)"
    awk -v s="$MARK_START" -v e="$MARK_END" -v f="$SRC/AGENTS.md" '
      $0 == s { while ((getline line < f) > 0) print line; close(f); skipping = 1; next }
      $0 == e { skipping = 0; next }
      !skipping { print }
    ' "$agents_file" >"$tmp"
    cat "$tmp" >"$agents_file"
    rm -f "$tmp"
    ok "$agents_name 안의 키트 블록을 최신으로 교체 (나머지 내용 유지)"
  else
    skip "$agents_name에 키트 블록이 이미 있음 (최신으로 바꾸려면 --force)"
  fi
else
  { printf '\n'; cat "$SRC/AGENTS.md"; } >>"$agents_file"
  ok "기존 $agents_name 원문은 그대로 두고 끝에 키트 규칙 추가"
fi
size="$(wc -c <"$agents_file" | tr -d ' ')"
if [ "$size" -gt 28000 ]; then
  warn "$agents_name가 ${size}바이트다. Codex의 기본 읽기 한도(32KiB)에 가까워 뒷부분이 잘릴 수 있다"
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
  ok "추가: ${missing[*]}"
fi

# ---------- 5. OpenAI Docs MCP ----------
echo "[5/5] OpenAI Docs MCP ($MCP_NAME)"
if [ "$DO_MCP" -eq 0 ]; then
  skip "--no-mcp"
else
  cfg_dir="${CODEX_HOME:-$HOME/.codex}"
  cfg="$cfg_dir/config.toml"
  mkdir -p "$cfg_dir" 2>/dev/null || true   # CODEX_HOME 폴더가 없으면 codex mcp add가 실패한다
  has_codex=0
  if command -v codex >/dev/null 2>&1; then has_codex=1; fi
  in_config() {
    [ -f "$cfg" ] && grep -Eq "^[[:space:]]*\[[[:space:]]*mcp_servers\.\"?$MCP_NAME\"?[[:space:]]*\]" "$cfg"
  }
  in_codex_list() {
    [ "$has_codex" -eq 1 ] || return 1
    local listed
    listed="$(timeout 30 codex mcp list </dev/null 2>/dev/null || true)"
    grep -qF "$MCP_NAME" <<<"$listed"
  }
  append_mcp_table() {
    mkdir -p "$cfg_dir" 2>/dev/null || return 1
    local sep=''
    if [ -s "$cfg" ]; then sep=$'\n'; fi
    printf '%s[mcp_servers.%s]\nurl = "%s"\n' "$sep" "$MCP_NAME" "$MCP_URL" >>"$cfg" 2>/dev/null
  }
  if in_config || in_codex_list; then
    skip "이미 등록됨"
  elif [ "$has_codex" -eq 1 ] \
       && timeout 60 codex mcp add "$MCP_NAME" --url "$MCP_URL" </dev/null >/dev/null 2>&1; then
    ok "codex mcp add $MCP_NAME --url $MCP_URL"
  elif in_config || in_codex_list; then
    ok "등록됨"
  elif append_mcp_table; then
    ok "$cfg에 직접 추가"
  else
    warn "MCP 등록 실패 ($cfg에 쓸 수 없음). MCP 없이도 과제는 진행 가능"
  fi
  if [ "$has_codex" -eq 1 ]; then
    if in_codex_list; then
      ok "codex mcp list에서 확인됨"
    else
      warn "codex mcp list에 보이지 않는다. Codex를 다시 실행한 뒤 /mcp로 확인 (안 붙어도 과제는 진행 가능)"
    fi
  else
    warn "이 터미널에서 codex 명령을 찾지 못했다. Codex 화면에서 /mcp로 연결을 확인"
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
  if [ "$DO_COMMIT" -eq 1 ]; then
    paths=()
    for p in "$agents_name" .agents/skills notes .gitignore; do
      if [ -e "$TARGET/$p" ]; then paths+=("$p"); fi
    done
    if ! (cd "$TARGET" && git add -- "${paths[@]}"); then
      warn "git add 실패: 직접 확인"
    elif (cd "$TARGET" && git diff --cached --quiet -- "${paths[@]}"); then
      skip "커밋할 변경 없음"
    elif (cd "$TARGET" && git commit -q -m "$COMMIT_MSG" -- "${paths[@]}"); then
      ok "커밋: $(git -C "$TARGET" log -1 --format='%h %s')"
    else
      warn "커밋 실패: git status로 확인 (설치 자체는 끝남)"
    fi
  else
    skip "--no-commit"
  fi
else
  warn "git 저장소가 아니다. 커밋 기록을 남기려면: bash $KIT_DIR/setup.sh --git-init"
fi

cat <<'EOF'

설치 완료. 다음 순서:
  1) Codex 실행. 이미 켜져 있었다면 종료 후 다시 실행해야 MCP가 붙는다.
  2) /mcp 로 openaiDeveloperDocs 연결 확인, $ 를 입력해 스킬 6개 확인
  3) $kickoff

흐름: $kickoff → 단계마다 $verify → 맥락이 길면 $handoff 후 /new
      → 약 90분에 새 세션에서 $cross-check → $explain → 160분에 $wrap-up
      → 마지막 5분은 notes/DECISIONS.md 리스크 표를 직접 읽기
EOF
