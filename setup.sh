#!/usr/bin/env bash
# codex-kit 설치. 작업 폴더에서 실행한다: bash /tmp/kit/setup.sh
# 인터넷 접속, sudo, ~/.codex 수정, 파일 삭제, 덮어쓰기를 하지 않는다. 여러 번 실행해도 결과가 같다.
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

echo "[1/4] AGENTS.md"
if [ -s "$WORK/AGENTS.override.md" ]; then
  warn "AGENTS.override.md가 있어 Codex는 AGENTS.md 대신 그 파일을 읽습니다. 키트 규칙이 자동으로 적용되지 않으니, 필요하면 Codex에게 'AGENTS.md도 읽고 따라'라고 말하세요."
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

echo "[2/4] PLAN.md, DECISIONS.md"
for f in PLAN.md DECISIONS.md; do
  if [ -e "$WORK/$f" ]; then
    say "건너뜀: $f (이미 있음)"
  else
    cp "$KIT/templates/$f" "$WORK/$f" || fail "$f를 만들지 못함"
    say "복사함: $f"
  fi
done

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

echo
if [ "$warnings" -gt 0 ]; then
  echo "완료, [주의] ${warnings}건. 위 내용을 확인하세요. Codex를 다시 켜고(/quit -> codex) /skills 를 확인하세요."
  exit 2
fi
echo "완료. Codex를 다시 켜고(/quit -> codex) /skills 에서 스킬 4개를 확인하세요."
