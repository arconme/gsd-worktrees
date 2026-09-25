# Feature list

Everything the toolkit does, by area. Each line names where it lives.
Flags and config keys are complete as of 2026-09-25; `<cmd> --help` is authoritative.

## 1. Repo setup

| Feature | Where |
|---|---|
| One-command setup of a repo from zero: bootstrap, then open `/gsd-new-project` or `/gsd-ingest-docs` | `gsd-init` |
| Auto-picks new-project vs ingest by scanning for ADR/PRD/RFC/spec/architecture docs (`--new` / `--ingest` force it) | `gsd-init` |
| Idempotent re-run: with an existing `.planning/ROADMAP.md` it only repairs workflow files, never planning state | `gsd-init` |
| Writes `.gsd.conf` (base, wtdir, install, providers, per-provider commands); migrates legacy `provider` / `agent_command` keys | `gsd-bootstrap-repo` |
| Installs the frozen shims into `scripts/` and `scripts/hooks/`, self-checked with `bash -n` | `gsd-bootstrap-repo` |
| Generated instructions: canonical `.gsd/INSTRUCTIONS.md` + marked entrypoints in `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`; text outside markers preserved; markers validated before any write | `gsd-bootstrap-repo`, `lib/provider.sh` |
| Registers native guard hooks (Claude `.claude/settings.json`, Gemini `.gemini/settings.json`) via a `jq` merge; skips cleanly without `jq` | `gsd-bootstrap-repo` |
| `.planning` merge safety: `.gitattributes` `merge=gsd-planning`, driver registration in git config, `post-merge` hook (husky-aware) | `lib/common.sh` (`gsd_planning_status` / `gsd_planning_apply`) |
| `--commit` stages only installed files; skipped if the repo was already dirty | `gsd-bootstrap-repo` |

## 2. Starting work

| Feature | Where |
|---|---|
| Claim a new phase in one step: claim → push → worktree → session (`-n "desc"`; a bare description is refused) | `gsd-start` |
| Attach to an existing phase, reusing its worktree (`-p N`, idempotent) | `gsd-start` |
| Claim a decimal hotfix phase (`--insert N`) | `gsd-start` |
| Deterministic claim via `gsd-sdk query phase.add` / `phase.insert` (no LLM call) | `gsd-start` |
| Parallel-safe claim: pull, push with rebase-and-retry, auto-renumber the loser | `gsd-start` |
| Duplicate-description guard (case-insensitive) | `gsd-start` |
| Claim bookkeeping: checklist + Progress rows and STATE.md counters land in the claim commit | `gsd-start`, `lib/roadmap-rows.pl` |
| Ticket link (`--ticket <id|url>`, old `--cu`): `tk-<id>` at the end of title/slug, duplicate-ticket guard, ticket → "in progress" when a tracker is set | `gsd-start`, `gsd-tracker` |
| Print-only by default; `--launch` / `--agent-command` / `--provider` open the session | `gsd-start` |
| `--flow` / `--no-flow` / `start_mode`: open discuss-phase only, or resume the full flow | `gsd-start`, `lib/provider.sh` |
| Guard check before a session is printed or launched | `gsd-start` |
| Worktree creation off the base branch, `phase-<N>-<slug>`; reuse if it exists | `gsd-wt-new` |
| Copies gitignored local config into the worktree (`.env.local`, `.mcp.json`, `.claude/settings.local.json`) | `gsd-wt-new` |
| Dependency install in background / foreground / none, with `.gsd-install.status` + `.gsd-install.log` | `gsd-wt-new`, `lib/common.sh` (`gsd_install_cmd`) |
| Per-worktree dev port: base + phase number | `gsd-derive-port` |

## 3. Finishing work

| Feature | Where |
|---|---|
| Finish from anywhere: no argument inside the worktree, `<N>` / `phase-N-slug` elsewhere, `--repo` outside | `gsd-finish` |
| Auto-returns a clean main checkout to the base branch; safe to run inside the worktree being removed | `gsd-finish` |
| Sync base with origin first; abort (worktree kept) if that fails | `gsd-wt-finish` |
| Validation before merge and on the combined tree after: `scripts/gsd-premerge-check.sh` (or `premerge =`), else the project's tests (`test =` or detection: xcodebuild / make / just / cargo / go / npm / pytest) | `gsd-wt-finish`, `lib/common.sh` (`gsd_test_cmd`) |
| `--no-ff` merge; a conflict aborts and leaves the base branch clean with resolution steps | `gsd-wt-finish` |
| Planning repair after every merge point; never pushes contradictory `.planning` | `gsd-wt-finish` |
| Push with up to 3 retries (pull + repair + re-validate between) | `gsd-wt-finish` |
| Removes worktree + branch; ticket → "in testing" when a tracker is set (also on `--pr`) | `gsd-wt-finish`, `gsd-finish`, `gsd-tracker` |
| `--pr [--draft]`: push (prefers the `*-pr` branch) and open a GitHub PR instead of merging | `gsd-finish` |
| Post-finish warning if the roadmap ticks look wrong | `gsd-finish` |

## 4. Planning-file integrity

| Feature | Where |
|---|---|
| Git merge driver: union, then reconcile single-value lines | `gsd-planning-merge`, `lib/gsd_planning.py reconcile` |
| Keyed lines keep first position + best content (`[x]` beats `[ ]`, real status beats "Not started", longer wins) | `lib/gsd_planning.py` |
| Section-scoped dedupe; STATE.md `## Session Continuity` never touched | `lib/gsd_planning.py` |
| Counter recompute from ground truth (ROADMAP headings/checklist, `*-PLAN.md`, `*-SUMMARY.md`) | `gsd-planning-repair`, `lib/gsd_planning.py repair` |
| `--check` CI guard (fails on merge damage; drift is advisory) / `--commit` | `gsd-planning-repair` |
| Falls back to plain union with a warning when Python 3.7+ is missing | `gsd-planning-merge`, `lib/common.sh` (`gsd_python`) |
| Audit for two upstream `gsd-sdk` bugs: missing checklist row, tick landing on the wrong phase | `lib/roadmap-audit.pl` |

## 5. Enforcement (the guard)

| Feature | Where |
|---|---|
| Provider-neutral guard API: `--command --args --phase --repo` | `gsd-worktree-guard` |
| Rule 1: `/gsd-phase` only on the base branch | `gsd-worktree-guard` |
| Rule 2: per-phase commands only inside the matching `phase-<N>-*` worktree (nested agent worktrees inherit identity) | `gsd-worktree-guard` |
| Rule 3: `/gsd-execute-phase` blocked while the install is `running` / `fail` | `gsd-worktree-guard` |
| Rule 4 (`flow = strict`): plan needs CONTEXT, execute needs REVIEWS, secure needs REVIEW (+ UI-REVIEW when a UI-SPEC exists); `--prd` / `--gaps-only` exemptions | `gsd-worktree-guard` |
| Native hooks: Claude `UserPromptExpansion` + `PreToolUse(Skill)`, Gemini `BeforeTool` (skill activation + direct `gsd-*` shell calls) | `gsd-worktree-guard`, `lib/gsd_hook_payload.py` |
| Hook JSON parsed without `jq` (Python fallback); compound shell text naming `gsd-` is blocked, not guessed | `lib/gsd_hook_payload.py` |
| Escape hatch `GSD_SKIP_GUARD=1`; shim fails open when the toolkit is not installed | `gsd-worktree-guard`, `shims/` |

## 6. Phase flow

| Feature | Where |
|---|---|
| Resumable step engine: ticket (only with a tracker) → discuss → ui-decision → ui-phase → plan → review → replan → execute → verifier → gaps → verify-work → code-review → ui-review → secure → done | `gsd-flow-next` |
| Reads artifacts only, so it survives crashes and `/clear` | `gsd-flow-next` |
| Detects an unfolded review (`replan`) from commit times of REVIEWS vs PLAN | `gsd-flow-next` |
| `--all` preview, `--json`, `--ui` / `--no-ui` | `gsd-flow-next` |
| Guard check before every step it returns | `gsd-flow-next` |
| Configurable cross-AI reviewer (`review_provider`, default `codex`) | `gsd-flow-next`, `lib/provider.sh` |
| Agent-facing driver skill with three human stop points | `skills/gsd-flow` |
| Doctor report of merged phases that skipped a mandatory step (T040, `flow_since`) | `gsd-doctor` |

## 7. AI providers

| Feature | Where |
|---|---|
| Providers: `claude`, `codex`, `gemini`, `custom`; ordered `providers =` list, first is default | `lib/provider.sh` |
| Precedence chains for provider, executable, model, start mode (CLI > env > repo > legacy > default) | `lib/provider.sh` |
| Safe argv rendering (arrays, no `eval`); Gemini `--prompt-interactive`, others positional | `lib/provider.sh` |
| Per-session model (`--model`, `GSD_MODEL`, `GSD_<P>_MODEL`, `<p>_model`, `default`) | `lib/provider.sh` |
| Sequential cross-provider handoff on one phase (`gsd-start -p N --provider X`) | `gsd-start` |
| Skills installed per agent (`install.sh --agent …` / `--all-agents`) | `install.sh`, `lib/provider.sh` |

## 8. Visibility and diagnostics

| Feature | Where |
|---|---|
| Phase table: number, title, plans done/total, stage, worktree; wraps to the terminal (`--compact` for one line) | `gsd-list` |
| Read-only health check, every finding names its fix command; `--quiet`, `--json` | `gsd-doctor` |
| Finding codes: T001–T007 toolkit (incl. T005 no gsd-sdk, T006 no perl, T007 stale skills), T010–T019 repo setup (T015 base branch, T017 unknown `.gsd.conf` key, T018 bad value, T019 pre-merge gate), T020–T025 planning (T025 duplicate phase heading), T030–T032 hygiene (T032 failed worktree install), T040 flow debt, T050–T060 providers, T070–T073 tracker (T073 no ClickUp token), W017 / W027 shared with `/gsd-health` | `gsd-doctor` |
| Checks for a newer GSD on npm and branches whose upstream is gone | `gsd-doctor` |

## 9. Install and maintenance

| Feature | Where |
|---|---|
| Symlink install (edits here are live) or `--copy` standalone runtime (`GSD_COPY_DIR`) | `install.sh` |
| Backups before overwrite; prunes links to deleted commands; refuses overlapping destinations | `install.sh` |
| Install manifest + `--reuse-install-config` | `install.sh` |
| One-command upkeep: pull/push this repo, re-link, check the calling repo's shims; `--check` dry run | `gsd-sync` |
| One-line install of a GitHub release, SHA256-checked, one folder per release (`--version`, `--agent`) | `get.sh` |
| Update / go back: `gsd-update [--check \| --version X.Y.Z]`; keeps the previous release, prunes older ones | `gsd-update` |
| "Newer version" notice for gsd-worktrees and GSD (npm) in `gsd-start` / `gsd-list` / `gsd-init` (terminal only) and `gsd-doctor` (also `--quiet`, `updates` in `--json`); day-long cache, background refresh; `GSD_NO_UPDATE_CHECK=1` | `lib/version.sh`, `gsd-doctor` |
| Reinstall replaces the toolkit's own links and skills in place (no `.bak` on PATH or in skill dirs) | `install.sh` |
| Tag-driven releases: tests → tarball + `SHA256SUMS` → GitHub release; `tools/release.sh X.Y.Z --push` | `.github/workflows/release.yml`, `tools/release.sh` |

## 10. Tickets and trackers ([trackers.md](trackers.md))

| Feature | Where |
|---|---|
| `start` / `finish` / `comment` / `status` / `snapshot [--out]` / `extract` / `check` / `which` | `gsd-tracker` |
| `tracker = none` (default) / `clickup` / `custom`; `GSD_TRACKER` override | `gsd-tracker`, `lib/tracker.sh` |
| Id parsing: bare, `tk-<id>`, `#<id>`, URL; tags read back from title, then branch | `lib/tracker.sh` |
| Status names from `tracker_status_start` / `_finish` (env `GSD_TRACKER_STATUS_*` wins) | `gsd-tracker` |
| ClickUp: status matched per list, subtask cascade, idempotent, markdown snapshot; token from `CLICKUP_API_TOKEN` or `~/.config/gsd/clickup.env` | `lib/trackers/clickup.sh` |
| Custom: `tracker_command` gets `start` / `finish` / `comment` / `status` / `snapshot` / `check` + `<id> [text]` | `lib/trackers/custom.sh` |
| Snapshot `--out` writes only on success (the file marks the flow step done) | `gsd-tracker` |
| Legacy read-only: `--cu`, `cu_<id>` tags, `STORY.md`, `gsd-clickup` alias | `lib/tracker.sh`, `gsd-clickup` |

## 11. Shared library (`lib/`)

| Module | Provides |
|---|---|
| `lib/common.sh` | `.gsd.conf` reader, main-checkout / base / wtdir detection, checkout lock (`mkdir`, dead-PID reclaim, re-entrant), merge-driver registration, planning-safety status/apply, Python 3.7+ discovery, install/test command detection |
| `lib/provider.sh` | provider identity/validation, instruction file + skill root per provider, native-hook capability + state, resolution chains, argv rendering, owned-marker block helpers |
| `lib/gsd_planning.py` | `reconcile` and `repair` engines for ROADMAP.md / STATE.md |
| `lib/gsd_hook_payload.py` | Claude/Gemini hook JSON → guard input |
| `lib/roadmap-audit.pl` | read-only ROADMAP bookkeeping audit |
| `lib/roadmap-rows.pl` | adds a claimed phase's missing checklist + Progress rows (the ones `gsd-sdk` leaves out) |
| `lib/version.sh` | this package's version, version compare, the cached latest-release check and notice |
| `lib/tracker.sh` | tracker choice, ticket id parsing, tag extraction and matching |
| `lib/trackers/*.sh` | one adapter per tracker (`clickup`, `custom`), sourced by `gsd-tracker` |
