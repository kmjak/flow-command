#!/usr/bin/env bash
# Status labels and assignee of a /flow issue (ticket.tracker: github).
#
#   issue-label.sh <number> start [--force]   flow:in-progress, assign yourself
#   issue-label.sh <number> review            flow:in-review
#   issue-label.sh <number> reset             flow:todo, unassign yourself
#
# Only the flow:todo / flow:in-progress / flow:in-review labels that are on
# the issue are removed; other labels (flow:out-of-sync included) are kept.
# Prints what was done in one line.
#
# Exit: 0 ok, 2 usage, 3 the issue is closed, 4 someone else is assigned
#       (start without --force), other: gh failed.
set -uo pipefail

usage() { grep '^#   [a-z]' "$0" | sed 's/^#   //' >&2; exit 2; }

[ $# -ge 2 ] && [ $# -le 3 ] || usage
n=$1 action=$2 force=${3:-}
[ -z "$force" ] || [ "$force" = --force ] || usage
case $action in
  start) want=flow:in-progress ;;
  review) want=flow:in-review ;;
  reset) want=flow:todo ;;
  *) usage ;;
esac

info=$(gh issue view "$n" --json state,labels,assignees \
  --jq '.state, ([.labels[].name] | join(",")), ([.assignees[].login] | join(","))') || exit $?
state=$(printf '%s\n' "$info" | sed -n 1p)
labels=$(printf '%s\n' "$info" | sed -n 2p)
assignees=$(printf '%s\n' "$info" | sed -n 3p)

[ "$state" = OPEN ] || { echo "issue #$n は閉じています（開き直さない）" >&2; exit 3; }

me=$(gh api user --jq .login) || exit $?

if [ "$action" = start ] && [ -z "$force" ]; then
  others=$(printf '%s' "$assignees" | tr ',' '\n' | grep -vx "$me" | paste -sd, -)
  if [ -n "$others" ]; then
    echo "issue #$n には他の人が assign されています: $others" >&2
    exit 4
  fi
fi

args=""
for l in flow:todo flow:in-progress flow:in-review; do
  [ "$l" = "$want" ] && continue
  case ",$labels," in *",$l,"*) args="$args --remove-label $l" ;; esac
done
args="$args --add-label $want"
note="#$n を $want に"
case $action in
  start) args="$args --add-assignee @me"; note="$note し、assignee に自分を追加" ;;
  reset) case ",$assignees," in *",$me,"*) args="$args --remove-assignee @me"; note="$note し、assignee から自分を外した" ;; esac ;;
esac

# shellcheck disable=SC2086 # $args is a list of flags without spaces in values
gh issue edit "$n" $args >/dev/null || exit $?
echo "$note"
