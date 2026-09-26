# Changelog

Each release is a GitHub release `vX.Y.Z` with `gsd-worktrees-X.Y.Z.tar.gz`
and `SHA256SUMS`. Install or update: see the README. The section for a version
becomes its release notes.

## 0.3.1

- `gsd-ui shots`: a phase can name its app with `url:` in `<P>-LAYOUT.md`
  (e.g. `url: http://localhost:{port:3100}`). It wins over `ui_url` in
  `.gsd.conf`, so projects with several apps (two portals, an API) screenshot
  the right one per phase. The LAYOUT template has the new `url:` line, and
  the "several base ports" message says where to put it.

## 0.3.0

UI quality gates — so phases with screens stop shipping ugly pages. See
`docs/ui-quality-plan.md`.

- **Design system, once per project:** `.planning/design/DESIGN.md`
  (references, tokens, components, page templates). `gsd-ui design` makes the
  stub.
- **Layout, per phase with screens:** before the UI-SPEC, `/gsd-sketch` the main
  screen, the user picks the winner, and `<P>-LAYOUT.md` records it with the
  pages. `gsd-ui layout <N>` makes the template.
- **Screenshots before ui-review:** `gsd-ui shots <N>` shoots every page at
  phone, tablet and desktop size with the Playwright CLI; ui-review compares
  them with the sketch. `--skip "<reason>"` when it is impossible.
- `gsd-flow-next` has the new steps: design-system, layout, screenshots.
  Phases whose UI-SPEC already exists skip the two pre-spec steps.
- `ui_gates` in `.gsd.conf`: `warn` (default — steps and doctor notes),
  `strict` (the guard blocks `/gsd-ui-phase` and `/gsd-ui-review` until done;
  doctor T080), `off`. `gsd-init --no-ui` sets `off` for projects without
  screens.
- `ui_url` in `.gsd.conf` for the app address; `{port}` follows each
  worktree's port.
- `gsd-init` prints optional tools per provider (Claude: `frontend-design`
  plugin, Playwright MCP).
- The e2e suite no longer reads the laptop's installed skills.

## 0.2.3

`gsd-doctor` checks more (all read-only, as before):

- Toolkit: GSD's `gsd-sdk` missing (T005), `perl` missing (T006), installed
  skills that differ from this version (T007, for every configured provider).
- `.gsd.conf`: unknown keys and lines that are not `key = value` (T017), bad
  `flow` / `flow_since` / `start_mode` values (T018).
- Base branch missing, or only on origin (T015). No `origin` is a note.
- Pre-merge gate: script not executable, or a configured path that does not
  exist (T019).
- ROADMAP with two headings for one phase (T025). Without perl the roadmap row
  check says it was skipped instead of passing.
- A worktree whose dependency install failed (T032).
- `tracker = clickup` with no token on this machine (T073).
- Fix lines name the right reinstall command for a release install
  (`get.sh --version X --reuse-install-config`) or a git checkout.
- `install.sh --reuse-install-config --agent <p>` now adds `<p>` to the agents
  recorded by the last install instead of ignoring it.

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
