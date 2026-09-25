#!/usr/bin/env bash
# PreToolUse(Bash) guard for /flow, registered by SKILL.md frontmatter.
#
# On a branch that a /flow run owns (docs/flow/*/main.md whose Branch is the
# current branch), it blocks:
#   1. gh pr create   unless Status is pr:awaiting-approval, and, when the run
#                     has an issue, unless the PR body closes it (Closes #N)
#   2. git push       unless Status is pr:awaiting-approval / pr:awaiting-review,
#                     or pr:in-progress with a PR already recorded in ## PR
#   3. git push --force (any form)
# Everything else, and every command outside a /flow branch, passes untouched.
#
# Exit 0 = no decision (normal permission flow). Exit 2 = block; stderr is
# shown to Claude as the reason.
set -uo pipefail

input=$(cat)

# Cheap pre-filter on the raw JSON: most commands never reach jq or git.
case "$input" in
  *push*|*"pr create"*) ;;
  *) exit 0 ;;
esac

block() {
  {
    echo "[/flow guard] $1"
    echo "この操作は /flow のルールでブロックされました。コマンドを言い換えて回避せず、理由をユーザーに伝えて指示を待ってください。"
  } >&2
  exit 2
}

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the command can't be read reliably; fail closed only for the
  # commands this guard exists for (the pre-filter above already matched).
  block "jq が見つからないため、push / PR 作成を検査できません。jq をインストールしてください。"
fi

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cmd" ] || exit 0
[ -n "$cwd" ] || cwd=$PWD

# A command segment starts at line start or after ; & | ( { and may be
# prefixed by `command`, env assignments, or git/gh global options.
seg_start='(^|[;&|({])[[:space:]]*(command[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
git_push_re="${seg_start}git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+push([[:space:]]|$)"
gh_pr_create_re="${seg_start}gh([[:space:]]+--?[A-Za-z][A-Za-z-]*(=[^[:space:]]+)?)*[[:space:]]+pr[[:space:]]+create([[:space:]]|$)"

is_push=0; is_pr_create=0
printf '%s\n' "$cmd" | grep -Eq "$git_push_re" && is_push=1
printf '%s\n' "$cmd" | grep -Eq "$gh_pr_create_re" && is_pr_create=1
[ $is_push -eq 1 ] || [ $is_pr_create -eq 1 ] || exit 0

# Find the /flow run that owns the current branch.
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
has_pr_url=0
awk '/^## PR/{p=1; next} /^## /{p=0} p' "$state" \
  | grep -Eq 'https://[^[:space:]]+/pull/[0-9]+' && has_pr_url=1

# 3. Force push, in any form, inside the push segment(s).
if [ $is_push -eq 1 ]; then
  push_args=$(printf '%s\n' "$cmd" | grep -Eo 'push([[:space:]][^;&|]*)?' || true)
  if printf '%s\n' "$push_args" \
      | grep -Eq '(^|[[:space:]])(--force|--force-with-lease(=[^[:space:]]*)?|--force-if-includes|-[A-Za-z]*f[A-Za-z]*)([[:space:]]|$)|[[:space:]]\+[^[:space:]]'; then
    block "force push は禁止です（ブランチ ${branch}）。履歴の書き換えが本当に必要なら、ユーザー自身が ! git push --force-with-lease などで実行してください。"
  fi
fi

# 2. push / PR creation only at the PR gate.
if [ $is_pr_create -eq 1 ] && [ "$status" != "pr:awaiting-approval" ]; then
  block "PR の作成は Status が pr:awaiting-approval（Phase 6 の確認ゲート）のときだけ許可されます。現在の Status: ${status}（${state#$top/}）。"
fi
if [ $is_push -eq 1 ]; then
  case "$status" in
    pr:awaiting-approval|pr:awaiting-review) ;;
    pr:in-progress)
      [ $has_pr_url -eq 1 ] || block "push は PR 作成の確認ゲート（pr:awaiting-approval）の後、または PR 作成後の対応（## PR に URL がある pr:in-progress）でだけ許可されます。現在の Status: ${status}、## PR に URL がありません。" ;;
    *)
      block "push は Phase 6（PR）でだけ許可されます。現在の Status: ${status}（${state#$top/}）。" ;;
  esac
fi

# 1. The PR must close the run's issue.
if [ $is_pr_create -eq 1 ]; then
  issue=$(field "$state" Issue | tr -dc '0-9')
  if [ -z "$issue" ]; then
    ticket=$(field "$state" Ticket)
    [ -n "$ticket" ] && [ -f "$top/$ticket" ] \
      && issue=$(grep -Eo -m1 '^Issue:[[:space:]]*#[0-9]+' "$top/$ticket" | tr -dc '0-9')
  fi
  if [ -n "$issue" ]; then
    haystack=$cmd
    body_file=$(printf '%s\n' "$cmd" | grep -Eo '(--body-file|-F)([[:space:]]+|=)[^[:space:];&|]+' | head -1 \
      | sed -E 's/^(--body-file|-F)([[:space:]]+|=)//; s/^["'\'']//; s/["'\'']$//')
    if [ -n "$body_file" ]; then
      case "$body_file" in /*) ;; *) body_file="$cwd/$body_file" ;; esac
      [ -f "$body_file" ] && haystack="$haystack
$(cat "$body_file")"
    fi
    if ! printf '%s\n' "$haystack" | grep -Eiq "(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#${issue}([^0-9]|$)"; then
      block "PR 本文に \"Closes #${issue}\" がありません。issue #${issue} を閉じる紐付けを本文に入れてから作成してください（--fill や本文なしでは作成できません）。"
    fi
  fi
fi

exit 0
