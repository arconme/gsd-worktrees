# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An extension to GSD, written as a bash toolkit (plus two Python modules and one Perl script). It does three things:

1. **Adds worktree support to GSD.** Each phase runs in its own `phase-<N>-<slug>` git worktree, so phases can run in parallel.
2. **Wraps repeated GSD steps in simple commands.** `gsd-start`, `gsd-list`, `gsd-finish`, `gsd-doctor`, and the others replace multi-step manual sequences (for example: claim phase → push → create worktree → open session).
3. **Is agent-agnostic.** Claude Code, Codex, Gemini, and `custom` are adapters. Several providers can work in one project, and hand off one phase between them: `gsd-start -p <N> --provider <name>` reuses the phase's worktree and artifacts. Handoff is **sequential**. Concurrent writers in one worktree are not safe; run parallel providers on different phases. The cross-AI plan review uses a configurable `review_provider` (default `codex`).

This repo is the **single source of truth**: target repos carry only `.gsd.conf`, the frozen shims, and generated instruction blocks. User docs: `README.md`, `docs/providers.md` (capability matrix + full `.gsd.conf` key reference), `docs/architecture.md`, `docs/migration.md`, `docs/gemini-hooks.md`, `docs/copy-install.md`, and `docs/command-order.html` (phase order).

GSD itself (the `/gsd-*` planning skills, including `gsd-review`, and the `gsd-sdk` CLI) is upstream and **not** in this repo. `gsd-start` claims phases with `gsd-sdk query phase.add` / `phase.insert` — no LLM call. Other outside tools: `git`, Python 3.7+, `perl`, `gh` (for `gsd-finish --pr`), `jq` (optional; doctor hook checks), and the ClickUp API (token in `~/.config/gsd/clickup.env`).

## Commands

```sh
./install.sh [--copy] [--agent claude|codex|gemini]... [--all-agents]
# default: symlink bin/* → ~/.local/bin, skills into each agent's skill dir.
# In symlink mode, editing a file here changes the live command at once.

# Tests (what CI runs, on ubuntu + macos) — each suite is standalone
tests/test-planning-reconcile.sh      # merge driver, planning repair, gsd-wt-finish, doctor
tests/test-worktree-guard.sh          # the guard, incl. flow = strict
tests/test-flow-next.sh               # the flow step engine
tests/test-providers.sh               # provider adapters, bootstrap, doctor JSON
bash tests/test-gemini-hook.sh        # Gemini BeforeTool payload adapter
tests/test-install-copy.sh            # install.sh --copy runtime
bash tests/test-review-fixes.sh       # regressions (finish push race, no-jq hooks, …)

# Lint / syntax (CI)
for f in bin/* lib/*.sh install.sh shims/scripts/*.sh shims/scripts/hooks/*.sh tests/*.sh; do bash -n "$f"; done
shellcheck -x bin/* lib/*.sh shims/scripts/*.sh shims/scripts/hooks/*.sh install.sh tests/*.sh
```

There is no per-test runner: each suite uses `ok`/`bad`/`is` helpers and `section` headers, and builds throwaway repos in `mktemp -d`. To focus, run one suite. Every command has `--help`. New suites must also be added to `.github/workflows/tests.yml` and the README test list.

## Architecture

**Core vs adapters.** The core is `bin/`, `lib/common.sh`, the planning reconciler, the worktree rules, and `gsd-flow-next`. It may call `lib/provider.sh`, but adapters must never hold phase state, merge, claim, or safety policy. To add a provider, extend `lib/provider.sh` (identity, instruction file, skill root, argv renderer, review flag, hook metadata), the CLI allowlists/help, docs, and `tests/test-providers.sh` — see `docs/architecture.md`.

- **`bin/`** — user-facing: `gsd-init`, `gsd-start`, `gsd-list`, `gsd-finish`, `gsd-doctor`, `gsd-sync`, `gsd-bootstrap-repo`, `gsd-planning-repair`, `gsd-clickup`. Internal: `gsd-wt-new` / `gsd-wt-finish` (worker halves of start/finish), `gsd-worktree-guard`, `gsd-flow-next`, `gsd-planning-merge` (git merge driver), `gsd-derive-port`. Each script finds its package via `GSD_PKG` (from its own resolved path) and sources `lib/`.
- **`lib/common.sh`** — config (`gsd_conf_get` reads `.gsd.conf`; keys fall back to detection), `gsd_main`, base branch, worktree dir, the checkout lock (`.git/gsd-cmd.lock`, dead-PID reclaim), merge-driver registration, and `gsd_planning_status`/`gsd_planning_apply` — the one definition of "installed" shared by doctor and bootstrap.
- **`lib/provider.sh`** — the provider adapters. No workflow logic. Resolves provider, executable, model and start mode (precedence tables in `docs/providers.md`); renders argv safely (never `eval`); owns the marked-block helpers for generated instruction files.
- **`lib/gsd_hook_payload.py`** — turns native hook JSON (Claude, Gemini) into the guard's NUL-delimited input. It rejects any compound/wrapped shell command that mentions a `gsd-` name instead of guessing.
- **`lib/gsd_planning.py`** — `reconcile` (one file, structural only, run mid-merge by the driver) and `repair` (both files + recompute counters from `.planning/phases/*/*-PLAN.md`/`*-SUMMARY.md`; `--check` for CI).
- **`lib/roadmap-audit.pl`** — read-only ROADMAP audit for `gsd-doctor`. It catches two upstream `gsd-sdk` bugs (`phase.insert` writes no checklist row; `phase.complete` can tick another phase's row).
- **`shims/`** — frozen 7-line delegators that bootstrap copies into target repos as `scripts/gsd-*.sh`. Keep them unchanged.
- **`skills/`** — `gsd-worktrees` and `gsd-flow`, installed per agent. They must stay provider-neutral: no literal `Skill()` calls. The flow skill only interprets `gsd-flow-next` output; it is not a second state machine.

**Enforcement.** The mandatory guard is provider-neutral: `gsd-worktree-guard --command … --phase … --repo …`. `gsd-start` calls it before it prints or launches a session, and `gsd-flow-next` calls it before it returns a step. Native hooks are extra defense only: Claude `PreToolUse(Skill)` and Gemini `BeforeTool`. Codex has none. Exit 2 = block. The only escape hatch is `GSD_SKIP_GUARD=1`.

**Generated instructions (in target repos).** `.gsd/INSTRUCTIONS.md` is canonical, between `canonical:start`/`end` markers. `CLAUDE.md` / `AGENTS.md` (Codex + custom share it) / `GEMINI.md` get only a marked `gsd-worktrees:provider:start`/`end` entrypoint. Bootstrap validates markers before writing and never touches text outside them.

**Finish path.** `gsd-finish` → `gsd-wt-finish`: sync origin (abort on failure) → validate the phase (`scripts/gsd-premerge-check.sh`, else the project's tests) → merge → `gsd-planning-repair` → validate the combined tree → push with retry (repair and validate again after each retry's pull) → remove worktree + branch → move the ClickUp story. A failed validation keeps local commits and the worktree, and never pushes.

## Invariants to keep

- One phase = one `phase-<N>-<slug>` worktree. The main checkout stays on the base branch.
- Claims serialize through the base branch (pull, push, rebase-and-retry; the loser renumbers).
- A failed merge or validation must leave the remote base branch untouched.
- The phase-flow artifact list (`<P>-CONTEXT.md`, `<P>-REVIEWS.md`, `<P>-REVIEW.md`, `<P>-UI-REVIEW.md`, …) is shared by `gsd-flow-next`, the guard's `flow = strict` rule, and gsd-doctor's T040 report. Change them together.
- Planning reconcile: keyed lines keep the **first** occurrence's position and the **best** occurrence's content (`[x]` beats `[ ]`, longer wins among equals). Single-value lines keep the last copy (the incoming branch). STATE.md's `## Session Continuity` must stay byte-identical — a test asserts it.
- `gsd-doctor` is read-only by design (no `--fix`). Finding codes: `W0xx` are shared with `/gsd-health`, `T0xx` are toolkit-only (e.g. `T050` bad providers list, `T059` bad model).
- Legacy configs keep working: a singular `provider` key, `agent_command`, `--agent`, and `GSD_AGENT` are read-only compatibility inputs. With no provider configured, the default is Claude.
- Scripts must work on both BSD (macOS) and GNU userlands. Shellcheck exceptions go in `.shellcheckrc` with a reason.
