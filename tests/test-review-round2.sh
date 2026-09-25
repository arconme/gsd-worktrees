#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are read inside check()'s eval strings
# Regression coverage for the 2026-09-25 full-code review (docs/fix-plan.md,
# R01–R12). Every repo is a throwaway fixture; no real remote is touched.
set -uo pipefail
PKG=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export PATH="$PKG/bin:$PATH"
unset GSD_PROVIDER GSD_AGENT GSD_AGENT_COMMAND GSD_LOCK_HELD
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '      %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
section() { printf '\n%s\n' "$1"; }
repo() {  # $1=dir — a repo on main with a one-phase roadmap
  mkdir -p "$1/.planning"; git -C "$1" init -qb main
  printf '# Roadmap\n### Phase 1: first\n### Phase 2: second\n' > "$1/.planning/ROADMAP.md"
}
commit() { git -C "$1" add -A; git -C "$1" commit -qm "${2:-c}"; }
# shellcheck source=../lib/common.sh
. "$PKG/lib/common.sh"
# shellcheck source=../lib/provider.sh
. "$PKG/lib/provider.sh"

section "R01 — install/test values are shell commands, not word lists"
R="$WORK/r01"; repo "$R"
printf 'install = echo one > a.txt && echo two > b.txt\n' > "$R/.gsd.conf"; commit "$R"
(cd "$R" && gsd-wt-new --phase 1 --install) > "$WORK/out" 2>&1
WT="$WORK/r01-worktrees/phase-1-first"
check "foreground install runs every part of a compound command" \
  '[ -f "$WT/a.txt" ] && [ -f "$WT/b.txt" ] && [ "$(cat "$WT/a.txt")" = one ]'
check "foreground install records ok" '[ "$(cat "$WT/.gsd-install.status")" = ok ]'
printf 'install = true && false\n' > "$R/.gsd.conf"; commit "$R"
(cd "$R" && gsd-wt-new --phase 2) > "$WORK/out" 2>&1
WT2="$WORK/r01-worktrees/phase-2-second"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$(cat "$WT2/.gsd-install.status")" = running ] || break; sleep 1; done
check "background install: a failing second command records fail, not ok" \
  '[ "$(cat "$WT2/.gsd-install.status")" = fail ]'

R="$WORK/r01t"; repo "$R"
printf 'test = true && false\n' > "$R/.gsd.conf"; commit "$R"
git -C "$R" worktree add -qb phase-1-x "$WORK/r01t-wt"
touch "$WORK/r01t-wt/feature"; commit "$WORK/r01t-wt"
if (cd "$R" && gsd-wt-finish 1) > "$WORK/out" 2>&1; then bad "a failing compound test command blocks the finish"
else check "a failing compound test command blocks the finish" 'grep -q "tests failed" "$WORK/out" && [ -d "$WORK/r01t-wt" ]'; fi

section "R02 — a non-executable pre-merge check is refused, not skipped"
R="$WORK/r02"; repo "$R"; mkdir -p "$R/scripts"
printf 'test = none\n' > "$R/.gsd.conf"
printf '#!/bin/sh\nexit 1\n' > "$R/scripts/gsd-premerge-check.sh"; chmod -x "$R/scripts/gsd-premerge-check.sh"
commit "$R"
git -C "$R" worktree add -qb phase-1-x "$WORK/r02-wt"
touch "$WORK/r02-wt/feature"; commit "$WORK/r02-wt"
before=$(git -C "$R" rev-parse HEAD)
if (cd "$R" && gsd-wt-finish 1) > "$WORK/out" 2>&1; then bad "finish refuses a non-executable pre-merge check"
else check "finish refuses a non-executable pre-merge check" 'grep -q "not executable" "$WORK/out"'; fi
check "nothing merged, worktree kept" '[ "$before" = "$(git -C "$R" rev-parse HEAD)" ] && [ -d "$WORK/r02-wt" ]'

section "R04 — deprecated GSD_AGENT never beats --agent-command"
R="$WORK/r04"; mkdir -p "$R"
GSD_AGENT=my-legacy-agent gsd_provider_resolve "$R" "" "/opt/bin/real-agent"
check "--agent-command wins over GSD_AGENT" '[ "$GSD_AGENT_COMMAND_RESOLVED" = /opt/bin/real-agent ]'
GSD_AGENT=my-legacy-agent GSD_AGENT_COMMAND=/opt/bin/env-agent gsd_provider_resolve "$R" "" ""
check "GSD_AGENT_COMMAND wins over GSD_AGENT" '[ "$GSD_AGENT_COMMAND_RESOLVED" = /opt/bin/env-agent ]'
GSD_AGENT=my-legacy-agent gsd_provider_resolve "$R" "" ""
check "GSD_AGENT alone still selects a custom executable" \
  '[ "$GSD_PROVIDER_RESOLVED" = custom ] && [ "$GSD_AGENT_COMMAND_RESOLVED" = my-legacy-agent ]'

section "R05 — concurrent gsd-wt-new runs for one phase reuse, not crash"
R="$WORK/r05"; repo "$R"; printf 'install = none\n' > "$R/.gsd.conf"; commit "$R"
(cd "$R" && gsd-wt-new --phase 1) > "$WORK/a" 2>&1 & a=$!
(cd "$R" && gsd-wt-new --phase 1) > "$WORK/b" 2>&1 & b=$!
wait $a; ra=$?; wait $b; rb=$?
check "both runs succeed" '[ "$ra" = 0 ] && [ "$rb" = 0 ]' || cat "$WORK/a" "$WORK/b"
check "exactly one phase-1 branch" '[ "$(git -C "$R" for-each-ref "refs/heads/phase-1-*" | wc -l | tr -d " ")" = 1 ]'
check "lock released afterwards" '[ ! -d "$R/.git/gsd-cmd.lock" ]'

section "R06 — planning-repair --check: no roadmap is not damage"
R="$WORK/r06"; mkdir -p "$R/.planning"; git -C "$R" init -qb main
gsd-planning-repair --check --repo "$R" > "$WORK/out" 2>&1; rc=$?
check "exit 0 when .planning/ROADMAP.md is missing" '[ "$rc" = 0 ]'

section "R07 — doctor JSON says whether the repo uses GSD"
R="$WORK/r07"; mkdir -p "$R"; git -C "$R" init -qb main
out=$(gsd-doctor --repo "$R" --json 2>/dev/null || true)
check "plain repo → gsd_repo false" 'printf "%s" "$out" | grep -q "\"gsd_repo\":false"'
check "JSON stays one parseable object" 'printf "%s" "$out" | python3 -c "import json,sys; json.load(sys.stdin)"'
out=$(gsd-doctor --repo "$WORK/r05" --json 2>/dev/null || true)
check "GSD repo → gsd_repo true" 'printf "%s" "$out" | grep -q "\"gsd_repo\":true"'

section "R09 — npm test detection reads scripts.test only"
R="$WORK/r09"; mkdir -p "$R"
printf '{\n  "dependencies": { "test": "^1.0.0" }\n}\n' > "$R/package.json"
check "a dependency named test is not a test script" '[ -z "$(gsd_test_cmd "$R")" ]'
printf '{\n  "scripts": { "build": "tsc", "test": "jest" }\n}\n' > "$R/package.json"
check "scripts.test → npm test" '[ "$(gsd_test_cmd "$R")" = "npm test" ]'

section "R12 — gsd-start -p says when it ignores a description"
gsd-start -p 1 "some text" --repo "$WORK/r05" --no-launch > "$WORK/out" 2>&1 || true
check "warning names the ignored text" 'grep -q "ignoring \"some text\"" "$WORK/out"'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
