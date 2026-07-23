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
- **`ROADMAP.md`/`STATE.md` use `merge=union`** so parallel finishes never stop
  on trivial shared-state conflicts.

## Current state / roadmap

- This repo is the **single source of truth** — commands, workers, lib, and
  shims all live here; repos carry only `.gsd.conf` + the frozen shims
  ("step two" done 2026-07-18: the old copy-and-perl-rewrite template system
  is gone).
- Planned: shellcheck + bats CI for the lock/claim/finish concurrency paths.
