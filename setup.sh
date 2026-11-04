#!/usr/bin/env bash
# codex-kit 설치. 작업 폴더에서 실행한다: bash /tmp/kit/setup.sh
# 인터넷 접속, sudo, ~/.codex 수정, 파일 삭제를 하지 않는다. 기존 파일은 덮어쓰지 않고, 기존 AGENTS.md 뒤와 .gitignore 앞에 덧붙이기만 한다.
# 여러 번 실행해도 결과가 같다.
# 종료 코드: 0 = 완료, 1 = 작업 폴더 파일 설치 실패, 2 = 완료했지만 [주의] 있음
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(pwd)"
SKILLS_DIR="${HOME}/.agents/skills"
MARK="codex-kit:rules"
warnings=0

if [ "$WORK" = "$KIT" ]; then
  echo "키트 폴더가 아니라 작업 폴더에서 실행하세요. 예: cd ~ && bash $KIT/setup.sh" >&2
  exit 1
fi

say() { printf '  %s\n' "$*"; }
warn() { printf '  [주의] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '  [실패] %s\n' "$*" >&2; exit 1; }

# 파일이 줄바꿈 없이 끝나면 덧붙이기 전에 줄바꿈을 넣는다
ensure_newline() {
  if [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then
    printf '\n' >> "$1"
  fi
}

# 과제 README가 없는 폴더면 작업 폴더를 잘못 골랐을 수 있다 (예: 홈에서 실행했는데 과제는 ~/workspace)
if ! ls -A "$WORK" 2>/dev/null | grep -qi '^readme'; then
  warn "이 폴더에 README가 없습니다. 과제 README.md가 있는 작업 폴더에서 실행했는지 확인하세요: $WORK"
fi

echo "[1/4] AGENTS.md"
# Codex는 override가 파일이기만 하면(빈 파일이어도) 같은 폴더의 AGENTS.md를 읽지 않는다
if [ -e "$WORK/AGENTS.override.md" ]; then
  warn "AGENTS.override.md가 있어(빈 파일이어도) Codex는 이 폴더의 AGENTS.md를 읽지 않습니다. 키트 규칙이 적용되지 않으니 Codex에게 'AGENTS.md도 읽고 따라'라고 말하세요."
fi
if [ ! -e "$WORK/AGENTS.md" ]; then
  cp "$KIT/AGENTS.md" "$WORK/AGENTS.md" || fail "AGENTS.md를 만들지 못함"
  say "복사함"
elif grep -qF "$MARK" "$WORK/AGENTS.md"; then
  say "건너뜀: 키트 규칙이 이미 들어 있음"
else
  ensure_newline "$WORK/AGENTS.md"
  { printf '\n'; cat "$KIT/AGENTS.md"; } >> "$WORK/AGENTS.md" || fail "AGENTS.md에 덧붙이지 못함"
  say "기존 AGENTS.md 뒤에 키트 규칙을 덧붙임 (기존 내용이 우선)"
fi
# Codex는 AGENTS.md를 32,768바이트까지만 읽는다. 넘으면 뒤에 붙은 키트 규칙이 잘린다.
if [ -f "$WORK/AGENTS.md" ] && [ "$(wc -c < "$WORK/AGENTS.md")" -gt 32768 ]; then
  warn "AGENTS.md가 32,768바이트를 넘어 Codex가 뒷부분(키트 규칙)을 잘라 읽습니다. Codex에게 '$KIT/AGENTS.md 읽고 따라'라고 말하세요."
fi

echo "[2/4] PLAN.md, INTERVIEW.md, DECISIONS.md, CONTRACT.md, work/_template.md"
for f in PLAN.md INTERVIEW.md DECISIONS.md CONTRACT.md; do
  if [ ! -e "$WORK/$f" ]; then
    cp "$KIT/templates/$f" "$WORK/$f" || fail "$f를 만들지 못함"
    say "복사함: $f"
  elif cmp -s "$KIT/templates/$f" "$WORK/$f"; then
    say "건너뜀: $f (키트 양식이 이미 있음)"
  else
    warn "$f가 이미 있어 덮어쓰지 않았습니다. 과제가 준 파일이면 Codex가 AGENTS.md '과제가 준 파일과 겹칠 때' 규칙대로 이 파일 형식을 우선합니다."
  fi
done
# 세션마다 work/<역할>.md를 이 양식으로 만든다
if [ -e "$WORK/work" ] && [ ! -d "$WORK/work" ]; then
  warn "work가 폴더가 아니라 파일이라 세션 기록 양식을 놓지 못했습니다. lead가 세션 기록 폴더를 따로 정해 PLAN.md '기록 위치'에 적으세요. 양식은 $KIT/templates/work.md 에 있습니다."
elif [ ! -e "$WORK/work/_template.md" ]; then
  if mkdir -p "$WORK/work" && cp "$KIT/templates/work.md" "$WORK/work/_template.md"; then
    say "복사함: work/_template.md"
  else
    warn "work/_template.md를 만들지 못했습니다. 양식은 $KIT/templates/work.md 에 있습니다."
  fi
elif cmp -s "$KIT/templates/work.md" "$WORK/work/_template.md"; then
  say "건너뜀: work/_template.md (키트 양식이 이미 있음)"
else
  warn "work/_template.md가 이미 있어 덮어쓰지 않았습니다. 키트 양식은 $KIT/templates/work.md 에 있습니다."
fi
# 이름은 달라도 계획·결정·메모 역할일 수 있는 문서 (숨김 폴더 제외, 세 단계 깊이까지)
similar="$(cd "$WORK" && find . -maxdepth 3 -type f \( -iname '*.md' -o -iname '*.txt' \) \
  \( -iname '*plan*' -o -iname '*todo*' -o -iname '*note*' -o -iname '*decision*' -o -iname 'adr*' -o -iname '*worklog*' \
     -o -iname '*task*' -o -iname '*require*' -o -iname '*handoff*' -o -iname '*contract*' -o -iname '*계획*' -o -iname '*결정*' -o -iname '*메모*' \) \
  -not -iname 'requirements*.txt' -not -path './.*' -not -path './node_modules/*' -not -path './work/*' 2>/dev/null \
  | sed 's|^\./||' | grep -vxE 'PLAN\.md|INTERVIEW\.md|DECISIONS\.md|CONTRACT\.md' | sort | tr '\n' ' ')"
if [ -n "$similar" ]; then
  warn "계획·결정·메모 역할일 수 있는 파일이 있습니다: ${similar}Codex가 시작할 때 확인하고 PLAN.md '기록 위치'를 정합니다."
fi

echo "[3/4] .gitignore"
if [ ! -e "$WORK/.gitignore" ]; then
  cp "$KIT/templates/gitignore" "$WORK/.gitignore" || fail ".gitignore를 만들지 못함"
  say "복사함"
else
  # 빠진 줄만 맨 앞에 넣는다. 기존 규칙(예외 포함)이 뒤에 오므로 기존 규칙이 우선한다.
  missing="$(mktemp)" || fail "임시 파일을 만들지 못함"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    grep -qxF -- "$line" "$WORK/.gitignore" || printf '%s\n' "$line" >> "$missing"
  done < "$KIT/templates/gitignore"
  added=$(wc -l < "$missing" | tr -d ' ')
  if [ "$added" -gt 0 ]; then
    merged="$(mktemp)" || fail "임시 파일을 만들지 못함"
    { printf '# codex-kit (아래 기존 규칙이 우선)\n'; cat "$missing"; cat "$WORK/.gitignore"; } > "$merged"
    cat "$merged" > "$WORK/.gitignore" || fail ".gitignore를 고치지 못함"
    rm -f "$merged"
  fi
  rm -f "$missing"
  say "기존 .gitignore 맨 앞에 빠진 줄 ${added}개 추가 (기존 규칙이 우선)"
fi
# 과제 .gitignore가 기록 파일까지 무시하면 커밋할 수 없다
if git -C "$WORK" rev-parse --git-dir >/dev/null 2>&1; then
  ignored="$(cd "$WORK" && git check-ignore PLAN.md INTERVIEW.md DECISIONS.md CONTRACT.md work/lead.md 2>/dev/null | tr '\n' ' ')"
  if [ -n "$ignored" ]; then
    warn "과제 .gitignore가 기록 파일을 무시합니다: ${ignored}이 줄은 lead 첫 메시지에 붙이세요. lead가 한 번 묻습니다. README에 따로 정한 것이 없으면, 추천은 기록 파일만 추적되게 과제 .gitignore를 최소한으로 고쳐 커밋하는 것입니다(Codex는 git add -f를 쓰지 않습니다)."
  fi
fi

echo "[4/4] 스킬 -> $SKILLS_DIR"
if ! mkdir -p "$SKILLS_DIR" 2>/dev/null; then
  warn "스킬 폴더를 만들지 못함. 스킬 없이 진행하고, 필요할 때 Codex에게 '$KIT/skills/<이름>/SKILL.md 읽고 그 절차대로 해'라고 하세요."
else
  for src in "$KIT"/skills/*/; do
    name="$(basename "$src")"
    dest="$SKILLS_DIR/$name"
    if [ ! -e "$dest" ]; then
      if cp -R "$src" "$dest" 2>/dev/null; then
        say "설치: $name"
      else
        warn "설치 실패: $name. 필요할 때 Codex에게 '$KIT/skills/$name/SKILL.md 읽고 그 절차대로 해'라고 하세요."
      fi
    elif [ ! -f "$dest/SKILL.md" ]; then
      warn "$name: 같은 이름 폴더가 있지만 SKILL.md가 없어 키트 스킬이 적용되지 않습니다. 덮어쓰지 않았습니다."
    elif cmp -s "$src/SKILL.md" "$dest/SKILL.md"; then
      say "건너뜀: $name (같은 내용이 이미 있음)"
    else
      warn "$name: 내용이 다른 같은 이름 스킬이 이미 있어 덮어쓰지 않았습니다. 키트 버전은 $KIT/skills/$name/SKILL.md 에 있습니다."
    fi
  done
fi
# Codex는 ~/.agents/skills 말고도 작업 폴더부터 저장소 맨 위까지의 .agents/skills·.codex/skills와
# $CODEX_HOME/skills도 읽는다. 같은 이름이 두 곳에 있으면 $이름 호출이 무시된다.
home_skills="$(cd "$SKILLS_DIR" 2>/dev/null && pwd -P)"
seen_dirs="$home_skills"
check_skill_dir() {
  [ -d "$1" ] || return 0
  local rd
  rd="$(cd "$1" && pwd -P)" || return 0
  printf '%s\n' "$seen_dirs" | grep -qxF -- "$rd" && return 0
  seen_dirs="$seen_dirs
$rd"
  for src in "$KIT"/skills/*/; do
    name="$(basename "$src")"
    if [ -f "$rd/$name/SKILL.md" ]; then
      warn "$name: $rd 에도 같은 이름 스킬이 있어 '\$$name'으로 부르면 무시됩니다. 대신 Codex에게 '$KIT/skills/$name/SKILL.md 읽고 그 절차대로 해'라고 하세요."
    fi
  done
}
top="$(git -C "$WORK" rev-parse --show-toplevel 2>/dev/null || pwd -P)"
d="$(pwd -P)"
while :; do
  check_skill_dir "$d/.agents/skills"
  check_skill_dir "$d/.codex/skills"
  [ "$d" = "$top" ] && break
  parent="$(dirname "$d")"
  [ "$parent" = "$d" ] && break
  d="$parent"
done
check_skill_dir "${CODEX_HOME:-$HOME/.codex}/skills"

echo
if [ "$warnings" -gt 0 ]; then
  echo "완료, [주의] ${warnings}건. 위 [주의] 줄을 선택해 Ctrl+C로 복사하고 Codex 첫 메시지에 Ctrl+Shift+V로 붙여 넣으세요(Codex는 이 출력을 보지 못합니다). Codex를 다시 켜고(/quit -> codex) /skills 를 확인하세요."
  exit 2
fi
echo "완료. Codex를 다시 켜고(/quit -> codex) /skills 에서 스킬 6개를 확인하세요."
