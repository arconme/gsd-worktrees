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
| `gsd-finish` | Finish from anywhere: merge the phase branch back into the base branch, push (with retry on parallel pushes), remove the worktree + branch, move the ClickUp story to "in testing". |
| `gsd-list` | Read-only table of all phases: number, description, plan progress, lifecycle stage (live from the phase's worktree), worktree state. |
| `gsd-init` | Take a repo with no GSD to "ready for gsd-start": bootstrap + open the right init skill (`/gsd-new-project` or `/gsd-ingest-docs`). |
| `gsd-bootstrap-repo` | Install/sync the per-repo scripts, guard hook, hook registration, CLAUDE.md section, gitignore/gitattributes into a target repo. |
| `gsd-clickup` | Minimal ClickUp write-back helper (status + comment + subtask cascade); token in `~/.config/gsd/clickup.env`. |
| `gsd-sync` | Toolkit maintenance in one command: pull + push this repo, re-link `bin/`, and sync `templates/` from the reference repo (drift-aware; never overwrites uncommitted template edits). `--check` for a dry run. |

**`templates/` — per-repo scripts** (what `gsd-bootstrap-repo` installs into each
repo, adapting base branch / worktree dir / package manager):

- `scripts/gsd-new-worktree-feature.sh` — create a phase worktree (+ config copy, background install)
- `scripts/gsd-finish-worktree-feature.sh` — merge back → push → clean up (locked, conflict-safe)
- `scripts/hooks/gsd-worktree-guard.sh` — blocks GSD commands run in the wrong place
- `scripts/gsd-derive-port.sh` + `gsd-dev-worktree.sh` + `gsd-dev.conf.example` — per-worktree dev ports and a boot-everything launcher

## Install

```sh
git clone git@github.com:arconme/gsd-worktrees.git
cd gsd-worktrees && ./install.sh          # symlinks into ~/.local/bin
```

Symlink mode means `git pull` updates the live commands, and edits to the live
commands land here ready to commit. Use `./install.sh --copy` for detached copies.

**Staying up to date:** run `gsd-sync` — it pulls this repo, pushes your local
commits, re-links any new commands, and syncs `templates/` from the reference
repo (see below). `gsd-sync --check` previews without changing anything.

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

- `bin/` is canonical **here**. `templates/` mirrors the reference installation
  in `arconme/siminds-platform` (`scripts/`); when the repo scripts change
  there, `gsd-sync` copies them into `templates/` and commits (the reference
  repo wins — it refuses to overwrite uncommitted template-side edits).
- **Step two (planned):** replace `gsd-bootstrap-repo`'s perl-rewrite adaptation
  with per-repo config (`git config gsd.base` / `.gsd.conf`), making installed
  scripts byte-identical everywhere and `templates/` the single source of truth.
- Also planned: shellcheck + bats CI for the lock/claim/finish concurrency paths.
