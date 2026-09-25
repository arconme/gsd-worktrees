#!/usr/bin/env bash
# test-commands.sh — command paths no other suite exercised: gsd-derive-port,
# gsd-start's refusals / --insert / -p / --flow, a conflicting finish, stale
# lock reclaim, gsd-init's docs detection, and gsd-finish --pr.
# CI-safe: gsd-sdk and gh are stubbed; remotes are local bare repos.
# (gsd-clickup is deliberately not covered here — it is due for a redesign.)
set -uo pipefail
PKG=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export PATH="$WORK/stub:$PKG/bin:$PATH"
unset GSD_PROVIDER GSD_AGENT GSD_AGENT_COMMAND GSD_LOCK_HELD GSD_SKIP_GUARD
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/      /'; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { if grep -q -- "$2" "$3"; then ok "$1"; else bad "$1" "$(tail -5 "$3")"; fi; }
fails() { local name=$1; shift; if "$@" > "$WORK/out" 2>&1; then bad "$name" "unexpected success"; else ok "$name"; fi; }
section() { printf '\n%s\n' "$1"; }
commit() { git -C "$1" add -A; git -C "$1" commit -qm "${2:-c}"; }

# ── stubs ────────────────────────────────────────────────────────────────────
mkdir -p "$WORK/stub"
# gsd-sdk: phase.add appends the next integer phase; phase.insert adds a
# zero-padded decimal after phase $3 (as gsd-sdk 1.42 does) and prints JSON.
cat > "$WORK/stub/gsd-sdk" <<'SDK'
#!/usr/bin/env bash
case "$1 $2" in
  "query phase.add")
    rm="$5/.planning/ROADMAP.md"
    n=$(grep -oE '^### Phase [0-9]+:' "$rm" | grep -oE '[0-9]+' | sort -n | tail -1)
    printf '\n### Phase %s: %s\n' "$((n + 1))" "$3" >> "$rm" ;;
  "query phase.insert")
    rm="$6/.planning/ROADMAP.md"; num="$(printf '%02d' "$3").1"
    printf '\n### Phase %s: %s (INSERTED)\n' "$num" "$4" >> "$rm"
    slug=$(printf '%s' "$4" | tr ' ' '-')
    printf '{\n  "phase_number": "%s",\n  "slug": "%s"\n}\n' "$num" "$slug" ;;
  *) echo "stub gsd-sdk: unsupported $*" >&2; exit 1 ;;
esac
SDK
# gh: record the call, print a PR URL.
cat > "$WORK/stub/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
echo "https://github.com/example/shop/pull/1"
GH
chmod +x "$WORK/stub/gsd-sdk" "$WORK/stub/gh"
export GH_LOG="$WORK/gh.log"

project() {  # $1=dir — repo on main + bare origin, roadmap with phase 1
  git init -q --bare -b main "$1.git"
  mkdir -p "$1/.planning/phases"; git -C "$1" init -qb main
  printf '# Roadmap\n\n### Phase 1: catalog\n' > "$1/.planning/ROADMAP.md"
  printf 'install = none\ntest = none\n' > "$1/.gsd.conf"
  commit "$1" init; git -C "$1" remote add origin "$1.git"; git -C "$1" push -qu origin main
}

section "gsd-derive-port — base + phase number"
port_on() {  # $1=branch → port for base 3000
  local d="$WORK/port-$RANDOM"; git init -qb "$1" "$d"; git -C "$d" commit -qm i --allow-empty
  (cd "$d" && gsd-derive-port 3000 2>&1)
}
is "phase-7-x → 3007"                 "$(port_on phase-7-x)" 3007
is "phase-12-x → 3012"                "$(port_on phase-12-x)" 3012
is "phase-3.1-x uses the integer part" "$(port_on phase-3.1-x)" 3003
is "padded phase-08.1-x is not octal"  "$(port_on phase-08.1-x)" 3008
is "a non-phase branch → the base"     "$(port_on main)" 3000
is "outside git → the base"            "$(cd "$WORK" && gsd-derive-port 3000)" 3000
fails "a non-numeric base is refused"  gsd-derive-port abc

section "gsd-start — refusals"
R="$WORK/shop"; project "$R"
fails "a bare description is refused (must say -n/-p/--insert)" bash -c 'cd "$1" && gsd-start "cart" --no-launch' _ "$R"
has   "…and the refusal lists the three choices" "gsd-start -n" "$WORK/out"
fails "-n and -p together are refused"  bash -c 'cd "$1" && gsd-start -n x -p 1 --no-launch' _ "$R"
fails "-p of a phase not in the roadmap" bash -c 'cd "$1" && gsd-start -p 9 --no-launch' _ "$R"
has   "…and says so"                    "phase 9 not found" "$WORK/out"
fails "re-claiming an existing title"   bash -c 'cd "$1" && gsd-start -n "Catalog" --no-launch' _ "$R"

section "gsd-start — claim, attach, insert, flow mode"
(cd "$R" && gsd-start -n "shopping cart" --no-launch) > "$WORK/out" 2>&1
is  "-n claims phase 2"          "$?" 0
has "…prints the discuss launch" "gsd-discuss-phase" "$WORK/out"
check_wt() { git -C "$R" worktree list | grep -q "phase-$1-"; }
if check_wt 2; then ok "…and creates the phase-2 worktree"; else bad "…and creates the phase-2 worktree"; fi
is  "…and pushes the claim"      "$(git --git-dir="$R.git" show main:.planning/ROADMAP.md | grep -c '^### Phase 2: shopping cart')" 1
(cd "$R" && gsd-start -p 2 --no-launch) > "$WORK/out" 2>&1
is  "-p re-attaches (idempotent)" "$?" 0
is  "…without a second worktree"  "$(git -C "$R" worktree list | grep -c 'phase-2-')" 1
(cd "$R" && gsd-start --insert 1 "price bug" --no-launch) > "$WORK/out" 2>&1
is  "--insert claims a padded decimal phase" "$?" 0
if check_wt 01.1; then ok "…on a phase-01.1 worktree (guard accepts it)"; else bad "…on a phase-01.1 worktree (guard accepts it)" "$(tail -3 "$WORK/out")"; fi
(cd "$R" && gsd-start -p 2 --flow --no-launch) > "$WORK/out" 2>&1
has "--flow prints the gsd-flow launch" "gsd-flow" "$WORK/out"

section "gsd-wt-finish — a conflicting merge aborts cleanly"
R="$WORK/conflict"; project "$R"
printf 'base\n' > "$R/shared.txt"; commit "$R" base-file; git -C "$R" push -q
git -C "$R" worktree add -qb phase-1-catalog "$WORK/conflict-wt"
printf 'phase version\n' > "$WORK/conflict-wt/shared.txt"; commit "$WORK/conflict-wt" phase-edit
printf 'main version\n' > "$R/shared.txt"; commit "$R" main-edit; git -C "$R" push -q
before=$(git -C "$R" rev-parse HEAD)
fails "finish refuses"               bash -c 'cd "$1" && gsd-wt-finish 1' _ "$R"
has   "…naming the conflict"         "merge conflict" "$WORK/out"
is    "…main HEAD unchanged"         "$(git -C "$R" rev-parse HEAD)" "$before"
if [ -f "$R/.git/MERGE_HEAD" ]; then bad "…no merge left in progress"; else ok "…no merge left in progress"; fi
is    "…main working tree clean"     "$(git -C "$R" status --porcelain)" ""
if [ -d "$WORK/conflict-wt" ]; then ok "…worktree kept"; else bad "…worktree kept"; fi
is    "…origin untouched"            "$(git --git-dir="$R.git" rev-parse main)" "$before"

section "checkout lock — a crashed run's lock is reclaimed"
R="$WORK/lock"; project "$R"
mkdir "$R/.git/gsd-cmd.lock"; echo 999999 > "$R/.git/gsd-cmd.lock/pid"
(cd "$R" && gsd-wt-new --phase 1) > "$WORK/out" 2>&1
is  "the command still runs"      "$?" 0
has "…after reclaiming the lock"  "reclaimed stale gsd lock" "$WORK/out"
if [ -d "$R/.git/gsd-cmd.lock" ]; then bad "…and releases it at the end"; else ok "…and releases it at the end"; fi

section "gsd-init — picks ingest when planning docs exist"
R="$WORK/docs"; mkdir -p "$R/docs"; git -C "$R" init -qb main
printf '# PRD\n' > "$R/docs/PRD-checkout.md"; commit "$R" docs
(cd "$R" && gsd-init --provider claude --no-launch) > "$WORK/out" 2>&1
has "a PRD → /gsd-ingest-docs" "gsd-ingest-docs" "$WORK/out"
R="$WORK/nodocs"; mkdir -p "$R"; git -C "$R" init -qb main; printf 'x\n' > "$R/a.txt"; commit "$R" code
(cd "$R" && gsd-init --provider claude --no-launch) > "$WORK/out" 2>&1
has "no docs → /gsd-new-project" "gsd-new-project" "$WORK/out"

section "gsd-finish --pr — push + open a PR, keep the worktree"
R="$WORK/pr"; project "$R"
git -C "$R" worktree add -qb phase-1-catalog "$WORK/pr-wt"
printf 'feature\n' > "$WORK/pr-wt/f.txt"; commit "$WORK/pr-wt" feature
: > "$GH_LOG"
(cd "$R" && gsd-finish 1 --pr) > "$WORK/out" 2>&1
is  "--pr succeeds"                   "$?" 0
if git --git-dir="$R.git" rev-parse -q --verify refs/heads/phase-1-catalog >/dev/null; then ok "…branch pushed"; else bad "…branch pushed" "$(tail -4 "$WORK/out")"; fi
has "…gh pr create, base main"        "pr create.*--base main" "$GH_LOG"
has "…head is the phase branch"       "--head phase-1-catalog" "$GH_LOG"
if [ -d "$WORK/pr-wt" ]; then ok "…worktree kept"; else bad "…worktree kept"; fi
is  "…nothing merged into main"       "$(git -C "$R" log --oneline main | grep -c feature)" 0

section "lint — bash 3.2 traps"
# macOS bash 3.2 in a UTF-8 locale reads "$VAR…" as a variable named VAR plus
# the first byte of "…" → "unbound variable" under set -u. Worse, with the lock's
# EXIT trap installed the script then exits 0, so the crash looks like success.
# Always brace a variable that touches a non-ASCII character: ${VAR}…
risky=$(cd "$PKG" && LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~[:space:]]' \
          bin/* lib/*.sh install.sh shims/scripts/*.sh shims/scripts/hooks/*.sh || true)
is "no \$VAR directly followed by a non-ASCII character" "$risky" ""

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
