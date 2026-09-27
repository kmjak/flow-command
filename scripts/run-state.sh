#!/usr/bin/env bash
# The tixforge run state file, .tixforge/<id>/state.md: creates it and reads
# or writes its header table. Sections are written by Claude with Edit; this
# script owns the header so Status and Updated never drift apart. The ticket
# is .tixforge/<id>/ticket.md and a GT id carries its issue number, so the
# header does not repeat them.
#
#   run-state.sh init <id>                   create state.md (Status research:in-progress)
#   run-state.sh get <id> [field]            print a header field (default Status)
#   run-state.sh set <id> <field> <value>    set Status / Branch / Base; also sets Updated
#   run-state.sh list                        "<id>\t<Status>\t<Branch>" for every run
#
# Exit: 0 ok, 1 no such run, 2 usage or invalid value, 3 run already exists.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() { grep '^#   [a-z]' "$0" | sed 's/^#   //' >&2; exit 2; }

top=$(flow_top)
sfile() { state_file "$1" "$top"; }

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

cmd=${1:-}; [ $# -gt 0 ] && shift
case $cmd in
  init)
    [ $# -eq 1 ] || usage
    is_ticket_id "$1" || { echo "not a ticket id: $1" >&2; exit 2; }
    f=$(sfile "$1")
    [ -e "$f" ] && { echo "run already exists: ${f#$top/}" >&2; exit 3; }
    ensure_workspace "$top"
    mkdir -p "$(dirname "$f")"
    {
      printf '# Run: %s\n\n' "$1"
      printf '| %-7s | %-34s |\n' Field Value
      printf '|---------|------------------------------------|\n'
      printf '| %-7s | %-34s |\n' Status research:in-progress \
        Branch — Base — Updated "$(flow_now)"
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
    printf '%s\n' "${f#$top/}"
    ;;
  get)
    [ $# -ge 1 ] && [ $# -le 2 ] || usage
    f=$(sfile "$1"); [ -f "$f" ] || { echo "no run: $1" >&2; exit 1; }
    field "$f" "${2:-Status}"
    ;;
  set)
    [ $# -eq 3 ] || usage
    f=$(sfile "$1"); [ -f "$f" ] || { echo "no run: $1" >&2; exit 1; }
    case $2 in
      Status) valid_status "$3" || { echo "invalid Status: $3" >&2; exit 2; } ;;
      Branch|Base) ;;
      *) echo "field not settable: $2 (Status, Branch, Base)" >&2; exit 2 ;;
    esac
    put "$f" "$2" "$3"
    put "$f" Updated "$(flow_now)"
    field "$f" "$2"
    ;;
  list)
    for f in "$(tf_dir "$top")"/*/state.md; do
      [ -f "$f" ] || continue
      id=${f%/state.md}; id=${id##*/}
      printf '%s\t%s\t%s\n' "$id" "$(field "$f" Status)" "$(field "$f" Branch)"
    done
    ;;
  *) usage ;;
esac
