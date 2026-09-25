# Changelog

Each release is a GitHub release `vX.Y.Z` with `gsd-worktrees-X.Y.Z.tar.gz`
and `SHA256SUMS`. Install or update: see the README. The section for a version
becomes its release notes.

## 0.2.2

Same as 0.2.1, which was tagged but never released (a test needed a command on
PATH that CI does not have):

- `gsd-doctor` shows newer versions (gsd-worktrees and GSD itself) even with
  `--quiet`, and lists them under `updates` in `--json`. Still never a finding.
- `gsd-start`, `gsd-list` and now `gsd-init` also tell you about a newer GSD on
  npm, not only a newer gsd-worktrees (terminal only, checked once a day).

## 0.2.0

- **Install from GitHub releases.** One `curl … get.sh | bash` line; no git
  checkout needed. `gsd-update` installs newer releases (or an older one with
  `--version`). `gsd-start`, `gsd-list` and `gsd-doctor` say when a newer
  release is out (at most one GitHub call a day; `GSD_NO_UPDATE_CHECK=1` turns
  it off).
- **Tickets from any tracker.** `gsd-tracker` with `tracker = none` (default),
  `clickup`, or `custom` (your script). `gsd-start --ticket <id|url>` tags the
  phase `tk-<id>`; the flow's `ticket` step saves `<P>-TICKET.md`.
  `--cu`, `cu_` tags, `STORY.md` and `gsd-clickup` still work.
- **Any AI agent.** Claude Code, Codex, Gemini and custom agents as adapters;
  hand one phase between them with `gsd-start -p N --provider X`.
- **Safer claims.** The claim race is decided on origin before merging; a claim
  writes its checklist and Progress rows and correct STATE counters; zero-padded
  decimal phases (`02.1`) work everywhere.
- MIT license.
- Fixes from two full reviews (docs/fix-plan.md), an end-to-end test suite, and
  `gsd-list` that honors `COLUMNS`.

## 0.1.0

- First tagged version: per-phase worktrees, `gsd-start` / `gsd-finish` /
  `gsd-list` / `gsd-doctor`, the `.planning` merge driver, and the guard.
