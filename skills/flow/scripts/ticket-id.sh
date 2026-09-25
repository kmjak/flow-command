#!/usr/bin/env bash
# Ticket ids for /flow. Numbers are handled as strings, so a zero-padded
# id is never read as octal.
#
#   ticket-id.sh normalize <T000123 | 123 | #123 | id>   canonical id
#   ticket-id.sh number <id>                              issue number (123)
#   ticket-id.sh next [--no-fetch]                        next local id
#
# `next` is for ticket.tracker: local. The largest number is taken from
# every place a ticket can be while it is not on the current branch:
# docs/tickets/ in the working tree, docs/tickets/ on every local and
# remote-tracking branch, docs/flow/<id>/ (runs, which are not in git) and
# branch names <id>-<slug>. Remote-tracking branches are refreshed with
# `git fetch` first (never pull: it would touch the working tree).
#
# Exit: 0 ok, 1 unknown id, 2 invalid id or usage.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

prefix=$(cfg ticket.prefix); [ -n "$prefix" ] || prefix=T
pad=$(cfg ticket.pad)
case $pad in ''|*[!0-9]*) pad=6 ;; esac

usage() { grep '^#   [a-z]' "$0" | sed 's/^#   //' >&2; exit 2; }

# fmt <digits>: prefix + number padded to $pad (never truncated).
fmt() {
  local n
  n=$(printf '%s' "$1" | sed 's/^0*//'); [ -n "$n" ] || n=0
  while [ ${#n} -lt "$pad" ]; do n="0$n"; done
  printf '%s%s\n' "$prefix" "$n"
}

digits_of_id() { # digits_of_id <id>: the number part, or empty
  local rest=${1#"$prefix"}
  [ "$rest" != "$1" ] || [ -z "$prefix" ] || return 0
  case $rest in ''|*[!0-9]*) return 0 ;; esac
  printf '%s\n' "$rest"
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case $cmd in
  normalize)
    [ $# -eq 1 ] || usage
    in=${1#\#}
    case $in in
      ''|*[!0-9]*) ;;
      *) fmt "$in"; exit 0 ;;
    esac
    d=$(digits_of_id "$in")
    if [ -n "$d" ]; then fmt "$d"; exit 0; fi
    case $1 in
      *[[:space:]/\#~^:?*\[\\]*) echo "invalid ticket id: $1" >&2; exit 2 ;;
    esac
    # An id in an older format is kept as is when its ticket exists.
    if [ -f "$(flow_top)/docs/tickets/$1.md" ]; then printf '%s\n' "$1"; exit 0; fi
    echo "unknown ticket id: $1" >&2; exit 1
    ;;
  number)
    [ $# -eq 1 ] || usage
    d=$(digits_of_id "$1")
    [ -n "$d" ] || { echo "not a numbered ticket id: $1" >&2; exit 2; }
    n=$(printf '%s' "$d" | sed 's/^0*//')
    [ -n "$n" ] || { echo "ticket number is zero: $1" >&2; exit 2; }
    printf '%s\n' "$n"
    ;;
  next)
    top=$(flow_top)
    if [ "${1:-}" != --no-fetch ] && git -C "$top" remote 2>/dev/null | grep -q .; then
      git -C "$top" fetch --quiet --prune 2>/dev/null || echo "warning: git fetch failed; remote branches may be stale" >&2
    fi
    max=$(
      {
        ls "$top/docs/tickets" 2>/dev/null
        ls "$top/docs/flow" 2>/dev/null
        refs=$(git -C "$top" for-each-ref --format='%(refname)' refs/heads refs/remotes 2>/dev/null)
        for ref in $refs; do
          printf '%s\n' "${ref##*/}"
          git -C "$top" ls-tree --name-only "$ref" docs/tickets/ 2>/dev/null | sed 's|.*/||'
        done
      } | awk -v p="$prefix" '
        { s = $0 }
        p != "" { if (index(s, p) != 1) next; s = substr(s, length(p) + 1) }
        match(s, /^[0-9]+/) {
          d = substr(s, 1, RLENGTH); sub(/^0+/, "", d); if (d == "") d = "0"
          if (length(d) > length(m) || (length(d) == length(m) && d > m)) m = d
        }
        END { print (m == "" ? "0" : m) }'
    )
    fmt "$((10#$max + 1))"
    ;;
  *) usage ;;
esac
