#!/usr/bin/env bash
# Run the verification commands of docs/flow.config.yml (`commands`), in
# the order written, from the repository root, and print one line that
# /flow records as is in the Implementation Log:
#
#   Verification @ a1b2c3d: test pass, lint fail
#
# `+dirty` after the hash means uncommitted changes were verified, so the
# line does not stand for that commit. Each command's output goes to a log
# file (listed for failures), so only the failures need to be read.
#
#   verify.sh
#
# Exit: 0 all passed (or `commands: {}`), 1 something failed,
#       3 `commands` is missing from the config (an older /flow init).
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

top=$(flow_top)
conf=$(flow_config "$top")

if ! cfg_has commands "$conf"; then
  echo "docs/flow.config.yml に commands がありません（/flow init の再実行で追加できます）" >&2
  exit 3
fi

hash=$(git -C "$top" rev-parse --short HEAD 2>/dev/null || echo none)
[ -n "$(git -C "$top" status --porcelain 2>/dev/null)" ] && hash="${hash}+dirty"

logdir="$(git -C "$top" rev-parse --absolute-git-dir 2>/dev/null || echo "$top")/flow/verify"
mkdir -p "$logdir"

tab=$(printf '\t')
results=""; failed=""; ran=0
while IFS="$tab" read -r key command; do
  [ -n "$key" ] || continue
  ran=1
  log="$logdir/$key.log"
  if (cd "$top" && bash -c "$command") < /dev/null > "$log" 2>&1; then
    results="${results}${results:+, }$key pass"
  else
    results="${results}${results:+, }$key fail"
    failed="${failed}log $key: $log
"
  fi
done <<EOF
$(cfg_map commands "$conf")
EOF

if [ $ran -eq 0 ]; then
  echo "Verification @ $hash: 検証コマンドなし"
  exit 0
fi
echo "Verification @ $hash: $results"
[ -z "$failed" ] && exit 0
printf '%s' "$failed"
exit 1
