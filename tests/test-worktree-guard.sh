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
blocked "missing phase dir cannot bypass discuss gate" gsd-plan-phase "8"
allowed "fresh phase can still discuss" gsd-discuss-phase "8"
GSD_SKIP_GUARD=1 allowed "GSD_SKIP_GUARD=1 bypasses"  gsd-plan-phase "8"
GSD_SKIP_GUARD=0 blocked "GSD_SKIP_GUARD=0 does not bypass" gsd-plan-phase "8"

section "flow = strict — zero-padded phase numbers (08/09 are not octal)"
mkrepo strict phase-8-pad 08-pad; : > "$PDIR/08-CONTEXT.md"
allowed "plan-phase 08 in phase-8 worktree passes"  gsd-plan-phase "08"
allowed "plan-phase 8 finds the 08-* dir"           gsd-plan-phase "8"
mkrepo strict phase-09-legacy 09-legacy; : > "$PDIR/09-CONTEXT.md"
allowed "phase from a phase-09-* branch pads correctly" gsd-plan-phase ""

section "flow = strict — gsd-sdk decimal inserts are zero-padded (02.1)"
mkrepo strict phase-02.1-hotfix 02.1-hotfix
blocked "02.1 plan-phase without CONTEXT is blocked"   gsd-plan-phase "02.1"
: > "$PDIR/02.1-CONTEXT.md"
allowed "02.1 plan-phase with CONTEXT passes"          gsd-plan-phase "02.1"
allowed "2.1 names the same phase as 02.1"             gsd-plan-phase "2.1"
allowed "phase taken from a phase-02.1-* branch"       gsd-discuss-phase ""
blocked "02.2 is still another phase"                  gsd-plan-phase "02.2"

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

section "install completion never bypasses strict gates"
printf 'base = develop\nflow = strict\ninstall = npm install\n' > "$REPO/.gsd.conf"
echo ok > "$REPO/.gsd-install.status"
blocked "install ok still requires review" gsd-execute-phase "7"
: > "$PDIR/07-REVIEWS.md"
allowed "install ok and review permit execution" gsd-execute-phase "7"
mkdir -p "$REPO/node_modules"
echo running > "$REPO/.gsd-install.status"
blocked "partial node_modules cannot bypass running install" gsd-execute-phase "7"
echo fail > "$REPO/.gsd-install.status"
blocked "node_modules cannot bypass failed install" gsd-execute-phase "7"
echo ok > "$REPO/.gsd-install.status"
blocked "review in wrong phase is blocked" gsd-review "--phase 9 --codex"
blocked "flow in wrong phase is blocked" gsd-flow "9"
blocked "omitted phase still enforces discuss gate" gsd-plan-phase ""
git -C "$REPO" checkout -q -b agent-untrusted
blocked "agent branch name alone is not an exemption" gsd-execute-phase "7"

section "nested workers retain phase checks"
git -C "$REPO" checkout -q phase-7-thing
git -C "$REPO" add .
git -C "$REPO" -c user.name=t -c user.email=t@t commit -qm artifacts
PARENT=$REPO
NESTED="$PARENT/.claude/worktrees/worker"
git -C "$PARENT" worktree add -q -b agent-nested "$NESTED"
REPO=$NESTED; PDIR="$REPO/.planning/phases/07-thing"
allowed "nested worker in same repository inherits phase" gsd-execute-phase "7"
blocked "nested worker cannot target another phase" gsd-execute-phase "9"
rm "$PDIR/07-REVIEWS.md"
blocked "nested worker still requires strict review" gsd-execute-phase "7"

section "ui_gates — warn (default) never blocks"
mkrepo "" phase-5-shop 05-shop
allowed "ui-phase without DESIGN/LAYOUT passes" gsd-ui-phase  "5"
allowed "ui-review without SHOTS passes"        gsd-ui-review "5"

section "ui_gates = strict — ui-phase needs the design system and a chosen layout"
echo "ui_gates = strict" >> "$REPO/.gsd.conf"
blocked "no DESIGN.md → blocked"                 gsd-ui-phase "5"
grep -q 'DESIGN.md' "$WORK/err" && ok "…the message names DESIGN.md" || bad "…the message names DESIGN.md" "$(cat "$WORK/err")"
mkdir -p "$REPO/.planning/design"; printf '# Design\n<!-- gsd:design-stub -->\n' > "$REPO/.planning/design/DESIGN.md"
blocked "stub DESIGN.md → blocked"               gsd-ui-phase "5"
printf '# Design\ntokens\n' > "$REPO/.planning/design/DESIGN.md"
blocked "filled DESIGN.md, no LAYOUT → blocked"  gsd-ui-phase "5"
printf 'sketch: .planning/sketches/001-shop\npages: /\n' > "$PDIR/05-LAYOUT.md"
mkdir -p "$REPO/.planning/sketches/001-shop"; printf -- '---\nwinner: null\n---\n' > "$REPO/.planning/sketches/001-shop/README.md"
blocked "sketch without a winner → blocked"      gsd-ui-phase "5"
printf -- '---\nwinner: A\n---\n' > "$REPO/.planning/sketches/001-shop/README.md"
allowed "design + chosen sketch + pages → allowed" gsd-ui-phase "5"
printf 'sketch: skip one button\n' > "$PDIR/05-LAYOUT.md"
allowed "sketch: skip <reason> → allowed"        gsd-ui-phase "5"

section "ui_gates = strict — ui-review needs the screenshots"
blocked "no SHOTS.md → blocked"                  gsd-ui-review "5"
printf 'skipped: no browser in CI\n' > "$PDIR/05-SHOTS.md"
allowed "a skip record → allowed"                gsd-ui-review "5"
printf 'taken: now\n' > "$PDIR/05-SHOTS.md"
allowed "screenshots → allowed"                  gsd-ui-review "5"
allowed "other commands are not UI-gated"        gsd-plan-phase "5"
rm "$PDIR/05-SHOTS.md"
rc=$(GSD_SKIP_GUARD=1 "$GUARD" --command gsd-ui-review --phase 5 --repo "$REPO" 2>/dev/null; echo $?)
[ "$rc" = 0 ] && ok "GSD_SKIP_GUARD=1 still escapes" || bad "GSD_SKIP_GUARD=1 still escapes" "rc=$rc"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
