#!/usr/bin/env bash
# Summarize a PR's state for /flow Phase 6.
#
# Usage: pr-status.sh <pr-url | pr-number | branch>
#
# First line is the verdict (one of):
#   merged             PR is merged
#   closed             PR is closed without merge
#   conflict           has merge conflicts with the base branch
#   ci_failing         at least one check failed
#   changes_requested  a reviewer requested changes (latest review per reviewer)
#   approved           approved, all checks passed (or none), no conflicts
#   ready              not approved yet, but all checks passed (or none) and no conflicts;
#                      done for review.required: false, pending otherwise
#   pending            anything else (awaiting review, checks running, mergeability unknown)
# Following lines are key: value details.
#
# Precedence: merged > closed > conflict > ci_failing > changes_requested > approved > ready > pending
#
# FLOW_PR_JSON=<file> reads the `gh pr view --json` output from a file
# instead of calling gh (for tests).
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $(basename "$0") <pr-url | pr-number | branch>" >&2
  exit 2
fi

filter='
    def check_result:
      if .__typename == "CheckRun" then
        if .status != "COMPLETED" then "pending"
        elif (.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or .conclusion == "CANCELLED"
              or .conclusion == "ACTION_REQUIRED" or .conclusion == "STARTUP_FAILURE") then "failure"
        else "success" end
      else
        if (.state == "PENDING" or .state == "EXPECTED") then "pending"
        elif (.state == "FAILURE" or .state == "ERROR") then "failure"
        else "success" end
      end;
    def check_name: .name // .context;

    [.statusCheckRollup[]? | {name: check_name, result: check_result}] as $checks
    | ([$checks[] | select(.result == "failure") | .name]) as $failing
    | (if ($failing | length) > 0 then "failure"
       elif ([$checks[] | select(.result == "pending")] | length) > 0 then "pending"
       else "success" end) as $ci
    | ([.latestReviews[]? | select(.state == "CHANGES_REQUESTED") | .author.login]) as $requesters
    | ([.latestReviews[]? | select(.state == "APPROVED") | .author.login]) as $approvers
    | ([.latestReviews[]? | select(.state == "COMMENTED") | .author.login]) as $commenters
    | (if .reviewDecision == "CHANGES_REQUESTED" or ($requesters | length) > 0 then "changes_requested"
       elif .reviewDecision == "APPROVED" or ((.reviewDecision == null or .reviewDecision == "") and ($approvers | length) > 0) then "approved"
       else "pending" end) as $review
    | (if .state == "MERGED" then "merged"
       elif .state == "CLOSED" then "closed"
       elif .mergeable == "CONFLICTING" then "conflict"
       elif $ci == "failure" then "ci_failing"
       elif $review == "changes_requested" then "changes_requested"
       elif $review == "approved" and $ci == "success" and .mergeable == "MERGEABLE" then "approved"
       elif $ci == "success" and .mergeable == "MERGEABLE" then "ready"
       else "pending" end) as $verdict
    | $verdict,
      "url: \(.url)",
      "review: \($review)",
      "ci: \($ci)",
      "mergeable: \(.mergeable)",
      "failing_checks: \($failing | join(", "))",
      "changes_requested_by: \($requesters | join(", "))",
      "approved_by: \($approvers | join(", "))",
      "commented_by: \($commenters | join(", "))"
  '

if [ -n "${FLOW_PR_JSON:-}" ]; then
  jq -r "$filter" "$FLOW_PR_JSON"
else
  gh pr view "$1" \
    --json url,state,mergeable,reviewDecision,latestReviews,statusCheckRollup \
    --jq "$filter"
fi
