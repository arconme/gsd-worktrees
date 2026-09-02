#!/usr/bin/env bash
# test-flow-next.sh — the /gsd-flow step engine walks the agreed order.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; PKG="$(cd "$HERE/.." && pwd)"
NEXT="$PKG/bin/gsd-flow-next"
PASS=0; FAIL=0; WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '      %s\n' "$2"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
section() { printf '\n%s\n' "$1"; }

REPO="$WORK/r"; PD="$REPO/.planning/phases/07-thing"; mkdir -p "$PD"
git -C "$REPO" init -q -b develop
gcommit() { git -C "$REPO" add -A >/dev/null; GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" git -C "$REPO" -c user.email=t@t -c user.name=t commit -q -m "$2" --allow-empty; }
step() { "$NEXT" 7 --repo "$REPO" "$@" | sed -n 's/^step=//p'; }
fm() { printf -- '---\nstatus: %s\n%s\n---\n' "$2" "${3:-}" > "$PD/07-$1"; }

section "walks the order as artifacts appear"
is "empty folder → story"            "$(step)" story
: > "$PD/07-STORY.md";      is "story → discuss"               "$(step)" discuss
: > "$PD/07-CONTEXT.md";    is "discuss → ui-decision"         "$(step)" ui-decision
is "ui-decision --no-ui → plan"       "$(step --no-ui)" plan
is "ui-decision --ui → ui-phase"      "$(step --ui)" ui-phase
: > "$PD/07-UI-SPEC.md";    is "UI-SPEC → plan (no flag needed)" "$(step)" plan
: > "$PD/07-01-PLAN.md"; : > "$PD/07-02-PLAN.md"
is "plans → review"                   "$(step)" review
: > "$PD/07-REVIEWS.md";    is "REVIEWS uncommitted → replan"  "$(step)" replan
gcommit 2026-01-01T10:00:00 "plans"          # plans + REVIEWS in one commit → counts as replanned
is "REVIEWS + plans same commit → execute"  "$(step)" execute
: > "$PD/07-REVIEWS.md"; echo x >> "$PD/07-REVIEWS.md"; gcommit 2026-01-01T11:00:00 "review again"
is "REVIEWS committed after plans → replan" "$(step)" replan
echo y >> "$PD/07-01-PLAN.md"; gcommit 2026-01-01T12:00:00 "replan"
is "plan committed after REVIEWS → execute" "$(step)" execute
: > "$PD/07-01-SUMMARY.md"; is "one summary short → execute"  "$(step)" execute
: > "$PD/07-02-SUMMARY.md"
is "all summaries, no VERIFICATION → verifier" "$(step)" verifier
fm VERIFICATION.md gaps_found; is "gaps_found → gaps"          "$(step)" gaps
fm VERIFICATION.md passed;     is "passed → verify-work"       "$(step)" verify-work
fm HUMAN-UAT.md partial;       is "partial UAT → verify-work"  "$(step)" verify-work
fm HUMAN-UAT.md complete;      is "UAT complete → code-review (missing)" "$(step)" code-review
fm REVIEW.md issues_found;     is "issues_found, no FIX → code-review" "$(step)" code-review
: > "$PD/07-REVIEW-FIX.md";    is "FIX present → ui-review"     "$(step)" ui-review
: > "$PD/07-UI-REVIEW.md";     is "UI-REVIEW → secure"          "$(step)" secure
fm SECURITY.md verified "threats_open: 2"; is "2 open threats → secure" "$(step)" secure
fm SECURITY.md verified "threats_open: 0"; is "0 open → done"  "$(step)" "done"

section "details"
is "done run= is gsd-finish" "$("$NEXT" 7 --repo "$REPO" | sed -n 's/^run=//p')" gsd-finish
is "--all lists every remaining step" "$("$NEXT" 7 --repo "$REPO" --all | grep -c '^step=')" 1
rm "$PD/07-REVIEWS.md" "$PD/07-UI-REVIEW.md"
is "--all with two gaps lists 3 (review, ui-review, done)" "$("$NEXT" 7 --repo "$REPO" --all | grep -c '^step=')" 3
is "--json emits one object" "$("$NEXT" 7 --repo "$REPO" --json | head -1 | grep -c '"step":"review"')" 1
is "review has a then= replan" "$("$NEXT" 7 --repo "$REPO" | sed -n 's/^then=//p')" "/gsd-plan-phase 7 --reviews"
is "story via cu_ in dir name counts" "$(mkdir -p "$REPO/.planning/phases/08-x-cu_abc" && "$NEXT" 8 --repo "$REPO" | sed -n 's/^step=//p')" discuss
is "decimal phase dir" "$(mkdir -p "$REPO/.planning/phases/7.1-fix" && "$NEXT" 7.1 --repo "$REPO" | sed -n 's/^step=//p')" story
"$NEXT" 9 --repo "$REPO" >/dev/null 2>&1; is "missing phase dir → exit 1" "$?" 1

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
