---
name: gsd-worktrees
description: "The gsd-* shell commands that run GSD phases in parallel git worktrees — gsd-start, gsd-finish, gsd-list, gsd-doctor, gsd-init, gsd-bootstrap-repo, gsd-sync, gsd-planning-repair. Use when asked to start/begin/pick up a feature or phase, to finish/land/ship a phase, to see what phases exist or what is in flight, to set GSD up in a repo, or to diagnose a broken .planning/ or worktree. These are shell commands run via Bash, distinct from the /gsd-* planning skills."
---

# gsd-worktrees — the shell commands around GSD

GSD's `/gsd-*` skills do the planning. This toolkit does everything around
them: one-command feature start/finish, a git worktree per phase, parallel-safe
phase claims, and the guard hook. Commands live in `~/.local/bin`; toolkit repo
is `arconme/gsd-worktrees`.

Only relevant in a **GSD-fitted repo** — one with `.gsd.conf` and `.planning/`.
Check with `ls .gsd.conf .planning` before assuming. If it isn't fitted, the
answer is `gsd-init`, not a manual setup.

## The rule that matters most

**Never claim a phase without checking first.** Run `gsd-list`, read it, and
decide:

| The work is… | Command |
|---|---|
| already a phase in the roadmap | `gsd-start -p <N>` (attach) |
| genuinely new | `gsd-start -n "<description>"` |
| a hotfix under an existing phase | `gsd-start --insert <N> "<description>"` |

`gsd-start "<description>"` with no flag is **refused** — deliberately. A bare
description used to claim, which made it far too easy to restate existing work
in fresh words and get a second phase for it. State the intent explicitly.

With `--cu <id>`, a phase already carrying that ClickUp id is also refused
however differently it was worded — that phase *is* this work.

## The loop per feature

1. `gsd-start -n "<desc>"` — claims a uniquely-numbered phase in `ROADMAP.md`
   (deterministic, auto-renumbers on a race with a parallel session), pushes
   the claim, creates `../<repo>-worktrees/phase-<N>-<slug>` off the base
   branch, and **prints** a `cd … && claude "/gsd-discuss-phase <N>"` one-liner.
2. **Relay that one-liner to the user** to run in a fresh terminal. Do not open
   a nested session, and do not do the phase work in the current session.
3. In that session: `/gsd-discuss-phase <N>` → `/gsd-plan-phase <N>` →
   `/gsd-execute-phase <N>`.
4. `gsd-finish` — from inside the phase worktree, as the session's **last**
   action (it deletes the directory the session is standing in). Merges into
   the base branch, pushes, removes worktree + branch.

## Commands

| Command | Use |
|---|---|
| `gsd-list [--compact]` | Read-only table of every phase: number, description, plan progress, lifecycle stage, worktree state. **Run this before starting anything.** |
| `gsd-start` | `-n "<desc>"` new · `-p <N>` attach · `--insert <N> "<desc>"` decimal hotfix · `--cu <id>` ClickUp story · `--slug` · `--repo <path>` · `--agent <cmd>` · `--launch` / `--no-launch` (print-only is the default) · `--no-push` |
| `gsd-finish [<N>]` | Land the phase. No argument = infer from the current worktree branch. |
| `gsd-doctor` | Read-only health check: toolkit install, shims, `.planning` merge safety, planning-file coherence, worktree hygiene. Diagnoses only — each finding names the command that fixes it. No `--fix`, by design. |
| `gsd-init` | Repo with no GSD → ready for `gsd-start`. Bootstrap + opens the right init skill. |
| `gsd-bootstrap-repo` | Just the file installation `gsd-init` wraps. Idempotent. |
| `gsd-planning-repair` | Reconcile `ROADMAP.md` + `STATE.md` after a union merge, recompute counters. `--check` = CI guard, `--commit` = land the repair. Runs automatically from `gsd-finish` and the `post-merge` hook. |
| `gsd-sync` | Toolkit maintenance: pull + push the toolkit repo, re-link `bin/`. `--check` dry-runs it. |

Every command self-documents: `gsd-start --help`, `gsd-finish --help`, ….
Prefer them over chaining the manual steps — they carry parallel-session race
handling the manual path lacks.

## Rules that bite if ignored

- **One feature = one phase = one worktree = one session.** Never two sessions
  on the same folder or branch. Never feature work in the main checkout.
- **Touch only your own phase** in `ROADMAP.md` / `STATE.md`. Never renumber or
  edit someone else's. Merges auto-resolve via the `merge=gsd-planning` driver.
- **A guard hook blocks misplaced commands** (`/gsd-phase` off the base branch,
  per-phase commands outside their `phase-<N>-*` worktree, execute-phase before
  the install finishes). If a command is blocked, you are in the wrong
  directory — move, don't force. `GSD_SKIP_GUARD=1` bypasses it; use only when
  the user asks.
- Repo settings live in `.gsd.conf`. `scripts/gsd-*.sh` are frozen shims that
  delegate to the toolkit — never edit them.

## When something looks wrong

Run `gsd-doctor` first and report what it says. `.planning/` looking
contradictory after a merge is the known failure mode — `gsd-planning-repair
--check` confirms it, `--commit` fixes it.
