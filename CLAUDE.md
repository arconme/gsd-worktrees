# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An extension to GSD, written as a bash toolkit (plus one Python module and one Perl script). It does three things:

1. **Adds worktree support to GSD.** Each phase runs in its own `phase-<N>-<slug>` git worktree, so phases can run in parallel.
2. **Wraps repeated GSD steps in simple commands.** `gsd-start`, `gsd-list`, `gsd-finish`, `gsd-doctor`, and the others replace multi-step manual sequences (for example: claim phase → push → create worktree → open session).
3. **Lets several AI providers work in one project, and even in one phase.** The commands are agent-agnostic. `gsd-start`/`gsd-init --agent <cmd>` open any CLI (claude, gemini, …). `gsd-start -p <N> --agent <cmd>` attaches another agent to an existing phase and its worktree. The phase flow calls other providers for some steps, like the cross-AI plan review (`/gsd-review --codex`, which needs `OPENAI_API_KEY` from `~/.config/ai-keys/keys.env`). Limits: the guard is registered only in `.claude/settings.json`, so only Claude Code sessions are guarded. The `.git/gsd-cmd.lock` serializes gsd commands, not agent sessions editing the same worktree.

It is the **single source of truth**: target repos carry only `.gsd.conf` and the frozen shims. `README.md` is the user-facing reference; `docs/command-order.html` shows the full phase order.

GSD itself (the `/gsd-*` planning skills and the `gsd-sdk` CLI) is upstream and **not** in this repo. This toolkit calls it: `gsd-start` claims phases with `gsd-sdk query phase.add` / `phase.insert` — no LLM call. Other outside tools: `git`, `python3`, `perl`, `gh` (for `gsd-finish --pr`), and the ClickUp API (token in `~/.config/gsd/clickup.env`).

Each bin script finds its own package via `GSD_PKG` (resolved from its symlinked path), then sources `lib/common.sh`. So editing a file here changes the live command at once — `install.sh` links, it does not copy.

## Commands

```sh
./install.sh                          # symlink bin/* → ~/.local/bin, skills/* → ~/.claude/skills (--copy for copies)

# Tests (what CI runs, on ubuntu + macos)
tests/test-planning-reconcile.sh      # merge driver, planning repair, gsd-wt-finish, gsd-doctor
tests/test-worktree-guard.sh          # the guard hook, incl. flow = strict
tests/test-flow-next.sh               # the /gsd-flow step engine

# Lint / syntax (CI)
for f in bin/* lib/common.sh shims/scripts/*.sh tests/*.sh; do bash -n "$f"; done
shellcheck -x bin/* lib/common.sh shims/scripts/*.sh shims/scripts/hooks/*.sh install.sh tests/*.sh
```

There is no per-test runner: each suite is a self-contained bash script with `ok`/`bad`/`is` helpers and `section` headers, building throwaway repos in `mktemp -d`. To focus, run one suite. Every command has `--help`.

## Architecture

- **`bin/`** — the commands. User-facing: `gsd-init`, `gsd-start`, `gsd-list`, `gsd-finish`, `gsd-doctor`, `gsd-sync`, `gsd-bootstrap-repo`, `gsd-planning-repair`, `gsd-clickup`. Internal: `gsd-wt-new` / `gsd-wt-finish` (worker halves of start/finish), `gsd-worktree-guard` (Claude Code hook), `gsd-flow-next` (step engine for `/gsd-flow`), `gsd-planning-merge` (git merge driver), `gsd-derive-port`.
- **`lib/common.sh`** — sourced by the bin scripts. Config (`gsd_conf_get` reads `.gsd.conf`, keys fall back to detection), main-checkout lookup (`gsd_main`), base branch, worktree dir, the checkout lock (`.git/gsd-cmd.lock`, dead-PID reclaim), merge-driver registration, and `gsd_planning_status`/`gsd_planning_apply` — the one definition of "installed" shared by `gsd-doctor` and `gsd-bootstrap-repo`.
- **`lib/gsd_planning.py`** — `reconcile` (one file, structural only, used mid-merge by the driver) and `repair` (both files + recompute counters from `.planning/phases/*/*-PLAN.md`/`*-SUMMARY.md` on disk; `--check` for CI). If python is missing, the driver falls back to plain union.
- **`lib/roadmap-audit.pl`** — read-only ROADMAP audit used by `gsd-doctor`. It catches two upstream `gsd-sdk` bugs: `phase.insert` writes no checklist row, and `phase.complete` can tick the wrong phase's row.
- **`gsd-worktree-guard`** — runs as a Claude Code hook on `UserPromptExpansion` (typed `/gsd-…`) and `PreToolUse` (Skill calls). It blocks with exit 2. Escape hatch: `GSD_SKIP_GUARD=1`.
- **Finish path** — `gsd-finish` → `gsd-wt-finish`: sync origin → run `scripts/gsd-premerge-check.sh` (or the project's tests) → merge → `gsd-planning-repair` → push with retry (repair again after the retry's pull) → remove worktree + branch → move the ClickUp story.
- **`shims/`** — frozen 7-line delegators that `gsd-bootstrap-repo` copies into target repos as `scripts/gsd-*.sh`. They are meant never to change. The port shim and guard shim fail soft/open when the toolkit is missing.
- **`skills/`** — agent-facing skills (`gsd-worktrees`, `gsd-flow`), symlinked into `~/.claude/skills`. When you change command behaviour, check whether these SKILL.md files and the README tables need the same change.

### Invariants to keep

- One phase = one `phase-<N>-<slug>` worktree = one session. The main checkout stays on the base branch.
- Claims serialize through the base branch (pull, push, rebase-and-retry; the loser renumbers).
- A failed merge must abort cleanly and leave the base branch untouched.
- The phase-flow artifact list (`<P>-CONTEXT.md`, `<P>-REVIEWS.md`, `<P>-REVIEW.md`, `<P>-UI-REVIEW.md`, …) is shared by `gsd-flow-next`, the guard's `flow = strict` rule, and gsd-doctor's T040 report. Change them together.
- Planning reconcile: keyed lines keep the **first** occurrence's position and the **best** occurrence's content (`[x]` beats `[ ]`, longer wins among equals). Single-value lines keep the last copy (the incoming branch). STATE.md's `## Session Continuity` must stay byte-identical — a test asserts it.
- `gsd-doctor` is read-only by design (no `--fix`). Its finding codes: `W0xx` are shared with `/gsd-health`, `T0xx` are toolkit-only.
- Scripts must work on both BSD (macOS) and GNU userlands. Shellcheck exceptions go in `.shellcheckrc` with a reason.
