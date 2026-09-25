# Fresh-review fix tracker

Scope: address the fresh review on the agent-agnostic feature worktree. No
consumer repositories, planning state, commits, pushes, or merges are part of
this implementation task. Git operations in isolated test fixtures are allowed.

Status: `pending`, `in progress`, `verified` (implementation and regression tests).

| ID | Finding / acceptance criterion | Status |
|---|---|---|
| F01 | Finish fails safely on sync failure and validates combined changes before push, including retries | verified |
| F02 | Claude hook parses nested arguments without jq; wrong-phase requests fail | verified |
| F03 | Doctor reports actual command guard and structurally valid hook state | verified |
| F04 | Bootstrap preserves user additions to canonical instructions | verified |
| F05 | Sync preserves installed provider selection; check is read-only | verified |
| F06 | Flow handles artifact paths containing spaces | verified |
| F07 | Finish rejects non-phase and PR-helper branch targets | verified |
| F08 | Planning post-merge hook is executable and idempotently repaired | verified |
| F09 | Codex/custom shared entrypoint is unambiguous; doctor validates complete blocks | verified |
| F10 | Installer rejects symlink aliases, handles stale copy commands safely, and preflights Python | verified |
| F11 | Shared provider metadata and skill paths used consistently | verified |
| F12 | Review provider validation and honest capability limitations | verified |
| F13 | Workflow/skill/HTML order, human gates, finish rule, configuration and test docs agree | verified |
| F14 | Full tests, syntax, ShellCheck, isolated doctor checks and final diff review | verified locally; hosted CI pending |

Execution groups: core safety (main agent), integration/configuration,
installation/sync, documentation. Independent groups run concurrently; main
agent reviews their changes and runs the complete suite before closing items.
Delegated workers stopped on a usage limit; the main agent completed and reviewed
the remaining work locally. The skill-creator guidance was used to validate both
skill entrypoints and remove conflicting approval/invocation instructions.

## Verification log

- Starting point: prior full suite 382 assertions plus copy-install suite;
  fresh review reran flow 34, guard 33, Gemini hook 17. These passing tests did
  not cover the newly identified cases.
- Regression suite `test-review-fixes.sh`: 28 checks, including an actual local
  bare-remote push race, combined-tree test fallback, no-jq Claude payloads,
  canonical migration/user additions, custom/Codex shared instructions and
  doctor JSON corruption checks. No authenticated provider sessions are used.
- Copy-install suite additionally covers preserved sync selection/destinations,
  copy upgrade retirement/backups, symlink slash aliases, and Python preflight.
- Final local run (2026-09-25): flow **34**, planning reconciliation **137**,
  worktree guard **33**, provider adapters **161**, Gemini hooks **17**,
  fresh-review regressions **28**: **410 assertions passed, zero failures**.
  The standalone copy-install suite also passed (including sync/no-fetch and
  installation safety regressions; that suite does not count assertions).
- All shell files passed `bash -n`; whole-tree ShellCheck, Python AST parsing,
  both skill validators, and `git diff --check` passed. Provider suites exercised
  doctor JSON in isolated Claude/Codex/Gemini/multi-provider repositories.
- Rechecked provider references: adapters, compatibility paths, fixtures and
  documentation only; classification recorded in `provider-audit.md`. Rendered
  Claude/Codex/Gemini flow launch commands with a space-containing working path.
- Main checkout remains clean. The feature worktree contains only intended
  refactor/fix/test/documentation changes; no planning state or consumer repository
  was changed. No toolkit commit, push, or merge was performed.

## Operational changes and limits

### Post-fix handoff smoke test (2026-09-25)

Toolkit-level scenario passed in a disposable repository: initialized
`providers = claude,codex` with strict flow, attached phase 7 with Claude's
printed discuss command, recorded an explicitly simulated discussion fixture,
then attached the same phase with Codex's printed flow command. The worktree,
branch HEAD, discussion checksum and repository provider configuration were
unchanged by handoff. The engine moved from discuss to plan; missing-discussion,
wrong-phase, base-checkout and missing-review execution guards all blocked.

**Live-agent validation remains pending.** Both installed CLIs report logged
out under the temporary configuration directories. No Claude discussion or
Codex planning model session ran; the discussion artifact was test data, not
AI output. No credentials were copied or authentication settings changed.
The fixture and logs are under `/tmp/gsd-handoff.DNCvjp/second` (ephemeral).
Temporary Codex state isolation follows the [official configuration documentation](https://learn.chatgpt.com/docs/config-file/config-advanced#config-and-state-locations).
Completing the live test requires user authentication in the isolated profiles.

- Finish now validates combined code in the base checkout too. Its dependencies
  must be installed there. Failures retain local merge commits and the phase
  worktree; they do not push or automatically roll back user work.
- External `gsd-review` supplies automatic reviewer delegation. This toolkit
  validates/selects its known flags and prints a manual handoff when unsupported;
  it does not implement a universal subprocess runner.
- Copy installs without an older ownership inventory cannot safely auto-retire
  historical obsolete files. New inventories cover command retirement; changed
  files are backed up, and unrelated files are never pruned.
- Linux/macOS CI is configured, but hosted runs require the normal later push/PR.
  This task does not authorize a commit, push, or merge.
