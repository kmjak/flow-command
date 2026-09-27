#!/usr/bin/env bash
# Write what the Review agents read: the change of this run, as files, so
# the agents need no Bash (they stay read-only) and the diff does not pass
# through the implementing session's context.
#
#   review-input.sh <id> <base>
#
# Files go under <git dir>/flow/review/<id>/ (outside docs/flow/, which the
# reviewers must not read) and are replaced on every call:
#   diff.patch   git diff <base>...HEAD
#   log.txt      git log --stat <base>..HEAD
#   files.txt    git diff --name-status <base>...HEAD
# Prints the three paths.
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: review-input.sh <id> <base>" >&2; exit 2; }
id=$1 base=$2

git rev-parse --verify -q "$base" >/dev/null || { echo "unknown base: $base" >&2; exit 2; }
dir="$(git rev-parse --absolute-git-dir)/flow/review/$id"
mkdir -p "$dir"
git diff "$base"...HEAD > "$dir/diff.patch"
git log --stat "$base"..HEAD > "$dir/log.txt"
git diff --name-status "$base"...HEAD > "$dir/files.txt"
printf '%s\n' "$dir/diff.patch" "$dir/log.txt" "$dir/files.txt"
