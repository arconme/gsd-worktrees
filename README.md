# gsd-worktrees

Parallel-session worktree orchestration for the **GSD** (Get Shit Done) planning
system — the companion toolkit that lets several agent sessions (Claude Code,
gemini, …) work on one repo at once without clobbering each other.

GSD itself provides the planning skills (`/gsd-phase`, `/gsd-discuss-phase`,
`/gsd-plan-phase`, `/gsd-execute-phase`, …) and the `gsd-sdk` CLI. This repo
provides everything around them: one-command feature start/finish, per-phase
git worktrees, claim races resolved automatically, a checkout lock, per-worktree
dev ports, ClickUp write-back, and the guard hook that keeps each command in
its right place.

## Components

**`bin/` — shared commands** (installed to `~/.local/bin`, canonical here):

| Command | What it does |
|---|---|
| `gsd-start` | Start a feature in one step: claim the phase (deterministic, parallel-safe with auto-renumber), push, create the `phase-<N>-<slug>` worktree, open/print the session. `-p <N>` re-attaches, `--insert <N>` claims a decimal hotfix phase, `--cu <id>` drives a ClickUp story. |
| `gsd-finish` | Finish from anywhere: merge the phase branch back into the base branch, push (with retry on parallel pushes), remove the worktree + branch, move the ClickUp story to its list's testing/review status (resolved per list, so differently-named statuses all work). |
| `gsd-list` | Read-only table of all phases: number, description, plan progress, lifecycle stage (live from the phase's worktree), worktree state. |
| `gsd-init` | Take a repo with no GSD to "ready for gsd-start": bootstrap + open the right init skill (`/gsd-new-project` or `/gsd-ingest-docs`). |
| `gsd-bootstrap-repo` | Fit a repo with the workflow: write `.gsd.conf`, install the frozen shims, register the guard hook, add the CLAUDE.md section + gitignore/gitattributes entries. Idempotent; no text rewriting. |
| `gsd-clickup` | Minimal ClickUp write-back helper (status + comment + subtask cascade); token in `~/.config/gsd/clickup.env`. |
| `gsd-sync` | Toolkit maintenance in one command: pull + push this repo, re-link `bin/`, and verify the reference repo's shims are current. `--check` for a dry run. |
| `gsd-wt-new` / `gsd-wt-finish` | The worktree workers behind `gsd-start`/`gsd-finish` (create with config-copy + background install; merge back locked and conflict-safe). Callable standalone. |
| `gsd-planning-repair` | Reconcile `.planning/ROADMAP.md` + `STATE.md` after a union merge and recompute their progress counters from the roadmap and the plan files on disk. `--check` is the CI guard (exit 1 on union-merge damage); `--commit` lands the repair. Run automatically by `gsd-finish` and the `post-merge` hook. |
| `gsd-planning-merge` | The git merge driver behind `merge=gsd-planning`: union both sides, then collapse every single-value line back to one value so the contradiction never lands. Registered per clone by `gsd-bootstrap-repo`, re-asserted by `gsd-finish`. |
| `gsd-doctor` | Read-only health check of a repo's GSD setup: toolkit install, shims, `.planning` merge safety, planning-file coherence, worktree hygiene. Diagnoses only — every finding names the command that fixes it. No `--fix`, by design. |
| `gsd-worktree-guard` | The guard: blocks `/gsd-phase` off the base branch, per-phase commands outside their `phase-<N>-*` worktree, and execute-phase before deps land. Invoked via the repo's hook shim. |
| `gsd-derive-port` / `gsd-dev` | Per-worktree dev ports (base + phase N) and the boot-everything launcher driven by the repo's `scripts/gsd-dev.conf`. |

## Per-repo footprint

All logic lives in this package. `gsd-bootstrap-repo` installs into a repo only:

- **`.gsd.conf`** (committed) — `base`, `wtdir`, `install`; every key optional,
  falling back to auto-detection (develop/main, `<repo>-worktrees`, lockfile).
- **`shims/` → `scripts/gsd-*.sh` + `scripts/hooks/gsd-worktree-guard.sh`** —
  frozen 7-line delegators to the PATH commands, so committed references
  (package.json dev scripts, `.claude/settings.json` hook registration, docs)
  keep working on every checkout. They never change, so there is nothing to
  sync. The port shim fails soft (bare base port) and the guard shim fails open
  on machines without the toolkit; the rest fail with an install pointer.
- **`.gitattributes`** — `.planning/ROADMAP.md` and `STATE.md` get
  `merge=gsd-planning` (repos on the old `merge=union` are migrated in place).
- **a `post-merge` hook** (`.husky/post-merge` when husky owns hooks, otherwise
  the unversioned `.git/hooks/post-merge`) — runs `gsd-planning-repair` so a
  plain `git pull` on the base branch is covered, not just `gsd-finish`.
- **`scripts/gsd-premerge-check.sh`** (optional, repo-authored — not a shim) —
  pre-merge hook `gsd-wt-finish` runs as `<script> <branch> <base>` after the
  origin sync, before the merge; nonzero aborts the finish with nothing merged.
  The home for repo-specific validations (e.g. TypeORM migration-timestamp
  collision checks). Path override: `premerge =` in `.gsd.conf`; `none` disables.

## Install

```sh
git clone git@github.com:arconme/gsd-worktrees.git
cd gsd-worktrees && ./install.sh          # symlinks into ~/.local/bin
```

Symlink mode means `git pull` updates the live commands, and edits to the live
commands land here ready to commit. Use `./install.sh --copy` for detached copies.

**Staying up to date:** run `gsd-sync` — it pulls this repo, pushes your local
commits, re-links any new commands, and verifies the reference repo's shims
are current. `gsd-sync --check` previews without changing anything.

## The loop per feature

```sh
gsd-start "customer terms rework" --cu 869e33cv4   # claim + worktree + session
# … discuss → plan → execute in the session it opens …
gsd-finish                                          # merge back, push, clean up
```

Every command self-documents: `gsd-start --help`, `gsd-finish --help`, ….

## Concurrency model (the point of all this)

- **One feature = one phase = one worktree = one session.** The main checkout
  stays on the base branch; nothing edits it directly.
- **Claims serialize through the base branch** — pulled first, pushed with a
  rebase-and-retry loop; two sessions claiming at once get distinct numbers
  (the loser auto-renumbers).
- **A local lock** (`.git/gsd-cmd.lock`) serializes gsd commands touching the
  same checkout on one machine; stale locks from crashed runs are reclaimed
  automatically (dead-PID detection).
- **Merges fail clean:** a conflicting finish aborts the merge, leaves the base
  branch pristine, and prints the resolution steps — it never wedges the shared
  checkout for other sessions.
- **`ROADMAP.md`/`STATE.md` use `merge=gsd-planning`** so parallel finishes never
  stop on trivial shared-state conflicts. The driver unions both sides (so each
  session keeps its own additions) and then reconciles: duplicated checklist
  entries, progress rows and phase sections collapse to one — `[x]` beating
  `[ ]`, at the position of the phase's first occurrence — and duplicated
  single-value lines collapse to the incoming branch's value. `gsd-finish` then
  runs `gsd-planning-repair`, which recomputes the progress counters from the
  roadmap and the `.planning/phases/*/*-PLAN.md` files on disk, because after a
  divergent merge neither side's counters are trustworthy. STATE.md's
  `## Session Continuity` history is never touched.

## The `.planning/` merge problem

`ROADMAP.md` and `STATE.md` are shared state that parallel phase sessions all
write to, so they merge automatically instead of conflicting. The original
strategy was git's built-in `union` — keep both sides — which is right for the
append-only parts of those files and wrong for every line that is a single
source of truth. When a phase branch flipped `- [ ] **Phase 11**` to `- [x]`
and the base branch had also touched the adjacent line, union kept both, and
the roadmap ended up claiming Phase 11 was simultaneously complete and not
started. The frontmatter went the same way: two `status:`/`stopped_at:` values
and two full sets of progress counters.

The fix is three layers, because the damage has three entry points:

1. **`merge=gsd-planning`** (the driver) — union first, so nobody loses their
   additions, then reconcile. Keyed content (checklist entries, progress rows,
   `### Phase N` sections) collapses to one per phase, keeping the position of
   the phase's *first* occurrence and the content of its *best* one — `[x]`
   beats `[ ]`, a real status beats "Not started", and among equals the longer
   line wins because it carries the `(completed <date>)` suffix. Keeping the
   later line instead would push phases out of numeric order, which is exactly
   what happened in one hand repair. Single-value lines collapse to their last
   copy, which is the incoming branch's, because union writes ours-then-theirs.
2. **`gsd-planning-repair`** — run by `gsd-finish` after *both* of its merge
   points (the phase merge, and the `pull` on the push-retry path, which fires
   precisely when a parallel session moved the base branch), and by the
   `post-merge` hook for plain `git pull`. It redoes the structural pass and
   then recomputes the progress counters, which a merge cannot get right by
   picking a side: after one real phase-11 merge the two candidates were
   30 phases/12 complete/96 plans and 28/11/103, and the truth was 30/13/111.
   Counters come from the roadmap's `### Phase` headings and `- [x] **Phase`
   entries, and from `.planning/phases/*/*-PLAN.md` and `*-SUMMARY.md` on disk.
3. **`gsd-planning-repair --check`** — the CI guard, so a corrupted file cannot
   reach the shared branch unnoticed:

   ```yaml
   - uses: actions/checkout@v4
   - run: |
       git clone --depth 1 https://github.com/arconme/gsd-worktrees.git /tmp/gsd
       /tmp/gsd/bin/gsd-planning-repair --check
   ```

   It exits 1 only on union-merge damage. Drift that merging did not cause — a
   stale counter, a phase missing from the progress table, a table row
   `/gsd-fast` appended past EOF — is reported as an advisory and never fails
   the check.

**What the repair never touches:** STATE.md's `## Session Continuity` section.
Its `Last session:` / `Stopped at:` / `Resume file:` lines are one entry per
past session and legitimately repeat, so every single-value dedupe is scoped to
the block that owns the field (`## Current Position`, the velocity block, the
frontmatter). A global keep-the-last-occurrence pass deletes real history — an
early hand-written attempt at this destroyed seven entries that way, and
`tests/test-planning-reconcile.sh` asserts that section stays byte-identical.

**Fallbacks.** Merge drivers live in git config, which is not versioned, so a
clone that never ran `gsd-init` gets plain union — the repair fixes
that afterwards, and the test suite covers the no-driver path explicitly.
Without `python3`, the driver does the plain union and warns; that is exactly
today's behaviour, never worse.

## Tests

```bash
tests/test-planning-reconcile.sh
```

117 assertions over the two real corruptions from `medyour-platform`
(`tests/fixtures/`), an end-to-end `git merge` through the driver, the same
merge without the driver, a full `gsd-wt-finish` run, the three collateral-
deletion regressions, and `gsd-doctor` — including that it leaves the working
tree, git config and every file byte-identical, and that `gsd-doctor` and
`gsd-bootstrap-repo` agree on what "installed" means (both go through
`gsd_planning_status`).

CI runs the suite on Linux and macOS (`.github/workflows/tests.yml`).

## Current state / roadmap

- This repo is the **single source of truth** — commands, workers, lib, and
  shims all live here; repos carry only `.gsd.conf` + the frozen shims
  ("step two" done 2026-07-18: the old copy-and-perl-rewrite template system
  is gone).
- Planned: shellcheck + bats CI for the lock/claim/finish concurrency paths.
