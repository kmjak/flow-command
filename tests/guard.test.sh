#!/usr/bin/env bash
# Tests for skills/flow/scripts/guard.sh.
#
# Feeds the guard the same JSON Claude Code sends to a PreToolUse(Bash) hook
# and checks its decision:
#   pass   exit 0, no output (normal permission flow)
#   ask    exit 0, permissionDecision "ask"
#   deny   exit 2, or permissionDecision "deny"
#
# Usage: bash tests/guard.test.sh   (also run it with /bin/bash on macOS for 3.2)
set -u

here=$(cd "$(dirname "$0")" && pwd)
guard="$here/../skills/flow/scripts/guard.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Isolate from the user's git config (signing, hooks, default branch).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# A PATH without jq: symlinks to only the tools the guard and git need.
nojq="$tmp/nojq-bin"
mkdir -p "$nojq"
for t in bash git awk grep sed tr head cat dirname; do
  p=$(command -v "$t") && ln -s "$p" "$nojq/$t"
done

# --- fixtures ---------------------------------------------------------------

# A repo whose branch T000001-login is owned by a /flow run.
flow="$tmp/flow-repo"
git init -q -b main "$flow"
git -C "$flow" commit -q --allow-empty -m init
git -C "$flow" checkout -q -b T000001-login
mkdir -p "$flow/docs/flow/T000001" "$flow/docs/tickets"
printf '# T000001: Login\n\nIssue: #1\n' > "$flow/docs/tickets/T000001.md"

# set_state <status> [pr-url]
set_state() {
  cat > "$flow/docs/flow/T000001/main.md" <<EOF
# Flow: T000001

| Field   | Value                        |
|---------|------------------------------|
| Status  | $1                           |
| Ticket  | docs/tickets/T000001.md      |
| Issue   | #1                           |
| Branch  | T000001-login                |
| Base    | main                         |
| Updated | 2026-01-01 00:00             |

## Implementation Log

## PR
${2:-}
EOF
}

# A repo with no /flow at all.
plain="$tmp/plain-repo"
git init -q -b main "$plain"
git -C "$plain" commit -q --allow-empty -m init

# --- runner -----------------------------------------------------------------

# json_str <s>: s as a JSON string literal (enough for these fixtures).
json_str() {
  printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

# decide <dir> <command> [PATH]: prints pass | ask | deny
decide() {
  local dir=$1 cmd=$2 path=${3:-$PATH} out code
  out=$(cd "$dir" && printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":%s}' \
          "$(json_str "$cmd")" "$(json_str "$dir")" \
        | PATH=$path bash "$guard" 2>/dev/null)
  code=$?
  if [ $code -eq 2 ]; then echo deny; return; fi
  case "$out" in
    *'"permissionDecision"'*'"deny"'*) echo deny ;;
    *'"permissionDecision"'*'"ask"'*) echo ask ;;
    '') [ $code -eq 0 ] && echo pass || echo "error($code)" ;;
    *) echo "unexpected($code): $out" ;;
  esac
}

pass=0; fail=0
# expect <want> <dir> <command> [PATH]
expect() {
  local want=$1 got
  got=$(decide "$2" "$3" "${4:-$PATH}")
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL  [%s] %s\n      want %s, got %s\n' "$state" "$3" "$want" "$got"
  fi
}

# --- cases ------------------------------------------------------------------

state="no flow"
expect pass "$plain" 'git push'
expect pass "$plain" 'gh pr create --fill'
expect pass "$tmp"   'git push'   # not a git repo

state="flow repo, other branch"
git -C "$flow" checkout -q main
set_state implement:in-progress
expect pass "$flow" 'git push'
git -C "$flow" checkout -q T000001-login

state="implement:in-progress"
set_state implement:in-progress
expect pass "$flow" 'git status'
expect pass "$flow" 'git stash push -m wip'
expect pass "$flow" 'echo pushed'
expect deny "$flow" 'git push'
expect deny "$flow" 'git push -u origin T000001-login'
expect deny "$flow" 'git -C . push'
expect deny "$flow" 'command git push'
expect deny "$flow" 'FOO=1 git push'
expect deny "$flow" 'cd . && git push'
expect deny "$flow" 'gh pr create --title t --body "Closes #1"'

state="pr:awaiting-approval"
set_state pr:awaiting-approval
expect pass "$flow" 'git push -u origin T000001-login'
expect deny "$flow" 'git push --force'
expect deny "$flow" 'git push -f'
expect deny "$flow" 'git push --force-with-lease'
expect deny "$flow" 'git push origin +T000001-login'
expect pass "$flow" 'gh pr create --title t --body "Closes #1"'
expect pass "$flow" 'gh pr create --title t --body "fixes #1"'
expect deny "$flow" 'gh pr create --title t --body "Closes #12"'
expect deny "$flow" 'gh pr create --fill'
printf 'Summary\n\nCloses #1\n' > "$tmp/body.md"
expect pass "$flow" "gh pr create --title t --body-file $tmp/body.md"
printf 'Summary\n' > "$tmp/body-noclose.md"
expect deny "$flow" "gh pr create --title t --body-file $tmp/body-noclose.md"

state="pr:awaiting-review"
set_state pr:awaiting-review 'https://github.com/o/r/pull/9'
expect pass "$flow" 'git push'
expect deny "$flow" 'gh pr create --title t --body "Closes #1"'

state="pr:in-progress"
set_state pr:in-progress
expect deny "$flow" 'git push'
set_state pr:in-progress 'https://github.com/o/r/pull/9'
expect pass "$flow" 'git push'

# Known gaps: rewordings the guard does not see today.
state="implement:in-progress (rewordings)"
set_state implement:in-progress
expect pass "$flow" 'bash -c "git push"'
expect pass "$flow" 'eval "git push"'
expect pass "$flow" 'env git push'
expect pass "$flow" '"git" push'
expect pass "$flow" 'gh api repos/o/r/pulls -f title=t -f head=T000001-login -f base=main'

state="no jq"
set_state implement:in-progress
expect deny "$flow"  'git push'              "$nojq"
expect pass "$flow"  'git status'            "$nojq"
expect deny "$plain" 'git stash push -m wip' "$nojq"   # blocks outside /flow

echo "guard: $pass passed, $fail failed"
[ $fail -eq 0 ]
