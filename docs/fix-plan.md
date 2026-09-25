# Fix plan — full-code review, 2026-09-25

Source: a fresh full-code review of `main` at `b88ea04` (four area reviews:
start/setup, finish/planning, guard/flow/providers, doctor/install/docs).
Every finding below was re-checked against the code before it was listed.
The previous tracker (agent-agnostic refactor, F01–F14) is archived in
[`archive/2026-09-agent-agnostic-fix-plan.md`](archive/2026-09-agent-agnostic-fix-plan.md).

Status: `todo` · `in progress` · `done` (fixed + regression test) · `won't fix` (reason given) · `backlog`

## Wave 1 — can let unvalidated code through (high)

| ID | Finding | Where | Fix | Status |
|---|---|---|---|---|
| R01 | `install =` / `test =` values run word-split, not parsed: `npm ci && npm run build` runs `npm` with `&& npm run build` as arguments → wrong command, possible false `ok` / false test pass | `bin/gsd-wt-new:144,149`, `bin/gsd-wt-finish:168` | run through `bash -c "$CMD"` | done |
| R02 | A pre-merge script that exists but lost its executable bit is skipped silently; with `test = none` finish merges with no validation | `bin/gsd-wt-finish:157` | refuse the finish and say `chmod +x` | done |
| R03 | Guard pads the phase with `printf '%02d' "$N"`; `08`/`09` are invalid octal → `00` → false strict-flow block | `bin/gsd-worktree-guard:183` | `printf '%02d' "$((10#$N))"`, as `gsd-flow-next` does | done — also fixed: `/gsd-plan-phase 08` in the `phase-8-*` worktree was blocked as "wrong phase" |

## Wave 2 — wrong result, visible (medium)

| ID | Finding | Where | Fix | Status |
|---|---|---|---|---|
| R04 | Deprecated `GSD_AGENT` (unknown name) overwrites an explicit `--agent-command` | `lib/provider.sh:164` | feed the legacy value into the executable chain below `--agent-command` / `GSD_AGENT_COMMAND` | done |
| R05 | `gsd-wt-new` takes no lock; two concurrent runs for one phase → raw `cannot lock ref` instead of reuse | `bin/gsd-wt-new` | `gsd_acquire_lock` (re-entrant under `gsd-start`) | done — `gsd-start` passes `GSD_LOCK_HELD=1` so it does not wait on itself |
| R06 | `gsd-planning-repair --check` exits 2 when `.planning/ROADMAP.md` is missing; docs promise failure only on merge damage | `bin/gsd-planning-repair`, `lib/gsd_planning.py:658` | no roadmap → nothing to check, exit 0 with a note | done |
| R07 | `gsd-doctor --json` looks identical for a healthy GSD repo and a non-GSD repo; `--help` omits most JSON keys | `bin/gsd-doctor:21,464` | add `"gsd_repo"`; document the real keys | done |
| R08 | `gsd-list` (≈300 lines, Perl table + stage derivation) has no test | `tests/` | new `tests/test-list.sh`, wired into CI | done (18 checks) |

## Wave 3 — low / hygiene

| ID | Finding | Where | Fix | Status |
|---|---|---|---|---|
| R09 | npm test detection greps the whole `package.json` for `"test"` (a dependency named `test` matches) | `lib/common.sh:234` | match a `"test"` key inside `"scripts"` only | done |
| R10 | A leftover `.husky/` dir counts as "post-merge hook installed" even when git does not use husky's hooks | `lib/common.sh:82` | doctor note when `core.hooksPath` does not point into `.husky/` | done (verified by hand; doctor notes are not in `--json`) |
| R11 | `gsd-finish --pr` push has no retry | `bin/gsd-finish:187` | clearer failure message only — see status | won't fix the retry — a rejected PR push needs the user to integrate origin's commits; the error now says how |
| R12 | `gsd-start -p N "text"` silently drops the text | `bin/gsd-start` | warn that the description is ignored when attaching | done |
| R13 | Gemini shell hook allows a renamed/aliased gsd command (`pp 5`) | `lib/gsd_hook_payload.py` | document; the mandatory command guard still applies | done (`docs/gemini-hooks.md`) |
| R14 | `lib/__pycache__/*.pyc` committed, no `.gitignore`; old finished tracker in `docs/` | repo | remove `.pyc`, add `.gitignore`; tracker archived | done |

## Backlog — not part of this pass

| ID | Item | Why not now |
|---|---|---|
| B01 | Native guard hook for Codex | needs a verified Codex hook API; the command-level guard already covers Codex |
| B02 | Lock against two agents editing one worktree at once | design decision (docs define handoff as sequential) |
| B03 | Live handoff test with logged-in Claude → Codex / Gemini sessions | needs the user's authenticated CLIs |

## Verification log

- Every fix except R10, R11, R13 and R14 has a regression check in
  `tests/test-review-round2.sh` (R01, R02, R04–R07, R09, R12) or
  `tests/test-worktree-guard.sh` (R03). Against a copy of the pre-fix code
  (`b88ea04`), all 13 fix checks in round 2 and the 2 new guard checks that
  target the bug **fail**; on the fixed code they pass.
- R08: `tests/test-list.sh` passes on old and new code alike. That is expected,
  because it adds coverage to code that worked, not a fix.
- R10 checked by hand: note shown with `.husky/` and no `core.hooksPath`; gone once
  `core.hooksPath = .husky/_`.
- Full local run (2026-09-25, macOS): planning reconcile 137, worktree guard 36,
  Gemini hook 17, flow-next 34, providers 161, review-fixes 28, gsd-list 18,
  review round 2 19 — **450 passed, 0 failed**; copy-install suite passed.
  `bash -n` on every script, Python AST parse, whole-tree ShellCheck and
  `git diff --check` clean. Both new suites wired into CI and README.
- Hosted CI: the first run (`a23a87b`) failed in the new `gsd-list` wrap check.
  CI has no terminal, so the width fell back to 120 and the title wrapped
  differently. Fixed in `8932223`: `gsd-list` honors `COLUMNS`, and the test
  joins the wrapped cell before comparing. Run 36130616994 passed on Linux and macOS.
