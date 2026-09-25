#!/usr/bin/env bash
# Tests for the /flow scripts other than guard.sh. gh is replaced by a stub
# that serves fixture JSON (through jq, as gh --jq would) and records edits.
#
# Usage: bash tests/scripts.test.sh   (also run it with /bin/bash on macOS for 3.2)
set -u

here=$(cd "$(dirname "$0")" && pwd)
scripts="$here/../skills/flow/scripts"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

pass=0; fail=0; section=""
ok() { pass=$((pass + 1)); }
ng() { fail=$((fail + 1)); printf 'FAIL  [%s] %s\n' "$section" "$1"; }
# eq <want> <got> <what>
eq() { if [ "$1" = "$2" ]; then ok; else ng "$3: want [$1], got [$2]"; fi; }
# has <text> <haystack> <what>
has() { case "$2" in *"$1"*) ok ;; *) ng "$3: [$1] not in [$2]" ;; esac; }

repo="$tmp/repo"
git init -q -b main "$repo"
cd "$repo" || exit 1
mkdir -p docs/tickets
cat > docs/flow.config.yml <<'EOF'
# /flow settings (shared, committed)
language: ja   # comment
commands:      # run in order
  test: echo testing && exit 0
  lint: "echo 'a # not a comment' ; exit 1"
ticket:
  tracker: local
  prefix: T
  pad: 6
repository:
  host: github
  default_branch: main
review:
  required: false
gates: [approach, plan, pr]
EOF
printf 'docs/flow/\n' > .gitignore
git add -A && git commit -q -m init

# --- lib.sh ----------------------------------------------------------------
section="lib.sh cfg"
. "$scripts/lib.sh"
eq ja "$(cfg language)" "top-level scalar with comment"
eq local "$(cfg ticket.tracker)" "nested scalar"
eq false "$(cfg review.required)" "review.required"
eq "" "$(cfg ticket.nothing)" "missing key"
eq "approach,plan,pr" "$(cfg_list gates | paste -sd, -)" "flow list"
printf 'gates:\n  - plan\n  - pr\n' > "$tmp/block.yml"
eq "plan,pr" "$(cfg_list gates "$tmp/block.yml" | paste -sd, -)" "block list"
eq "test,lint" "$(cfg_map commands | cut -f1 | paste -sd, -)" "command keys in order"
eq "echo testing && exit 0" "$(cfg_map commands | sed -n 1p | cut -f2)" "command value"
cfg_has commands && ok || ng "cfg_has commands"
cfg_has nothing && ng "cfg_has nothing" || ok

# --- ticket-id.sh ----------------------------------------------------------
section="ticket-id.sh"
tid() { bash "$scripts/ticket-id.sh" "$@"; }
eq T000123 "$(tid normalize 123)" "digits"
eq T000123 "$(tid normalize '#123')" "#digits"
eq T000123 "$(tid normalize T123)" "short id"
eq T000123 "$(tid normalize T000123)" "canonical"
eq T1234567 "$(tid normalize 1234567)" "longer than pad"
eq 123 "$(tid number T000123)" "number"
eq 8 "$(tid number T000008)" "number, not octal"
tid normalize 'a b' 2>/dev/null; eq 2 $? "invalid id"
tid normalize legacy-1 2>/dev/null; eq 1 $? "unknown old-format id"
touch docs/tickets/legacy-1.md
eq legacy-1 "$(tid normalize legacy-1)" "old-format id with a ticket"
rm docs/tickets/legacy-1.md
eq T000001 "$(tid next --no-fetch)" "first ticket"

# The bug this fixes: a ticket committed only on its branch, plus a stale run.
echo '# T000001: A' > docs/tickets/T000001.md
git switch -q -c T000001-a && git add docs/tickets && git commit -q -m t1 && git switch -q main
eq T000002 "$(tid next --no-fetch)" "ticket only on a branch"
mkdir -p docs/flow/T000005 && touch docs/flow/T000005/main.md
eq T000006 "$(tid next --no-fetch)" "stale run folder counts"
git branch T000009-x
eq T000010 "$(tid next --no-fetch)" "branch name counts"
mkdir -p docs/tickets && echo '# T000011: B' > docs/tickets/T000011.md
eq T000012 "$(tid next --no-fetch)" "untracked working copy counts"
rm -rf docs/tickets/T000011.md docs/flow/T000005
git branch -D -q T000009-x

# Remote-tracking branches are fetched and scanned.
git init -q --bare "$tmp/origin.git"
git remote add origin "$tmp/origin.git"
git push -q origin main 2>/dev/null
git clone -q "$tmp/origin.git" "$tmp/other" 2>/dev/null
( cd "$tmp/other" && git switch -q -c T000020-y && mkdir -p docs/tickets \
  && echo x > docs/tickets/T000020.md && git add -A && git commit -q -m t20 \
  && git push -q origin T000020-y 2>/dev/null )
eq T000021 "$(tid next)" "ticket pushed from another clone"

# --- state.sh --------------------------------------------------------------
section="state.sh"
st() { bash "$scripts/state.sh" "$@"; }
mkdir -p docs/tickets && printf '# T000001: A\n\nIssue: #1\n\n## 背景\n' > docs/tickets/T000001.md
eq docs/flow/T000001/main.md "$(st init T000001)" "init"
st init T000001 2>/dev/null; eq 3 $? "init twice"
eq research:in-progress "$(st get T000001)" "initial Status"
eq '#1' "$(st get T000001 Issue)" "Issue from the ticket"
rm docs/tickets/T000001.md   # the branch T000001-a has its own copy
eq T000001 "$(cat docs/flow/.active)" ".active while researching"
eq T000001-a "$(st set T000001 Branch T000001-a)" "set Branch"
st set T000001 Status implement:typo 2>/dev/null; eq 2 $? "invalid Status"
st set T000001 Updated x 2>/dev/null; eq 2 $? "Updated is not settable"
eq plan:awaiting-approval "$(st set T000001 Status plan:awaiting-approval)" "set Status"
eq T000001 "$(cat docs/flow/.active)" ".active until Implement"
st set T000001 Status implement:in-progress >/dev/null
[ -f docs/flow/.active ] && ng ".active removed at Implement" || ok
grep -q '^## Implementation Log' docs/flow/T000001/main.md && ok || ng "sections kept"
eq "$(printf 'T000001\timplement:in-progress\tT000001-a')" "$(st list)" "list"
st get T000404 2>/dev/null; eq 1 $? "no such run"

# --- status.sh -------------------------------------------------------------
section="status.sh"
out=$(bash "$scripts/status.sh")
has "tracker=local" "$out" "config"
has "gates=approach,plan,pr" "$out" "gates"
has "T000001: Status implement:in-progress" "$out" "open run"
out=$(cd "$tmp" && bash "$scripts/status.sh"); eq 0 $? "outside a repo exits 0"
has "flow.config.yml が無い" "$out" "no config"

# --- session-start.sh ------------------------------------------------------
section="session-start.sh"
git switch -q T000001-a
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "run T000001" "$out" "run on this branch"
has "modes/dev.md" "$out" "tells to re-read dev.md"
git switch -q main
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
eq "" "$out" "no run on main"
bash "$scripts/state.sh" set T000001 Status approach:in-progress >/dev/null
out=$(printf '{"source":"compact","cwd":"%s"}' "$repo" | bash "$scripts/session-start.sh")
has "run T000001" "$out" ".active run before a branch exists"
bash "$scripts/state.sh" set T000001 Status implement:in-progress >/dev/null

# --- verify.sh -------------------------------------------------------------
section="verify.sh"
echo wip > wip.txt
out=$(bash "$scripts/verify.sh"); code=$?
eq 1 $code "a failing command"
has "Verification @ $(git rev-parse --short HEAD)+dirty: test pass, lint fail" "$out" "result line"
has "log lint:" "$out" "log of the failure"
has "a # not a comment" "$(cat "$(git rev-parse --absolute-git-dir)/flow/verify/lint.log")" "quoted # kept"
git stash -q -u
sed 's/exit 1"/exit 0"/' docs/flow.config.yml > "$tmp/c" && cat "$tmp/c" > docs/flow.config.yml
git commit -q -am pass
out=$(bash "$scripts/verify.sh"); eq 0 $? "all pass"
eq "Verification @ $(git rev-parse --short HEAD): test pass, lint pass" "$out" "clean tree"
git stash pop -q
printf 'language: ja\ncommands: {}\n' > "$tmp/empty.yml"
cp docs/flow.config.yml "$tmp/keep.yml"; cp "$tmp/empty.yml" docs/flow.config.yml
has "検証コマンドなし" "$(bash "$scripts/verify.sh")" "commands: {}"
printf 'language: ja\n' > docs/flow.config.yml
bash "$scripts/verify.sh" 2>/dev/null; eq 3 $? "no commands key"
cp "$tmp/keep.yml" docs/flow.config.yml

# --- review-input.sh -------------------------------------------------------
section="review-input.sh"
git switch -q T000001-a
echo change > file.txt && git add file.txt && git commit -q -m change
paths=$(bash "$scripts/review-input.sh" T000001 main)
diff_file=$(printf '%s\n' "$paths" | sed -n 1p)
has "+change" "$(cat "$diff_file")" "diff"
has "/.git/flow/review/T000001/" "$diff_file" "outside docs/flow"
git switch -q main

# --- ticket-hash.sh --------------------------------------------------------
section="ticket-hash.sh"
th() { bash "$scripts/ticket-hash.sh" "$@"; }
h1=$(printf '## A\nx\n' | th hash "Title")
h2=$(printf '## A\r\nx\r\n\n  \n' | th hash " Title ")
eq "$h1" "$h2" "CRLF and trailing blanks do not change the hash"
h3=$(printf '## A\n x\n' | th hash "Title")
[ "$h1" != "$h3" ] && ok || ng "inner spacing changes the hash"
h4=$(printf '## A\nx\n' | th hash "Title2")
[ "$h1" != "$h4" ] && ok || ng "the title changes the hash"
body=$(printf '> note\n\n<!-- flow:hash:abc123abc123 -->\r\n<!-- flow:ticket:start -->\r\n## A\r\nx\r\n<!-- flow:ticket:end -->\r\n')
eq "$(printf '## A\nx')" "$(printf '%s' "$body" | th extract)" "extract"
eq abc123abc123 "$(printf '%s' "$body" | th stored)" "stored"
printf 'no markers\n' | th extract >/dev/null; eq 3 $? "extract without markers"

# --- gh stub ---------------------------------------------------------------
# Serves $GH_DIR/issue-<n>.json and $GH_DIR/pr.json; writes edits to
# $GH_DIR/calls. `issue edit --body-file f` also updates the fixture body.
bin="$tmp/bin"; mkdir -p "$bin"
GH_DIR="$tmp/gh"; mkdir -p "$GH_DIR"; export GH_DIR
cat > "$bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_DIR/calls"
jqf=""; args=()
while [ $# -gt 0 ]; do
  case $1 in --jq) jqf=$2; shift 2 ;; --json) shift 2 ;; *) args+=("$1"); shift ;; esac
done
set -- "${args[@]}"
case "$1 $2" in
  "issue view") jq -r "$jqf" "$GH_DIR/issue-$3.json" ;;
  "api user") echo me ;;
  "issue create")
    echo "https://github.com/o/r/issues/42" ;;
  "issue edit")
    n=$3; shift 3
    while [ $# -gt 0 ]; do
      case $1 in
        --body-file) jq --rawfile b "$2" '.body = $b' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        --title) jq --arg t "$2" '.title = $t' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        --remove-label) jq --arg l "$2" '.labels |= map(select(.name != $l))' "$GH_DIR/issue-$n.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-$n.json"; shift 2 ;;
        *) shift ;;
      esac
    done ;;
  *) echo "stub gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$bin/gh"
PATH="$bin:$PATH"

# issue <n> <title> <body-file> [state] [reason] [labels-json]
issue() {
  jq -n --arg t "$2" --rawfile b "$3" --arg s "${4:-OPEN}" --arg r "${5:-}" --argjson l "${6:-[]}" \
    '{title: $t, body: $b, state: $s, stateReason: $r, labels: $l, assignees: [], comments: []}' \
    > "$GH_DIR/issue-$1.json"
}

# --- issue-sync.sh ---------------------------------------------------------
section="issue-sync.sh"
is() { bash "$scripts/issue-sync.sh" "$@"; }
cat > "$tmp/draft.md" <<'EOF'
# <ticket-id>: ログイン

## 背景
ログインしたい

## 受け入れ条件
- [ ] ログインできる
EOF
out=$(is create "$tmp/draft.md")
has "number: 42" "$out" "create prints the number"
has "--label flow:todo" "$(cat "$GH_DIR/calls")" "create labels flow:todo"
is body "$tmp/draft.md" > "$tmp/body42"
has "<!-- flow:ticket:start -->" "$(cat "$tmp/body42")" "body has markers"
has "この issue の本文は" "$(cat "$tmp/body42")" "notice in the document language"
issue 42 "ログイン" "$tmp/body42"
eq in-sync "$(is check 42 | sed -n 1p)" "fresh issue is in sync"

out=$(is pull 42 docs/tickets/T000042.md)
has "created" "$out" "pull creates the working copy"
eq "# T000042: ログイン" "$(sed -n 1p docs/tickets/T000042.md)" "title line"
eq "Issue: #42" "$(sed -n 3p docs/tickets/T000042.md)" "Issue line"
eq "$(ticket_body() { awk '/^## / { on = 1 } on' "$1"; }; ticket_body "$tmp/draft.md")" \
   "$(awk '/^## / { on = 1 } on' docs/tickets/T000042.md)" "ticket copied verbatim"
has "unchanged" "$(is pull 42 docs/tickets/T000042.md)" "pull again"

# Edited on GitHub: the hash no longer matches.
sed 's/ログインしたい/ログインしたい（直接編集）/' "$tmp/body42" > "$tmp/edited"
issue 42 "ログイン" "$tmp/edited" OPEN "" '[{"name":"flow:out-of-sync"}]'
eq edited "$(is check 42 | sed -n 1p)" "direct edit detected"
issue 42 "ログイン（改）" "$tmp/body42"
eq edited "$(is check 42 | sed -n 1p)" "direct title edit detected"
issue 42 "ログイン" "$tmp/edited" OPEN "" '[{"name":"flow:out-of-sync"}]'
is pull 42 docs/tickets/T000042.md >/dev/null 2>&1; eq 4 $? "pull refuses an edited issue"
before=$(cat docs/tickets/T000042.md)
is pull 42 docs/tickets/T000042.md --accept-edited --dry-run | grep -q '直接編集' && ok || ng "dry run shows the diff"
eq "$before" "$(cat docs/tickets/T000042.md)" "dry run does not write"
is pull 42 docs/tickets/T000042.md --accept-edited | grep -q '直接編集' && ok || ng "pull --accept-edited shows the diff"
is push 42 docs/tickets/T000042.md >/dev/null 2>&1; eq 4 $? "push refuses an edited issue"
out=$(is push 42 docs/tickets/T000042.md --force)
has "updated" "$out" "push --force rehashes"
has "removed label: flow:out-of-sync" "$out" "push removes out-of-sync"
eq in-sync "$(is check 42 | sed -n 1p)" "in sync after adopting"

# Local edit (/flow edit) then push.
sed 's/ログインできる/ログインできる\n- [ ] ログアウトできる/' docs/tickets/T000042.md > "$tmp/t" && cat "$tmp/t" > docs/tickets/T000042.md
has "updated" "$(is push 42 docs/tickets/T000042.md)" "push a local edit"
has "ログアウトできる" "$(jq -r .body "$GH_DIR/issue-42.json")" "issue has the edit"
eq in-sync "$(is check 42 | sed -n 1p)" "in sync after push"
has "unchanged" "$(is push 42 docs/tickets/T000042.md)" "push again"

# Markers removed on GitHub.
printf 'just text\n' > "$tmp/nomark"
issue 43 "x" "$tmp/nomark"
eq no-markers "$(is check 43 | sed -n 1p)" "no markers"
is pull 43 docs/tickets/T000043.md >/dev/null 2>&1; eq 3 $? "pull without markers"

# An issue made before hashes.
grep -v 'flow:hash' "$tmp/body42" > "$tmp/nohash"
issue 44 "ログイン" "$tmp/nohash"
eq no-hash "$(is check 44 | sed -n 1p)" "no hash"
has "created" "$(is pull 44 docs/tickets/T000044.md)" "pull an issue without a hash"

# Canceled issue: Status / Reason come back.
sed '1s/.*/# <ticket-id>: やめた/' "$tmp/draft.md" > "$tmp/draft45"
is body "$tmp/draft45" > "$tmp/body45"
issue 45 "やめた" "$tmp/body45" CLOSED NOT_PLANNED
jq '.comments = [{"body":"Canceled by /flow: 優先度が下がった"}]' "$GH_DIR/issue-45.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-45.json"
is pull 45 docs/tickets/T000045.md >/dev/null
has "Status: canceled" "$(cat docs/tickets/T000045.md)" "canceled status restored"
has "Reason: 優先度が下がった" "$(cat docs/tickets/T000045.md)" "cancel reason restored"

# --- issue-label.sh --------------------------------------------------------
section="issue-label.sh"
il() { bash "$scripts/issue-label.sh" "$@"; }
jq '.labels = [{"name":"flow:todo"},{"name":"bug"}] | .assignees = []' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
: > "$GH_DIR/calls"
has "flow:in-progress" "$(il 42 start)" "start"
has "--remove-label flow:todo --add-label flow:in-progress --add-assignee @me" "$(tail -1 "$GH_DIR/calls")" "start edits"
jq '.assignees = [{"login":"someone"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 start 2>/dev/null; eq 4 $? "someone else is assigned"
il 42 start --force >/dev/null; eq 0 $? "start --force"
jq '.assignees = [{"login":"me"}] | .labels = [{"name":"flow:in-review"}]' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 reset >/dev/null
has "--remove-label flow:in-review --add-label flow:todo --remove-assignee @me" "$(tail -1 "$GH_DIR/calls")" "reset edits"
jq '.state = "CLOSED"' "$GH_DIR/issue-42.json" > "$GH_DIR/t" && mv "$GH_DIR/t" "$GH_DIR/issue-42.json"
il 42 review 2>/dev/null; eq 3 $? "closed issue"

# --- pr-status.sh ----------------------------------------------------------
section="pr-status.sh"
prs() { FLOW_PR_JSON="$tmp/pr.json" bash "$scripts/pr-status.sh" x | sed -n 1p; }
# pr <state> <mergeable> <reviewDecision> <latestReviews-json> <checks-json>
pr() {
  jq -n --arg s "$1" --arg m "$2" --arg d "$3" --argjson r "$4" --argjson c "$5" \
    '{url: "https://github.com/o/r/pull/9", state: $s, mergeable: $m, reviewDecision: $d, latestReviews: $r, statusCheckRollup: $c}' > "$tmp/pr.json"
}
ok_check='[{"__typename":"CheckRun","name":"test","status":"COMPLETED","conclusion":"SUCCESS"}]'
bad_check='[{"__typename":"CheckRun","name":"test","status":"COMPLETED","conclusion":"FAILURE"}]'
run_check='[{"__typename":"CheckRun","name":"test","status":"IN_PROGRESS","conclusion":""}]'
approved='[{"state":"APPROVED","author":{"login":"a"}}]'
pr MERGED MERGEABLE "" '[]' "$ok_check";              eq merged "$(prs)" "merged"
pr CLOSED MERGEABLE "" '[]' "$ok_check";              eq closed "$(prs)" "closed"
pr OPEN CONFLICTING APPROVED "$approved" "$ok_check"; eq conflict "$(prs)" "conflict"
pr OPEN MERGEABLE APPROVED "$approved" "$bad_check";  eq ci_failing "$(prs)" "ci failing"
pr OPEN MERGEABLE CHANGES_REQUESTED '[{"state":"CHANGES_REQUESTED","author":{"login":"a"}}]' "$ok_check"
eq changes_requested "$(prs)" "changes requested"
pr OPEN MERGEABLE APPROVED "$approved" "$ok_check";   eq approved "$(prs)" "approved"
pr OPEN MERGEABLE "" '[]' "$ok_check";                eq ready "$(prs)" "ready without review"
pr OPEN MERGEABLE "" '[]' '[]';                       eq ready "$(prs)" "ready, no checks"
pr OPEN MERGEABLE "" '[]' "$run_check";               eq pending "$(prs)" "checks running"
pr OPEN UNKNOWN "" '[]' "$ok_check";                  eq pending "$(prs)" "mergeability unknown"

echo "scripts: $pass passed, $fail failed"
[ $fail -eq 0 ]
