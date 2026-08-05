#!/usr/bin/env bash
#
# test-planning-reconcile.sh — regression tests for the .planning merge fix.
#
# Fixtures are the two real corruptions from medyour-platform, checked in under
# tests/fixtures/ so the tests run anywhere:
#
#   phase-11-merge/   the raw `git merge` result that produced today's damage
#                     (ROADMAP: phases 10 + 11 listed twice with contradictory
#                     marks; STATE: two frontmatter blocks, duplicate focus /
#                     position / velocity lines). Ground truth for its counters
#                     is 30 phases / 13 complete / 111 plans / 111 summaries /
#                     43% — neither frontmatter block had it.
#   2026-08-02/       the earlier corruption, which also carries a table row
#                     that /gsd-fast appended past EOF.
#
# Run:  tests/test-planning-reconcile.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
FIX="$HERE/fixtures"
ENGINE="$PKG/lib/gsd_planning.py"

PASS=0
FAIL=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok()   { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '      %s\n' "$2"; }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }

# Build a .planning tree from a fixture: the two markdown files plus empty
# PLAN/SUMMARY files, which is all compute_truth() counts.
stage() {  # $1=fixture name  $2=dest dir
  local src="$FIX/$1" dest="$2"
  mkdir -p "$dest/.planning/phases"
  cp "$src/ROADMAP.md" "$src/STATE.md" "$dest/.planning/"
  local n=0 phase
  while read -r phase; do
    [ -n "$phase" ] || continue
    mkdir -p "$dest/.planning/phases/$phase"
  done < <(cut -d/ -f1 "$src/plans.txt" | sort -u)
  while read -r rel; do
    [ -n "$rel" ] || continue
    : > "$dest/.planning/phases/$rel"
    n=$((n + 1))
  done < "$src/plans.txt"
}

section() { printf '\n%s\n' "$1"; }

# ── 1. the phase-11 merge: counters must be RECOMPUTED, not picked ───────────
section "phase-11 merge — counters recomputed from ground truth"
stage phase-11-merge "$WORK/a"
python3 "$ENGINE" repair "$WORK/a/.planning" > "$WORK/a.log" 2>&1
FM="$(sed -n '/^---$/,/^---$/p' "$WORK/a/.planning/STATE.md")"
is "total_phases is 30"     "$(grep -c 'total_phases: 30' <<<"$FM")"     1
is "completed_phases is 13" "$(grep -c 'completed_phases: 13' <<<"$FM")" 1
is "total_plans is 111"     "$(grep -c 'total_plans: 111' <<<"$FM")"     1
is "completed_plans is 111" "$(grep -c 'completed_plans: 111' <<<"$FM")" 1
is "percent is 43"          "$(grep -c 'percent: 43' <<<"$FM")"          1
is "exactly one frontmatter block" "$(grep -c '^---$' "$WORK/a/.planning/STATE.md")" 2
for key in status stopped_at last_updated last_activity; do
  is "one '$key:' in frontmatter" "$(grep -c "^$key:" <<<"$FM")" 1
done

section "phase-11 merge — single-value lines take the incoming branch's value"
# Verified against the real merge parents: develop said 'planning' / Phase 11,
# the phase-11 branch said 'ready_to_plan' / Phase 12, and the hand repair kept
# the branch's. union writes ours-then-theirs, so last-occurrence == theirs.
is "status is the branch's"  "$(grep -c '^status: ready_to_plan' <<<"$FM")" 1
is "focus is Phase 12"       "$(grep -c '^\*\*Current focus:\*\* Phase 12' "$WORK/a/.planning/STATE.md")" 1
is "Current Position Phase 12" \
   "$(awk '/^## Current Position/,/^## [^C]/' "$WORK/a/.planning/STATE.md" | grep -c '^Phase: 12')" 1

section "phase-11 merge — checklist and tables keep first position, best content"
is "one Phase 10 checklist entry" "$(grep -c '^- \[.\] \*\*Phase 10:' "$WORK/a/.planning/ROADMAP.md")" 1
is "one Phase 11 checklist entry" "$(grep -c '^- \[.\] \*\*Phase 11:' "$WORK/a/.planning/ROADMAP.md")" 1
is "Phase 11 survives as [x]"     "$(grep -c '^- \[x\] \*\*Phase 11:' "$WORK/a/.planning/ROADMAP.md")" 1
is "Phase 11 keeps '(completed 2026-08-05)'" \
   "$(grep -c '^- \[x\] \*\*Phase 11:.*(completed 2026-08-05)$' "$WORK/a/.planning/ROADMAP.md")" 1
# Trap 3: the stale '- [ ] Phase 11' sat ABOVE the correct '- [x] Phase 11', so
# keeping the later line would have pushed phase 11 below phase 10's duplicate.
is "phases stay in numeric order" \
   "$(grep -o '^- \[.\] \*\*Phase [0-9.]*' "$WORK/a/.planning/ROADMAP.md" | sed 's/.*Phase //' | sort -c -V 2>&1 && echo sorted)" \
   "sorted"
is "one Phase 11 progress row" "$(grep -c '^| 11\. ' "$WORK/a/.planning/ROADMAP.md")" 1
is "Phase 11 row says Complete" "$(grep -c '^| 11\..*| 15/15 | Complete' "$WORK/a/.planning/ROADMAP.md")" 1

# ── 2. trap 1: history must survive ──────────────────────────────────────────
section "history is never damaged (trap 1)"
for fixture in phase-11-merge 2026-08-02; do
  stage "$fixture" "$WORK/h-$fixture"
  before="$(awk '/^## Session Continuity/,0' "$FIX/$fixture/STATE.md")"
  python3 "$ENGINE" repair "$WORK/h-$fixture/.planning" >/dev/null 2>&1
  after="$(awk '/^## Session Continuity/,0' "$WORK/h-$fixture/.planning/STATE.md")"
  if [ "$before" = "$after" ]; then
    ok "$fixture: ## Session Continuity is byte-identical"
  else
    bad "$fixture: ## Session Continuity changed" "$(diff <(echo "$before") <(echo "$after") | head -5)"
  fi
  is "$fixture: every 'Resume file:' entry kept" \
     "$(grep -c '^Resume file:' <<<"$after")" "$(grep -c '^Resume file:' <<<"$before")"
done

# ── 3. idempotence + the check gate ──────────────────────────────────────────
section "idempotence and --check"
stage phase-11-merge "$WORK/i"
python3 "$ENGINE" repair --check "$WORK/i/.planning" >/dev/null 2>&1
is "--check on a corrupt tree exits 1" "$?" 1
python3 "$ENGINE" repair "$WORK/i/.planning" >/dev/null 2>&1
cp "$WORK/i/.planning/ROADMAP.md" "$WORK/i-road" && cp "$WORK/i/.planning/STATE.md" "$WORK/i-state"
python3 "$ENGINE" repair "$WORK/i/.planning" >/dev/null 2>&1
if diff -q "$WORK/i-road" "$WORK/i/.planning/ROADMAP.md" >/dev/null \
   && diff -q "$WORK/i-state" "$WORK/i/.planning/STATE.md" >/dev/null; then
  ok "a second repair changes nothing"
else
  bad "a second repair changed the files"
fi
python3 "$ENGINE" repair --check "$WORK/i/.planning" >/dev/null 2>&1
is "--check on a repaired tree exits 0" "$?" 0

# ── 4. the 2026-08-02 corruption, including the row past EOF ─────────────────
section "2026-08-02 corruption"
stage 2026-08-02 "$WORK/b"
out="$(python3 "$ENGINE" repair --check "$WORK/b/.planning" 2>&1)"
for n in 5 6 7 8; do
  is "Phase $n duplicate checklist entry found" \
     "$(grep -c "duplicate checklist entry for Phase $n\$" <<<"$out")" 1
done
is "the row /gsd-fast left past EOF is reported" \
   "$(grep -c 'table row outside any table' <<<"$out")" 1
python3 "$ENGINE" repair "$WORK/b/.planning" >/dev/null 2>&1
is "the stray row is preserved, not silently re-homed" \
   "$(grep -c 'gitignore apps/mobile/design/verification' "$WORK/b/.planning/STATE.md")" 1
for n in 5 6 7 8; do
  is "one Phase $n checklist entry after repair" \
     "$(grep -c "^- \[.\] \*\*Phase $n:" "$WORK/b/.planning/ROADMAP.md")" 1
done

# ── 5. end-to-end: a real git merge through the driver ───────────────────────
# Reproduces the exact shape of the real corruption: two sessions each flip a
# DIFFERENT phase's line, and the lines are adjacent, so the two edits land in
# one overlapping hunk. That is what makes union keep all four lines.
section "end-to-end: git merge through the gsd-planning driver"
E2E="$WORK/e2e"
mkdir -p "$E2E/.planning/phases/01-a" "$E2E/.planning/phases/02-b"
git init -q "$E2E"
git -C "$E2E" config user.email t@example.com
git -C "$E2E" config user.name test
git -C "$E2E" config merge.gsd-planning.driver "$PKG/bin/gsd-planning-merge %O %A %B %P"
: > "$E2E/.planning/phases/01-a/01-01-PLAN.md"
: > "$E2E/.planning/phases/01-a/01-01-SUMMARY.md"
: > "$E2E/.planning/phases/02-b/02-01-PLAN.md"
printf '.planning/ROADMAP.md merge=gsd-planning\n.planning/STATE.md merge=gsd-planning\n' \
  > "$E2E/.gitattributes"

roadmap() {  # $1/$2 = phase 1/2 checklist line tail, $3/$4 = their progress cells
  cat > "$E2E/.planning/ROADMAP.md" <<EOF
# Roadmap

## Phases

- [$1] **Phase 1: Alpha** - first phase$2
- [$3] **Phase 2: Beta** - second phase$4

## Phase Details

### Phase 1: Alpha

Goal: alpha.

### Phase 2: Beta

Goal: beta.

## Progress

| Phase | Plans | Status | Completed |
|-------|-------|--------|-----------|
| 1. Alpha | $5 |
| 2. Beta | $6 |
EOF
}

state() {  # $1=status  $2=focus phase  $3=completed_phases  $4=timestamp
  cat > "$E2E/.planning/STATE.md" <<EOF
---
milestone: v1.0
status: $1
stopped_at: Phase $2 pending
last_updated: "$4"
progress:
  total_phases: 9
  completed_phases: $3
  total_plans: 9
  completed_plans: 9
  percent: 11
---

# Project State

**Current focus:** Phase $2

## Current Position

Phase: $2
Status: $1

Progress: [░░░░░░░░░░] 0%

## Session Continuity

Last session: 2026-01-01T00:00:00.000Z
Stopped at: one
Resume file: a.md
Last session: 2026-01-02T00:00:00.000Z
Stopped at: two
Resume file: b.md
EOF
}

roadmap ' ' '' ' ' '' '0/TBD | Not started | - ' '0/TBD | Not started | - '
state planning 1 0 '2026-01-01T00:00:00.000Z'
git -C "$E2E" add -A
git -C "$E2E" commit -qm base
BASE_BRANCH="$(git -C "$E2E" branch --show-current)"

# The phase-1 session finishes phase 1.
git -C "$E2E" checkout -qb phase-1
roadmap 'x' ' (completed 2026-03-01)' ' ' '' '1/1 | Complete | 2026-03-01 ' '0/TBD | Not started | - '
state ready_to_plan 2 1 '2026-03-01T00:00:00.000Z'
git -C "$E2E" commit -qam "phase 1 done"

# In parallel, another session finishes phase 2 on the base branch.
git -C "$E2E" checkout -q "$BASE_BRANCH"
roadmap ' ' '' 'x' ' (completed 2026-03-02)' '0/TBD | Not started | - ' '2/2 | Complete | 2026-03-02 '
state executing 2 1 '2026-03-02T00:00:00.000Z'
git -C "$E2E" commit -qam "phase 2 done in a parallel session"
git -C "$E2E" tag diverged

if git -C "$E2E" merge -q --no-ff phase-1 -m "Merge phase-1" >/dev/null 2>&1; then
  ok "the merge completes without conflicts"
else
  bad "the merge conflicted"
fi

R="$E2E/.planning/ROADMAP.md"
S="$E2E/.planning/STATE.md"
is "driver left one Phase 1 checklist entry" "$(grep -c '^- \[.\] \*\*Phase 1:' "$R")" 1
is "driver left one Phase 2 checklist entry" "$(grep -c '^- \[.\] \*\*Phase 2:' "$R")" 1
is "both phases survive as [x]"              "$(grep -c '^- \[x\] \*\*Phase' "$R")" 2
is "each side's completion date survives"    "$(grep -c '(completed 2026-03-0[12])$' "$R")" 2
is "driver left one Phase 1 progress row"    "$(grep -c '^| 1\. Alpha' "$R")" 1
is "driver left one Phase 2 progress row"    "$(grep -c '^| 2\. Beta' "$R")" 1
is "driver left one '### Phase 1' section"   "$(grep -c '^### Phase 1:' "$R")" 1
is "driver left one frontmatter block"       "$(grep -c '^---$' "$S")" 2
is "driver left one 'status:'"               "$(grep -c '^status:' "$S")" 1
is "driver left one 'stopped_at:'"           "$(grep -c '^stopped_at:' "$S")" 1
is "driver left one '**Current focus:**'"    "$(grep -c '^\*\*Current focus:\*\*' "$S")" 1
is "driver left one 'Phase:' in position"    "$(awk '/^## Current Position/,/^## S/' "$S" | grep -c '^Phase:')" 1
is "driver kept both history entries"        "$(grep -c '^Resume file:' "$S")" 2

python3 "$ENGINE" repair "$E2E/.planning" >/dev/null 2>&1
is "repair recomputes total_phases from the roadmap"  "$(grep -c '  total_phases: 2' "$S")" 1
is "repair recomputes completed_phases"               "$(grep -c '  completed_phases: 2' "$S")" 1
is "repair recomputes total_plans from disk"          "$(grep -c '  total_plans: 2' "$S")" 1
is "repair recomputes completed_plans from disk"      "$(grep -c '  completed_plans: 1' "$S")" 1
is "repair recomputes percent"                        "$(grep -c '  percent: 100' "$S")" 1
python3 "$ENGINE" repair --check "$E2E/.planning" >/dev/null 2>&1
is "the merged tree passes --check" "$?" 0

# ── 6. the same merge WITHOUT the driver — repair still fixes it ─────────────
# The driver lives in git config, which is not versioned, so a clone that never
# ran gsd-bootstrap-repo still gets plain union. gsd-finish's post-merge repair
# has to be able to clean that up on its own.
section "no driver registered — plain union, repaired afterwards"
git -C "$E2E" config merge.gsd-planning.driver 'git merge-file -q --union %A %O %B'
git -C "$E2E" reset -q --hard diverged
git -C "$E2E" merge -q --no-ff phase-1 -m "Merge phase-1 (plain union)" >/dev/null 2>&1
is "plain union DOES duplicate the checklist entry" "$(grep -c '^- \[.\] \*\*Phase 1:' "$R")" 2
is "plain union DOES duplicate the frontmatter"     "$(grep -c '^status:' "$S")" 2
python3 "$ENGINE" repair "$E2E/.planning" >/dev/null 2>&1
is "repair alone fixes the checklist"    "$(grep -c '^- \[.\] \*\*Phase 1:' "$R")" 1
is "repair alone keeps both [x] marks"   "$(grep -c '^- \[x\] \*\*Phase' "$R")" 2
is "repair alone collapses frontmatter"  "$(grep -c '^status:' "$S")" 1
is "repair alone keeps history intact"   "$(grep -c '^Resume file:' "$S")" 2
python3 "$ENGINE" repair --check "$E2E/.planning" >/dev/null 2>&1
is "the repaired tree passes --check" "$?" 0

# ── 7. the real gsd-finish path ──────────────────────────────────────────────
# The guarantee the whole change exists for: a normal finish must never leave
# .planning self-contradictory on the base branch.
section "gsd-finish leaves the base branch coherent"
WT="$WORK/wt"
mkdir -p "$WT/repo/.planning/phases/01-a"
git init -q -b develop "$WT/repo"
git -C "$WT/repo" config user.email t@example.com
git -C "$WT/repo" config user.name test
E2E="$WT/repo"   # roadmap()/state() write into $E2E
: > "$WT/repo/.planning/phases/01-a/01-01-PLAN.md"
printf 'base = develop\nwtdir = wt\ninstall = none\n' > "$WT/repo/.gsd.conf"
printf '.planning/ROADMAP.md merge=gsd-planning\n.planning/STATE.md merge=gsd-planning\n' \
  > "$WT/repo/.gitattributes"
roadmap ' ' '' ' ' '' '0/TBD | Not started | - ' '0/TBD | Not started | - '
state planning 1 0 '2026-01-01T00:00:00.000Z'
git -C "$WT/repo" add -A && git -C "$WT/repo" commit -qm base

git -C "$WT/repo" worktree add -q -b phase-1-alpha "$WT/wt/phase-1-alpha" develop
E2E="$WT/wt/phase-1-alpha"
: > "$WT/wt/phase-1-alpha/.planning/phases/01-a/01-01-SUMMARY.md"
roadmap 'x' ' (completed 2026-03-01)' ' ' '' '1/1 | Complete | 2026-03-01 ' '0/TBD | Not started | - '
state ready_to_plan 2 1 '2026-03-01T00:00:00.000Z'
git -C "$WT/wt/phase-1-alpha" add -A
git -C "$WT/wt/phase-1-alpha" commit -qm "phase 1 done"

E2E="$WT/repo"
roadmap ' ' '' 'x' ' (completed 2026-03-02)' '0/TBD | Not started | - ' '2/2 | Complete | 2026-03-02 '
state executing 2 1 '2026-03-02T00:00:00.000Z'
git -C "$WT/repo" commit -qam "parallel session finished phase 2"

finish_out="$( cd "$WT/wt/phase-1-alpha" && PATH="$PKG/bin:$PATH" gsd-wt-finish 1 2>&1 )"
finish_rc=$?
is "gsd-wt-finish succeeds" "$finish_rc" 0
is "it reports reconciling .planning" "$(grep -c 'reconciling .planning after the phase merge' <<<"$finish_out")" 1

R="$WT/repo/.planning/ROADMAP.md"
S="$WT/repo/.planning/STATE.md"
is "develop has one Phase 1 checklist entry" "$(grep -c '^- \[.\] \*\*Phase 1:' "$R")" 1
is "develop has both phases complete"        "$(grep -c '^- \[x\] \*\*Phase' "$R")" 2
is "develop has one 'status:'"               "$(grep -c '^status:' "$S")" 1
is "develop's counters were recomputed"      "$(grep -c '  completed_phases: 2' "$S")" 1
is "develop's history is intact"             "$(grep -c '^Resume file:' "$S")" 2
( cd "$WT/repo" && PATH="$PKG/bin:$PATH" gsd-planning-repair --check >/dev/null 2>&1 )
is "develop passes --check after the finish" "$?" 0
is "the repair left no uncommitted changes"  "$(git -C "$WT/repo" status --porcelain -- .planning | wc -l | tr -d ' ')" 0

# ── 8. content the reconciler must never touch ───────────────────────────────
# Three defects found reviewing the committed fix. All three are the same class
# of failure the tool exists to prevent: silently deleting real content.
section "no collateral deletion"

# A: ROADMAP.md puts every '### Phase N:' detail AFTER '## Progress'. When the
# Progress section was bounded only at '##' it ran to EOF, so the progress-row
# dedupe reached into the phase details and deleted a numbered table row in one
# phase because another phase's detail happened to use the same number.
COLL="$WORK/collateral"
mkdir -p "$COLL/.planning/phases"
# (built with python: the injected rows contain '|', which fights every sed delimiter)
python3 - "$FIX/phase-11-merge/ROADMAP.md" "$COLL/.planning/ROADMAP.md" <<'INJECT'
import sys
src, dst = sys.argv[1], sys.argv[2]
doc = open(src).read()
table = "\n| Step | What |\n|------|------|\n| %s | who |\n"
doc = doc.replace("### Phase 20: Verify and dispense\n",
                  "### Phase 20: Verify and dispense\n" + table % "1. Scan the QR code")
doc = doc.replace("### Phase 21: Branch self-service and admin queue\n",
                  "### Phase 21: Branch self-service and admin queue\n" + table % "1. Open the queue")
open(dst, "w").write(doc)
INJECT
cp "$FIX/phase-11-merge/STATE.md" "$COLL/.planning/"
python3 "$ENGINE" repair "$COLL/.planning" >/dev/null 2>&1
is "a phase detail's numbered row survives"        "$(grep -c '^| 1\. Scan the QR code' "$COLL/.planning/ROADMAP.md")" 1
is "the same number in another phase survives too" "$(grep -c '^| 1\. Open the queue' "$COLL/.planning/ROADMAP.md")" 1
is "the real progress table is still deduped"      "$(grep -c '^| 11\. Catalogs' "$COLL/.planning/ROADMAP.md")" 1

# B: the frontmatter emitter used to rebuild from parsed keys, so any line it
# had no model for — YAML lists, comments — was dropped on the floor.
FM="$WORK/frontmatter"
mkdir -p "$FM/.planning/phases/01-a"
: > "$FM/.planning/phases/01-a/01-01-PLAN.md"
printf '# Roadmap\n\n## Phases\n\n- [x] **Phase 1: A** - a\n' > "$FM/.planning/ROADMAP.md"
cat > "$FM/.planning/STATE.md" <<'EOF'
---
milestone: v1.0
status: planning
tags:
  - alpha
  - beta
# a comment the parser has no model for
progress:
  total_phases: 9
  completed_phases: 9
status: executing
---

# Project State

## Current Position

Phase: 1
EOF
python3 "$ENGINE" repair "$FM/.planning" >/dev/null 2>&1
is "a YAML list item survives"        "$(grep -c '^  - alpha' "$FM/.planning/STATE.md")" 1
is "every list item survives"         "$(grep -c '^  - beta' "$FM/.planning/STATE.md")" 1
is "a comment survives"               "$(grep -c '^# a comment' "$FM/.planning/STATE.md")" 1
is "the list's parent key survives"   "$(grep -c '^tags:' "$FM/.planning/STATE.md")" 1
is "the duplicate key still collapses" "$(grep -c '^status:' "$FM/.planning/STATE.md")" 1
is "and takes the incoming value"     "$(grep -c '^status: executing' "$FM/.planning/STATE.md")" 1
is "counters still recomputed"        "$(grep -c '  total_phases: 1' "$FM/.planning/STATE.md")" 1

# C: --commit ran `git add` on both planning files unconditionally, which is
# fatal when one is absent. Called from gsd-finish that aborted the repair with
# the merge already committed.
NOSTATE="$WORK/nostate"
mkdir -p "$NOSTATE/.planning/phases"
git init -q "$NOSTATE"
git -C "$NOSTATE" config user.email t@example.com
git -C "$NOSTATE" config user.name test
printf '# Roadmap\n\n## Phases\n\n- [x] **Phase 1: A** - a\n' > "$NOSTATE/.planning/ROADMAP.md"
git -C "$NOSTATE" add -A && git -C "$NOSTATE" commit -qm init
printf '# Roadmap\n\n## Phases\n\n- [ ] **Phase 1: A** - a\n- [x] **Phase 1: A** - a (completed 2026-01-01)\n' \
  > "$NOSTATE/.planning/ROADMAP.md"
PATH="$PKG/bin:$PATH" gsd-planning-repair --repo "$NOSTATE" --commit >/dev/null 2>&1
is "--commit succeeds with no STATE.md" "$?" 0
is "the repair was committed"           "$(git -C "$NOSTATE" status --porcelain -- .planning | wc -l | tr -d ' ')" 0
is "the duplicate was collapsed"        "$(grep -c '^- \[.\] \*\*Phase 1:' "$NOSTATE/.planning/ROADMAP.md")" 1

# ── 9. gsd-doctor ────────────────────────────────────────────────────────────
# It diagnoses and never fixes. The read-only guarantee is the whole reason it
# is safe to run on a repo you are mid-feature in, so it is asserted, not
# assumed. (Toolkit-level findings are ignored here: they reflect the state of
# the checkout the tests run from, not the repo under inspection.)
section "gsd-doctor"

DOC="$WORK/doctor"
mkdir -p "$DOC/.planning/phases/01-a" "$DOC/scripts"
git init -q -b develop "$DOC"
git -C "$DOC" config user.email t@example.com
git -C "$DOC" config user.name test
printf '.planning/ROADMAP.md merge=union\n.planning/STATE.md merge=union\n' > "$DOC/.gitattributes"
cp "$FIX/phase-11-merge/ROADMAP.md" "$FIX/phase-11-merge/STATE.md" "$DOC/.planning/"
git -C "$DOC" add -A && git -C "$DOC" commit -qm init

out="$(PATH="$PKG/bin:$PATH" gsd-doctor --repo "$DOC" 2>&1)"
is "reports merge=union"          "$(grep -c 'still on merge=union' <<<"$out")" 1
is "reports the missing driver"   "$(grep -c 'merge driver not registered' <<<"$out")" 1
is "reports the missing hook"     "$(grep -c 'no post-merge hook' <<<"$out")" 1
is "reports missing shims"        "$(grep -c 'shims: .* missing' <<<"$out")" 1
is "reports the planning damage"  "$(grep -c 'contradicts itself' <<<"$out")" 1
is "names gsd-init as the fix"    "$([ "$(grep -c 'gsd-init' <<<"$out")" -ge 4 ] && echo yes)" yes
is "names the repair as the fix"  "$(grep -c 'gsd-planning-repair' <<<"$out")" 1

# THE guarantee: a diagnosis must not change the thing it diagnoses.
before_tree="$(git -C "$DOC" status --porcelain)"
before_cfg="$(git -C "$DOC" config --local --list | sort)"
before_files="$(find "$DOC" -type f -not -path '*/.git/*' | sort | xargs shasum 2>/dev/null | shasum)"
PATH="$PKG/bin:$PATH" gsd-doctor --repo "$DOC" >/dev/null 2>&1
is "working tree untouched"  "$(git -C "$DOC" status --porcelain)" "$before_tree"
is "git config untouched"    "$(git -C "$DOC" config --local --list | sort)" "$before_cfg"
is "no file contents changed" "$(find "$DOC" -type f -not -path '*/.git/*' | sort | xargs shasum 2>/dev/null | shasum)" "$before_files"
is "no --fix flag exists" \
   "$(PATH="$PKG/bin:$PATH" gsd-doctor --fix --repo "$DOC" 2>&1 | grep -c 'unknown argument')" 1

# Once the repo is fitted, the repo-setup findings clear.
PATH="$PKG/bin:$PATH" gsd-planning-repair --repo "$DOC" >/dev/null 2>&1
( cd "$DOC" && PATH="$PKG/bin:$PATH" gsd-bootstrap-repo ) >/dev/null 2>&1
out="$(PATH="$PKG/bin:$PATH" gsd-doctor --repo "$DOC" 2>&1)"
is "merge=union finding clears"   "$(grep -c 'still on merge=union' <<<"$out")" 0
is "driver finding clears"        "$(grep -c 'merge driver not registered' <<<"$out")" 0
is "hook finding clears"          "$(grep -c 'no post-merge hook' <<<"$out")" 0
is "planning reports coherent"    "$(grep -c '.planning is coherent' <<<"$out")" 1

printf '\n%s\n' "── $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ]
