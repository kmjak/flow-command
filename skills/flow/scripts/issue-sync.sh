#!/usr/bin/env bash
# Tickets and their GitHub issues (ticket.tracker: github). The issue is the
# source of truth; docs/tickets/<id>.md is a working copy that is not in git
# and is rebuilt from the issue. See references/github.md.
#
#   issue-sync.sh create <ticket-file>                     create the issue (flow:todo); prints number and url
#   issue-sync.sh check <number>                           in-sync | edited | no-hash | no-markers, then details
#   issue-sync.sh pull <number> <ticket-file> [--accept-edited] [--dry-run]
#                                                          rebuild the working copy from the issue; prints the diff
#                                                          (--dry-run: only print it)
#   issue-sync.sh push <number> <ticket-file> [--force]    write the working copy to the issue
#   issue-sync.sh body <ticket-file>                       the issue body for a ticket (no GitHub access)
#
# check verdicts:
#   in-sync     the body's hash matches its title + ticket: only /flow wrote it
#   edited      it does not: the title or the ticket was edited on GitHub
#   no-hash     markers but no hash (an issue made before hashes); treated as in-sync
#   no-markers  the markers are gone (edited on GitHub, or an old issue)
#
# Exit: 0 ok, 2 usage, 3 no markers, 4 edited on GitHub (pull without
#       --accept-edited, push without --force), other: gh failed.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
hash_sh="$here/ticket-hash.sh"

usage() { grep '^#   [a-z]' "$0" | sed 's/^#   //' >&2; exit 2; }

OUT_OF_SYNC=flow:out-of-sync

# --- ticket file ------------------------------------------------------------

ticket_title() { sed -n '1{s/^# *//; s/^[^:]*: *//; p;}' "$1"; }
ticket_body() { awk '/^## / { on = 1 } on' "$1"; }                  # first ## to the end
ticket_meta() { awk '/^## / { exit } /^(Status|Reason):/' "$1"; }  # cancel lines

notice() {
  case $(cfg language) in
    ja|'') printf '%s\n' '> [!NOTE]' '> この issue の本文は `/flow` がチケットと同期しています。本文やタイトルを変えるときは直接編集せず、`/flow edit` を使ってください。議論はコメントでどうぞ。' ;;
    *) printf '%s\n' '> [!NOTE]' '> This issue body is synced with a ticket by `/flow`. Do not edit the body or title here; use `/flow edit`. Discussion is welcome in the comments.' ;;
  esac
}

# make_body <title> <ticket-body-file>
make_body() {
  local h
  h=$(bash "$hash_sh" hash "$1" < "$2")
  notice
  printf '\n<!-- flow:hash:%s -->\n<!-- flow:ticket:start -->\n' "$h"
  tr -d '\r' < "$2" | awk '{ a[NR] = $0 } END { n = NR; while (n > 0 && a[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print a[i] }'
  printf '<!-- flow:ticket:end -->\n'
}

# --- issue ------------------------------------------------------------------

tmpd=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpd"' EXIT

# load <number>: fills $tmpd/body and title, state, reason, labels.
load() {
  local info
  # One value per line: a tab-separated read would collapse empty fields.
  info=$(gh issue view "$1" --json title,state,stateReason,labels \
    --jq '.title, .state, (.stateReason // ""), ([.labels[].name] | join(","))') || exit $?
  gh issue view "$1" --json body --jq .body > "$tmpd/body" || exit $?
  title=$(printf '%s\n' "$info" | sed -n 1p)
  state=$(printf '%s\n' "$info" | sed -n 2p)
  reason=$(printf '%s\n' "$info" | sed -n 3p)
  labels=$(printf '%s\n' "$info" | sed -n 4p)
}

# verdict: of the loaded issue.
verdict() {
  local stored
  bash "$hash_sh" extract < "$tmpd/body" > "$tmpd/ticket" || { echo no-markers; return; }
  stored=$(bash "$hash_sh" stored < "$tmpd/body") || { echo no-hash; return; }
  if [ "$(bash "$hash_sh" hash "$title" < "$tmpd/ticket")" = "$stored" ]; then echo in-sync; else echo edited; fi
}

has_label() { case ",$labels," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

cmd=${1:-}; [ $# -gt 0 ] && shift
case $cmd in
  body)
    [ $# -eq 1 ] || usage
    ticket_body "$1" > "$tmpd/ticket"
    make_body "$(ticket_title "$1")" "$tmpd/ticket"
    ;;

  create)
    [ $# -eq 1 ] || usage
    t=$(ticket_title "$1")
    ticket_body "$1" > "$tmpd/ticket"
    make_body "$t" "$tmpd/ticket" > "$tmpd/new"
    url=$(gh issue create --title "$t" --body-file "$tmpd/new" --label flow:todo) || exit $?
    url=$(printf '%s\n' "$url" | grep -Eo 'https://[^[:space:]]+/issues/[0-9]+' | tail -1)
    echo "number: ${url##*/}"
    echo "url: $url"
    ;;

  check)
    [ $# -eq 1 ] || usage
    load "$1"
    verdict
    echo "title: $title"
    echo "state: $state"
    echo "state_reason: $reason"
    echo "labels: $labels"
    ;;

  pull)
    [ $# -ge 2 ] || usage
    n=$1 file=$2 accept="" dry=""; shift 2
    for a in "$@"; do
      case $a in --accept-edited) accept=1 ;; --dry-run) dry=1 ;; *) usage ;; esac
    done
    load "$n"
    v=$(verdict)
    case $v in
      no-markers) echo "no-markers: issue #$n の本文に flow の目印がありません" >&2; exit 3 ;;
      edited) [ -n "$accept" ] || { echo "edited: issue #$n は GitHub 上で直接編集されています" >&2; exit 4; } ;;
    esac
    id=$(basename "$file" .md)
    meta=""
    [ -f "$file" ] && meta=$(ticket_meta "$file")
    if [ -z "$meta" ] && [ "$state" = CLOSED ] && [ "$reason" = NOT_PLANNED ]; then
      why=$(gh issue view "$n" --json comments \
        --jq '[.comments[].body | select(startswith("Canceled by /flow: "))] | last // ""' | head -1)
      [ -n "$why" ] && meta="Status: canceled
Reason: ${why#Canceled by /flow: }"
    fi
    {
      printf '# %s: %s\n\nIssue: #%s\n' "$id" "$title" "$n"
      [ -n "$meta" ] && printf '%s\n' "$meta"
      printf '\n'
      cat "$tmpd/ticket"
    } > "$tmpd/new"
    if [ ! -f "$file" ]; then
      if [ -n "$dry" ]; then echo "would create: $file"; cat "$tmpd/new"; exit 0; fi
      mkdir -p "$(dirname "$file")"; cat "$tmpd/new" > "$file"
      echo "created: $file"
    elif cmp -s "$file" "$tmpd/new"; then
      echo "unchanged: $file"
    else
      diff -u --label "$file (before)" --label "$file (issue #$n)" "$file" "$tmpd/new"
      [ -n "$dry" ] || cat "$tmpd/new" > "$file"
    fi
    ;;

  push)
    [ $# -ge 2 ] && [ $# -le 3 ] || usage
    n=$1 file=$2 force=${3:-}
    [ -z "$force" ] || [ "$force" = --force ] || usage
    load "$n"
    v=$(verdict)
    case $v in
      no-markers) [ -n "$force" ] || { echo "no-markers: issue #$n の本文に flow の目印がありません（--force で上書き）" >&2; exit 3; } ;;
      edited) [ -n "$force" ] || { echo "edited: issue #$n は GitHub 上で直接編集されています（--force で上書き）" >&2; exit 4; } ;;
    esac
    t=$(ticket_title "$file")
    ticket_body "$file" > "$tmpd/local"
    make_body "$t" "$tmpd/local" > "$tmpd/new"
    if [ "$t" = "$title" ] && [ "$(tr -d '\r' < "$tmpd/body")" = "$(cat "$tmpd/new")" ]; then
      echo "unchanged: #$n"
    else
      gh issue edit "$n" --title "$t" --body-file "$tmpd/new" >/dev/null || exit $?
      echo "updated: #$n"
    fi
    if has_label "$OUT_OF_SYNC"; then
      gh issue edit "$n" --remove-label "$OUT_OF_SYNC" >/dev/null && echo "removed label: $OUT_OF_SYNC"
    fi
    ;;

  *) usage ;;
esac
