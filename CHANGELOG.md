# Changelog

Each release is a GitHub release `vX.Y.Z` with `gsd-worktrees-X.Y.Z.tar.gz`
and `SHA256SUMS`. Install or update: see the README. The section for a version
becomes its release notes.

## 0.4.0

The UI steps now look at the built page, not only at the code
(`docs/plan-ui-check.md`).

- `gsd-ui check <N>`: opens every page of the phase at 375, 768 and 1440 px
  in the project's own Playwright, measures it, takes the pictures, and
  writes `<P>-UI-CHECK.md` and a sheet (`<P>-SHOTS/index.html`). Checks: the
  page scrolls sideways (C1), text may be cut off (C2), contrast (C3, a
  pinned axe-core ships with the toolkit), small text (C4, `ui_min_font`,
  default 12), broken images (C5), page errors (C6), the main button is
  missing, below the first screen or covered (C7), the page did not load or
  is another page such as a login (C8). Exit 0 passed, 1 failed, 2 could not
  run. Needs Node and Playwright in the project.
- New lines in `<P>-LAYOUT.md`: `main_button: /path = Text` (or
  `css=<selector>`, or `none`), `expect: /path = text on the page`,
  `app: <folder with Playwright>`, and
  `waive: <check> | <page> | <width> | <target> | <reason>` for a finding you
  accept.
- `gsd-ui look <N>` writes `<P>-UI-LOOK.md`: the agent answers one line per
  picture and layout rule (R1–R10; edit them in `DESIGN.md`) with what it
  saw. `gsd-ui sheet <N>` shows you the pictures; `gsd-ui approve <N>`
  records your yes (`--waive "<reason>"` when you choose not to look).
- Flow: `ui-check → ui-look → ui-approve → ui-review` replaces the
  `screenshots` step. The check remembers the code it ran on: change the code
  and the step opens again. Pages that still look the same keep their look
  and approval.
- `ui_gates = strict`: the guard blocks `/gsd-ui-review`, and `gsd-finish`
  (also `--pr`) refuses, until check, look and approval are current.
  `warn` (default) shows the steps and warns at finish. A phase whose UI
  review is already merged is left alone.
- `gsd-doctor`: UI debt of merged phases (T040 `ui-check`, `ui-approve`) no
  longer needs `flow = strict`; T081 = pictures committed by mistake;
  `ui_min_font` is checked (T018); notes are listed in `--json`; the
  Playwright note also looks in `apps/*` and `packages/*`.
- `gsd-ui shots` stays for pictures without checks. Picture names now carry a
  short hash, so `/a/b` and `/a-b` no longer share one file.
- **After updating:** the instruction text changed, so `gsd-doctor` reports
  T016 in each project. `gsd-doctor --fix` refreshes it.

## 0.3.4

- `gsd-doctor` T016: the project's GSD instructions (`.gsd/INSTRUCTIONS.md`
  and the marked blocks in `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`) are older
  than the installed toolkit, so agents follow old rules. Doctor compares
  each block with what `gsd-init` would write today — a release that doesn't
  change the text raises nothing, and your own text outside the blocks is
  ignored. `gsd-doctor --fix` refreshes them (runs `gsd-init`).
- The instruction text now has one definition in `lib/provider.sh`, shared by
  `gsd-bootstrap-repo` and `gsd-doctor` (output unchanged).

## 0.3.3

- `flow_skip` in `.gsd.conf`: leave single merged phases out of doctor's
  flow-debt report (T040), e.g. `flow_skip = 13.1, 14   # shipped before the
  rules`. Unlike `flow_since` (a cutoff), phases around them are still
  checked, and doctor lists the skipped ones as a note. Bad entries are T018.
- Fix: the T040 report now finds zero-padded decimal phase folders
  (`04.1-…`, as gsd-sdk writes them) — such phases were silently skipped.

## 0.3.2

- `gsd-doctor --fix`: after the normal check, runs only the safe fixes it
  found — `gsd-init --no-launch --no-commit` (shims, merge rules, driver,
  hook, instructions), `gsd-planning-repair` (planning damage and stale
  STATE.md counters), `git branch --track <base>`, `chmod +x` on the pre-merge
  script, and removing a lock whose process is gone. It lists them, asks
  (y/N; `--yes` for scripts), runs them, checks again, and lists the changed
  files. It never commits, pushes, checks out, deletes branches or edits
  ROADMAP.md — those stay commands for you. Without `--fix`, doctor still
  writes nothing, and it now says when `--fix` could help.

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
