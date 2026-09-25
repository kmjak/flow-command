#!/usr/bin/env bash
# PreToolUse(Bash) guard for /flow, registered in ~/.claude/settings.json
# (/flow init walks through it). It runs for every Bash call in every
# project, and acts only on a branch that a /flow run owns
# (docs/flow/*/main.md whose Branch is the current branch). There it:
#   deny  git push --force (any form), and gh pr create whose body does not
#         close the run's issue (Closes #N)
#   ask   every other push / PR creation, whatever the phase, so the user
#         confirms on the permission prompt even when git push is on the
#         allow list; the phase is shown in the prompt
# Detection is deliberately loose (git + push, gh + pr create, gh api +
# pulls, quotes stripped) because a false positive only costs a prompt.
# It is accident prevention, not a sandbox: any command Claude can run can
# be written so that it is not recognised.
#
# Output: nothing + exit 0 = no decision (normal permission flow).
# exit 2 = deny; stderr goes to Claude. JSON on stdout = ask; the reason
# goes to the user only.
set -uo pipefail

input=$(cat)

# Cheap pre-filter on the raw JSON: most commands never reach git or jq.
case "$input" in
  *push*|*create*|*pulls*) ;;
  *) exit 0 ;;
esac

deny() {
  {
    echo "[/flow guard] $1"
    echo "この操作は /flow のルールでブロックされました。コマンドを言い換えて回避せず、理由をユーザーに伝えて指示を待ってください。"
  } >&2
  exit 2
}

ask() {
  local reason
  reason=$(printf '[/flow] %s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

cwd=$PWD
if [ $have_jq -eq 1 ]; then
  c=$(printf '%s' "$input" | jq -r '.cwd // empty')
  [ -n "$c" ] && cwd=$c
fi

# Find the /flow run that owns the current branch. No jq needed, so a
# missing jq never affects repos or branches outside /flow.
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null) || exit 0

field() { # field <main.md> <name> -> value from the header table
  awk -F'|' -v k="$2" '{ key=$2; gsub(/^[ \t]+|[ \t]+$/, "", key) }
    key == k { v=$3; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit }' "$1"
}

state=""
for f in "$top"/docs/flow/*/main.md; do
  [ -f "$f" ] || continue
  if [ "$(field "$f" Branch)" = "$branch" ]; then state=$f; break; fi
done
[ -n "$state" ] || exit 0

status=$(field "$state" Status)
base=$(field "$state" Base)
where="ブランチ ${branch}、Status ${status}（${state#$top/}）"

if [ $have_jq -eq 0 ]; then
  ask "jq が無いため、このコマンドが push / PR 作成かを詳しく判定できません。${where}。jq をインストールすると判定できます。"
fi

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

# Precise forms: a command segment starts at line start or after ; & | ( {
# and may be prefixed by `command`, env assignments, or git/gh options.
seg_start='(^|[;&|({])[[:space:]]*(command[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
git_push_re="${seg_start}git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+push([[:space:]]|$)"
gh_pr_create_re="${seg_start}gh([[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+pr[[:space:]]+create([[:space:]]|$)"

# Loose forms: words anywhere once quotes and backslashes are removed, so
# bash -c "git push", eval, env, "git" push and gh api .../pulls are caught.
# `stash push` is local and dropped first.
norm=$(printf '%s\n' "$cmd" | tr -d "\"'\\\\" | sed -E 's/stash[[:space:]]+push//g')
has_word() { printf '%s\n' "$norm" | grep -Eq "(^|[^[:alnum:]_-])$1([^[:alnum:]_-]|$)"; }

is_pr_create=0; precise_pr=0
printf '%s\n' "$cmd" | grep -Eq "$gh_pr_create_re" && { is_pr_create=1; precise_pr=1; }
if has_word gh && { { has_word pr && has_word create; } || { has_word api && has_word pulls; }; }; then
  is_pr_create=1
fi
is_push=0; precise_push=0
printf '%s\n' "$cmd" | grep -Eq "$git_push_re" && { is_push=1; precise_push=1; }
has_word git && has_word push && is_push=1
[ $is_push -eq 1 ] || [ $is_pr_create -eq 1 ] || exit 0

# deny: force push, in any form, inside the push segment(s).
if [ $is_push -eq 1 ]; then
  push_args=$(printf '%s\n' "$norm" | grep -Eo 'push([[:space:]][^;&|]*)?' || true)
  if printf '%s\n' "$push_args" \
      | grep -Eq '(^|[[:space:]])(--force|--force-with-lease(=[^[:space:]]*)?|--force-if-includes|-[A-Za-z]*f[A-Za-z]*)([[:space:]]|$)|[[:space:]]\+[^[:space:]]'; then
    deny "force push は禁止です（ブランチ ${branch}）。履歴の書き換えが本当に必要なら、ユーザー自身が ! git push --force-with-lease などで実行してください。"
  fi
fi

# deny: the PR must close the run's issue. Only the precise form has a body
# we can read; anything else is left to the prompt.
issue=$(field "$state" Issue | tr -dc '0-9')
if [ -z "$issue" ]; then
  ticket=$(field "$state" Ticket)
  [ -n "$ticket" ] && [ -f "$top/$ticket" ] \
    && issue=$(grep -Eo -m1 '^Issue:[[:space:]]*#[0-9]+' "$top/$ticket" | tr -dc '0-9')
fi
if [ $precise_pr -eq 1 ] && [ -n "$issue" ]; then
  haystack=$cmd
  body_file=$(printf '%s\n' "$cmd" | grep -Eo '(--body-file|-F)([[:space:]]+|=)[^[:space:];&|]+' | head -1 \
    | sed -E 's/^(--body-file|-F)([[:space:]]+|=)//; s/^["'\'']//; s/["'\'']$//')
  if [ -n "$body_file" ]; then
    case "$body_file" in /*) ;; *) body_file="$cwd/$body_file" ;; esac
    [ -f "$body_file" ] && haystack="$haystack
$(cat "$body_file")"
  fi
  if ! printf '%s\n' "$haystack" | grep -Eiq "(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#${issue}([^0-9]|$)"; then
    deny "PR 本文に \"Closes #${issue}\" がありません。issue #${issue} を閉じる紐付けを本文に入れてから作成してください（--fill や本文なしでは作成できません）。"
  fi
fi

# ask: everything else that leaves the machine. The phase goes in the prompt.
if [ $is_pr_create -eq 1 ]; then what="PR 作成"; obj="PR 作成を"; else what="push"; obj="push を"; fi
detail="${where}、Base ${base:-—}"
[ $is_pr_create -eq 1 ] && [ -n "$issue" ] && detail="${detail}、Closes #${issue}"
pr_url=$(awk '/^## PR/{p=1; next} /^## /{p=0} p' "$state" | grep -Eo -m1 'https://[^[:space:]]+/pull/[0-9]+' || true)

case "$status" in
  pr:awaiting-approval)
    note="PR ゲート：${obj}承認しますか？" ;;
  pr:awaiting-review|pr:in-progress)
    if [ $is_pr_create -eq 1 ] && [ -n "$pr_url" ]; then
      note="⚠ PR は既にあります（${pr_url}）。${obj}承認しますか？"
    elif [ -n "$pr_url" ]; then
      note="PR 作成後の ${what}（${pr_url}）を承認しますか？"
    else
      note="⚠ ## PR に URL がありません。${obj}承認しますか？"
    fi ;;
  *)
    note="⚠ まだ PR ゲート前です。${obj}承認しますか？" ;;
esac
if { [ $is_push -eq 1 ] && [ $precise_push -eq 0 ]; } || { [ $is_pr_create -eq 1 ] && [ $precise_pr -eq 0 ]; }; then
  note="${note}（コマンドの形から ${what} の可能性があると判断）"
fi
ask "${note} ${detail}"
