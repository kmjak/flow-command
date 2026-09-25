#!/usr/bin/env bash
# SessionStart hook for /flow (matcher: compact|resume). After the
# conversation is compacted, the skill's SKILL.md is re-attached but a mode
# file read with Read (modes/dev.md) may survive only as a summary. When a
# /flow run is in progress here, this prints a reminder that Claude Code
# adds to the context: which run, its Status, and what to re-read.
# Prints nothing (and changes nothing) anywhere else.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"

input=$(cat)
cwd=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$cwd" ] && [ -d "$cwd" ] && cd "$cwd"

top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || true)

run=""
for f in "$top"/docs/flow/*/main.md; do
  [ -f "$f" ] || continue
  is_open_status "$(field "$f" Status)" || continue
  if [ -n "$branch" ] && [ "$(field "$f" Branch)" = "$branch" ]; then run=$f; break; fi
done
if [ -z "$run" ] && [ -f "$top/docs/flow/.active" ]; then
  f="$top/docs/flow/$(cat "$top/docs/flow/.active")/main.md"
  [ -f "$f" ] && is_open_status "$(field "$f" Status)" && run=$f
fi
[ -n "$run" ] || exit 0

id=${run%/main.md}; id=${id##*/}
cat <<EOF
[/flow] この作業ディレクトリでは /flow dev の run ${id} が進行中です（Status: $(field "$run" Status)、Branch: $(field "$run" Branch)）。
会話が要約・再開されたため、手順書の細部が失われている可能性があります。/flow の作業を続ける前に、次を Read し直してください:
- ${here%/scripts}/modes/dev.md
- ${run#$top/}
EOF
exit 0
