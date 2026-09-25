#!/usr/bin/env bash
# The /flow run state file, docs/flow/<id>/main.md: creates it and reads or
# writes its header table. Sections are written by Claude with Edit; this
# script owns the header so Status and Updated never drift apart.
#
#   state.sh init <id>                   create main.md (Status research:in-progress)
#   state.sh get <id> [field]            print a header field (default Status)
#   state.sh set <id> <field> <value>    set Status / Branch / Base / Issue; also sets Updated
#   state.sh list                        "<id>\t<Status>\t<Branch>" for every run
#
# Setting Status also maintains docs/flow/.active, which names the run that
# is before Implement (research / approach / plan). The guard hook reads it
# to ask before files outside docs/ are edited ahead of the Plan approval.
#
# Exit: 0 ok, 1 no such run, 2 usage or invalid value, 3 run already exists.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() { grep '^#   [a-z]' "$0" | sed 's/^#   //' >&2; exit 2; }

top=$(flow_top)
state_file() { printf '%s/docs/flow/%s/main.md\n' "$top" "$1"; }

valid_status() {
  case "$1" in
    research:in-progress|research:awaiting-approval) ;;
    approach:in-progress|approach:awaiting-approval) ;;
    plan:in-progress|plan:awaiting-approval) ;;
    implement:in-progress|implement:awaiting-approval) ;;
    review:in-progress|review:awaiting-approval) ;;
    pr:in-progress|pr:awaiting-approval|pr:awaiting-review) ;;
    done|canceled) ;;
    *) return 1 ;;
  esac
}

# put <file> <field> <value>: rewrite one row of the header table.
put() {
  local tmp
  tmp=$(mktemp) || exit 1
  awk -F'|' -v k="$2" -v v="$3" '
    { key = $2; gsub(/^[ \t]+|[ \t]+$/, "", key) }
    !done && key == k { printf "| %-7s | %-34s |\n", k, v; done = 1; next }
    { print }
    END { if (!done) exit 1 }' "$1" > "$tmp" || { rm -f "$tmp"; echo "no field $2 in $1" >&2; exit 2; }
  cat "$tmp" > "$1"; rm -f "$tmp"
}

track_active() { # track_active <id> <status>
  local active="$top/docs/flow/.active"
  case "$2" in
    research:*|approach:*|plan:*) printf '%s\n' "$1" > "$active" ;;
    *) [ -f "$active" ] && [ "$(cat "$active")" = "$1" ] && rm -f "$active" ;;
  esac
  return 0
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case $cmd in
  init)
    [ $# -eq 1 ] || usage
    f=$(state_file "$1")
    [ -e "$f" ] && { echo "run already exists: ${f#$top/}" >&2; exit 3; }
    ticket="docs/tickets/$1.md"
    issue=$(grep -Eo -m1 '^Issue:[[:space:]]*#[0-9]+' "$top/$ticket" 2>/dev/null | sed 's/^Issue:[[:space:]]*//')
    mkdir -p "$(dirname "$f")"
    {
      printf '# Flow: %s\n\n' "$1"
      printf '| %-7s | %-34s |\n' Field Value
      printf '|---------|------------------------------------|\n'
      printf '| %-7s | %-34s |\n' Status research:in-progress Ticket "$ticket" \
        Issue "${issue:-—}" Branch — Base — Updated "$(flow_now)"
      cat <<'EOF'

## Research
<!-- Phase 1: organized understanding of the ticket + relevant context -->

## Approach
<!-- Phase 2: chosen implementation approach and key design decisions -->

## Plan
<!-- Phase 3: branch, base, acceptance criteria -> verification table, ordered commits -->

## Implementation Log
<!-- Phase 4: commits, verification results, manual checks, notable decisions -->

## Review
<!-- Phase 5: reviewer findings as rounds, with recommendations and decisions -->

## PR
<!-- Phase 6: title, target branch, URL, review outcome -->
EOF
    } > "$f"
    track_active "$1" research:in-progress
    printf '%s\n' "${f#$top/}"
    ;;
  get)
    [ $# -ge 1 ] && [ $# -le 2 ] || usage
    f=$(state_file "$1"); [ -f "$f" ] || { echo "no run: $1" >&2; exit 1; }
    field "$f" "${2:-Status}"
    ;;
  set)
    [ $# -eq 3 ] || usage
    f=$(state_file "$1"); [ -f "$f" ] || { echo "no run: $1" >&2; exit 1; }
    case $2 in
      Status) valid_status "$3" || { echo "invalid Status: $3" >&2; exit 2; } ;;
      Branch|Base|Issue) ;;
      *) echo "field not settable: $2 (Status, Branch, Base, Issue)" >&2; exit 2 ;;
    esac
    put "$f" "$2" "$3"
    put "$f" Updated "$(flow_now)"
    [ "$2" = Status ] && track_active "$1" "$3"
    field "$f" "$2"
    ;;
  list)
    for f in "$top"/docs/flow/*/main.md; do
      [ -f "$f" ] || continue
      id=${f%/main.md}; id=${id##*/}
      printf '%s\t%s\t%s\n' "$id" "$(field "$f" Status)" "$(field "$f" Branch)"
    done
    ;;
  *) usage ;;
esac
