#!/usr/bin/env bash
#
# test-worktree-guard.sh — the guard's phase-flow rule (`flow = strict`).
#
# Builds a throwaway repo with a phase worktree branch checked out, feeds the
# guard the PreToolUse(Skill) payload Claude Code sends, and asserts exit codes:
# 0 = allowed, 2 = blocked. The rule is opt-in, so the first section proves a
# repo WITHOUT `flow = strict` is untouched.
#
# Run:  tests/test-worktree-guard.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
GUARD="$PKG/bin/gsd-worktree-guard"

PASS=0; FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '      %s\n' "$2"; }
section() { printf '\n%s\n' "$1"; }

# guard <skill> <args> → exit code
guard() {
  printf '{"tool_name":"Skill","tool_input":{"skill":"%s","args":"%s"}}' "$1" "$2" \
    | CLAUDE_PROJECT_DIR="$REPO" "$GUARD" >/dev/null 2>"$WORK/err"
  echo $?
}
allowed() { local rc; rc=$(guard "$2" "$3"); if [ "$rc" = 0 ]; then ok "$1"; else bad "$1" "exit $rc: $(cat "$WORK/err")"; fi; }
blocked() { local rc; rc=$(guard "$2" "$3"); if [ "$rc" = 2 ]; then ok "$1"; else bad "$1" "expected block (2), got $rc"; fi; }

# A repo on a phase-7 branch with an empty phase dir. `install = none` keeps
# rule 3 (deps installed) out of the picture.
mkrepo() {  # $1=flow value ('' = unset)  $2=branch  $3=phase dir name
  REPO="$WORK/$RANDOM"; mkdir -p "$REPO"
  git -C "$REPO" init -q -b develop
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  { echo "base = develop"; echo "install = none"; [ -n "$1" ] && echo "flow = $1"; } > "$REPO/.gsd.conf"
  git -C "$REPO" checkout -q -b "$2"
  PDIR="$REPO/.planning/phases/$3"; mkdir -p "$PDIR"
}

section "flow unset — the rule is opt-in, nothing is blocked"
mkrepo "" phase-7-thing 07-thing
allowed "plan-phase without CONTEXT passes"     gsd-plan-phase    "7"
allowed "execute-phase without REVIEWS passes"  gsd-execute-phase "7"
allowed "secure-phase without REVIEW passes"    gsd-secure-phase  "7"

section "flow = strict — plan-phase needs discuss"
mkrepo strict phase-7-thing 07-thing
blocked "plan-phase without CONTEXT is blocked"  gsd-plan-phase "7"
allowed "plan-phase --prd skips discuss"         gsd-plan-phase "7 --prd docs/x.md"
: > "$PDIR/07-CONTEXT.md"
allowed "plan-phase with CONTEXT passes"         gsd-plan-phase "7"
allowed "discuss-phase itself is never gated"    gsd-discuss-phase "7"

section "flow = strict — execute-phase needs the cross-AI review"
blocked "execute without REVIEWS is blocked"     gsd-execute-phase "7"
allowed "execute --gaps-only skips it"           gsd-execute-phase "7 --gaps-only"
: > "$PDIR/07-REVIEWS.md"
allowed "execute with REVIEWS passes"            gsd-execute-phase "7"

section "flow = strict — secure-phase is the last gate"
blocked "secure without REVIEW is blocked"       gsd-secure-phase "7"
: > "$PDIR/07-REVIEW.md"
allowed "secure with REVIEW, no screens, passes" gsd-secure-phase "7"
: > "$PDIR/07-UI-SPEC.md"
blocked "secure with UI-SPEC but no UI-REVIEW is blocked" gsd-secure-phase "7"
: > "$PDIR/07-UI-REVIEW.md"
allowed "secure with UI-REVIEW passes"           gsd-secure-phase "7"

section "flow = strict — decimal phases and fresh claims"
mkrepo strict phase-7.1-fix 7.1-fix
blocked "7.1 plan-phase without CONTEXT is blocked" gsd-plan-phase "7.1"
: > "$PDIR/7.1-CONTEXT.md"
allowed "7.1 plan-phase with CONTEXT passes"        gsd-plan-phase "7.1"
mkrepo strict phase-8-new 08-new; rmdir "$PDIR"
allowed "no phase dir yet → nothing to order"        gsd-plan-phase "8"
GSD_SKIP_GUARD=1 allowed "GSD_SKIP_GUARD=1 bypasses"  gsd-plan-phase "8"

section "flow = strict — policy comes from the MAIN checkout, not the worktree copy"
mkrepo "" phase-7-thing 07-thing          # branch carries NO flow key
git -C "$REPO" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
git -C "$REPO" -c user.email=t@t -c user.name=t commit -q -m wt >/dev/null 2>&1
MAIN="$REPO"; WT="$WORK/wt-$RANDOM"
git -C "$MAIN" checkout -q develop
echo "flow = strict" >> "$MAIN/.gsd.conf"   # main turns it on later
git -C "$MAIN" worktree add -q "$WT" phase-7-thing
REPO="$WT"; PDIR="$WT/.planning/phases/07-thing"; mkdir -p "$PDIR"
blocked "old worktree (no flow key in its .gsd.conf) is still gated" gsd-plan-phase "7"

section "flow = strict — the older rules still fire first"
mkrepo strict phase-7-thing 07-thing
blocked "wrong phase worktree is still blocked"  gsd-plan-phase "9"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
