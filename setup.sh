#!/usr/bin/env bash
# codex-kit 설치. 작업 폴더에서 실행한다: bash /tmp/kit/setup.sh
# 인터넷 접속, sudo, ~/.codex 수정, 파일 삭제, 덮어쓰기를 하지 않는다. 여러 번 실행해도 결과가 같다.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(pwd)"
SKILLS_DIR="${HOME}/.agents/skills"
MARK="codex-kit:rules"

if [ "$WORK" = "$KIT" ]; then
  echo "키트 폴더가 아니라 작업 폴더에서 실행하세요. 예: cd ~ && bash $KIT/setup.sh" >&2
  exit 1
fi

say() { printf '  %s\n' "$*"; }

# 파일이 줄바꿈 없이 끝나면 덧붙이기 전에 줄바꿈을 넣는다
ensure_newline() {
  if [ -s "$1" ] && [ -n "$(tail -c 1 "$1")" ]; then
    printf '\n' >> "$1"
  fi
}

echo "[1/4] 스킬 -> $SKILLS_DIR"
mkdir -p "$SKILLS_DIR"
for src in "$KIT"/skills/*/; do
  name="$(basename "$src")"
  if [ -e "$SKILLS_DIR/$name" ]; then
    say "건너뜀: $name (이미 있음)"
  else
    cp -R "$src" "$SKILLS_DIR/$name"
    say "설치: $name"
  fi
done

echo "[2/4] AGENTS.md"
if [ ! -e "$WORK/AGENTS.md" ]; then
  cp "$KIT/AGENTS.md" "$WORK/AGENTS.md"
  say "복사함"
elif grep -qF "$MARK" "$WORK/AGENTS.md"; then
  say "건너뜀: 키트 규칙이 이미 들어 있음"
else
  ensure_newline "$WORK/AGENTS.md"
  { printf '\n'; cat "$KIT/AGENTS.md"; } >> "$WORK/AGENTS.md"
  say "기존 AGENTS.md 뒤에 키트 규칙을 덧붙임 (기존 내용은 그대로)"
fi

echo "[3/4] PLAN.md, DECISIONS.md"
for f in PLAN.md DECISIONS.md; do
  if [ -e "$WORK/$f" ]; then
    say "건너뜀: $f (이미 있음)"
  else
    cp "$KIT/templates/$f" "$WORK/$f"
    say "복사함: $f"
  fi
done

echo "[4/4] .gitignore"
if [ ! -e "$WORK/.gitignore" ]; then
  cp "$KIT/templates/gitignore" "$WORK/.gitignore"
  say "복사함"
else
  ensure_newline "$WORK/.gitignore"
  added=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    if ! grep -qxF -- "$line" "$WORK/.gitignore"; then
      printf '%s\n' "$line" >> "$WORK/.gitignore"
      added=$((added + 1))
    fi
  done < "$KIT/templates/gitignore"
  say "기존 .gitignore에 빠진 줄 ${added}개 추가"
fi

echo
echo "완료. Codex를 다시 켜고(/quit -> codex) /skills 에서 스킬 4개를 확인하세요."
