---
name: gsd-worktrees
description: "The gsd-* shell commands that run GSD phases in parallel git worktrees — gsd-start, gsd-finish, gsd-list, gsd-doctor, gsd-init, gsd-bootstrap-repo, gsd-sync, gsd-planning-repair. Use when asked to start/begin/pick up a feature or phase, to finish/land/ship a phase, to see what phases exist or what is in flight, to set GSD up in a repo, or to diagnose a broken .planning/ or worktree. These are shell commands run via Bash, distinct from the /gsd-* planning skills."
---

# gsd-worktrees — the shell commands around GSD

GSD's provider-native planning skills do the planning. This toolkit does everything around
them: one-command feature start/finish, a git worktree per phase, parallel-safe
phase claims, and provider-neutral command guards. Commands live in `~/.local/bin`; toolkit repo
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
   branch, and prints a safely quoted command for the configured provider.
2. **Relay that one-liner to the user** to run in a fresh terminal. Do not open
   a nested session, and do not do the phase work in the current session.
3. Select `--flow` on the start command above, or use the installed `gsd-flow` skill in the new session. It
   resumes the step reported by `gsd-flow-next <N>`. Without `--flow`,
   `gsd-start` begins at discussion; invoke the later steps through the
   provider's actual skill mechanism. The engine is authoritative for order.
4. After the engine reports `done`, tell the user the phase is ready to land.
   Run `gsd-finish` only on explicit user request, from the phase worktree,
   as the session's **last** action: it removes that directory after merging.

## Commands

| Command | Use |
|---|---|
| `gsd-list [--compact]` | Read-only table of every phase: number, description, plan progress, lifecycle stage, worktree state. **Run this before starting anything.** |
| `gsd-start` | `-n "<desc>"` new · `-p <N>` attach · `--insert <N> "<desc>"` decimal hotfix · `--cu <id>` ClickUp story · `--slug` · `--repo <path>` · `--provider <name>` · `--agent-command <path>` · `--model <id>` · `--flow` / `--no-flow` · `--launch` / `--no-launch` (print-only is the default) · `--no-push` |
| `gsd-finish [<N>]` | Land the phase. No argument = infer from the current worktree branch. Runs the repo's pre-merge check or its test suite first. `--pr` opens a GitHub PR instead of merging (worktree stays; re-run after it lands). |
| `gsd-doctor` | Read-only health check: toolkit install, shims, `.planning` merge safety, planning-file coherence, worktree hygiene. Diagnoses only — each finding names the command that fixes it, with a code; `--json` for scripts. No `--fix`, by design. |
| `gsd-init` | Repo with no GSD → ready for `gsd-start`. Use `--providers claude,codex,gemini` for a provider set and `--provider codex` to choose the initialization session. |
| `gsd-bootstrap-repo` | Just the file installation `gsd-init` wraps. Idempotent. |
| `gsd-planning-repair` | Reconcile `ROADMAP.md` + `STATE.md` after a union merge, recompute counters. `--check` = CI guard, `--commit` = land the repair. Runs automatically from `gsd-finish` and the `post-merge` hook. |
| `gsd-sync` | Toolkit maintenance: pull + push the toolkit repo, refresh installed commands using the recorded provider set. `--check` is read-only and uses last-fetched refs. |

Every command self-documents: `gsd-start --help`, `gsd-finish --help`, ….
Prefer them over chaining the manual steps — they carry parallel-session race
handling the manual path lacks.

## Rules that bite if ignored

- **One feature = one phase = one worktree.** Configured providers may hand the
  same phase between sessions. Never run simultaneous mutating sessions in the
  same folder or branch. Never feature work in the main checkout.
- **Touch only your own phase** in `ROADMAP.md` / `STATE.md`. Never renumber or
  edit someone else's. Merges auto-resolve via the `merge=gsd-planning` driver.
- **The command-level guard blocks misplaced or premature commands** (phase
  setup off the base branch, per-phase commands outside their
  `phase-<N>-*` worktree, execution before install completion). Follow the
  reported prerequisite; location is only one possible cause. The guard runs
  through supported GSD shell routes; arbitrary direct shell commands can
  bypass those routes. `GSD_SKIP_GUARD=1` bypasses it; use only when the user
  asks. Claude/Gemini native hooks provide optional early feedback.
- **With `flow = strict` in `.gsd.conf` the guard also enforces the phase
  order.** `/gsd-plan-phase` needs the discuss artifact (`<P>-CONTEXT.md`),
  `/gsd-execute-phase` needs the cross-AI review (`<P>-REVIEWS.md`; `--gaps-only`
  exempt), `/gsd-secure-phase` needs the code review (`<P>-REVIEW.md`) and, for a
  phase with a UI-SPEC, `<P>-UI-REVIEW.md`. A block names the step to run first.
  Do the step; never work around it.
- Repo settings live in `.gsd.conf`. `scripts/gsd-*.sh` are frozen shims that
  delegate to the toolkit — never edit them.

## When something looks wrong

Run `gsd-doctor` first and report what it says. In a `flow = strict` repo it
also lists every merged phase that skipped a mandatory step (T040) — that is
the backlog, not something to fix from the main checkout. `.planning/` looking
contradictory after a merge is the known failure mode — `gsd-planning-repair
--check` confirms it, `--commit` fixes it.
