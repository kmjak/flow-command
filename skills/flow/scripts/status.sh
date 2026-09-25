#!/usr/bin/env bash
# Snapshot of /flow for SKILL.md: injected with !`...` when /flow starts, so
# the settings and the open runs are in context before anything is read.
# Always exits 0: a failing injected command would abort the skill.
set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

top=$(flow_top)
conf=$(flow_config "$top")

echo "- リポジトリ: ${top}"
if git -C "$top" rev-parse --git-dir >/dev/null 2>&1; then
  echo "- 現在のブランチ: $(git -C "$top" symbolic-ref --short -q HEAD 2>/dev/null || echo '(detached)')"
else
  echo "- git リポジトリではない"
fi

if [ -f "$conf" ]; then
  gates=$(cfg_list gates "$conf" | paste -sd, -)
  echo "- 設定（docs/flow.config.yml）: language=$(cfg language "$conf")" \
    "tracker=$(cfg ticket.tracker "$conf")" \
    "host=$(cfg repository.host "$conf")" \
    "default_branch=$(cfg repository.default_branch "$conf")" \
    "review.required=$(cfg review.required "$conf")" \
    "gates=${gates:-（未設定）}"
else
  echo "- docs/flow.config.yml が無い（/flow init が未実行）"
fi

open=""
for f in "$top"/docs/flow/*/main.md; do
  [ -f "$f" ] || continue
  s=$(field "$f" Status)
  is_open_status "$s" || continue
  id=${f%/main.md}; id=${id##*/}
  open="${open}  - ${id}: Status ${s}、Branch $(field "$f" Branch)
"
done
if [ -n "$open" ]; then
  echo "- 進行中の run:"
  printf '%s' "$open"
else
  echo "- 進行中の run: なし"
fi
exit 0
