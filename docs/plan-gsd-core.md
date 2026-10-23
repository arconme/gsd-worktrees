# Plan: move gsd-worktrees from get-shit-done-cc to gsd-core

Status: approved plan, 2026-10-23. Nothing built yet.

## Why

GSD moved. The old npm package `get-shit-done-cc` (last release 1.42.3, May
2026) is marked "no longer supported" on npm, and its repo
`gsd-build/get-shit-done` was archived on 2026-06-26. GSD now lives at
[open-gsd/gsd-core](https://github.com/open-gsd/gsd-core), npm
`@opengsd/gsd-core` (1.18.0 on 2026-10-19; its version counter restarted, so
1.42.3 is *older* than 1.18.0).

gsd-worktrees still assumes the old package. Every new user who installs GSD
today gets gsd-core, and `gsd-start` cannot claim a phase there.

## What we found

Research, 2026-10-23: the gsd-core source was read, and its CLI was built and
run on a throwaway project.

### Breaks

| What | Old | gsd-core | Where we use it |
|---|---|---|---|
| CLI binary | `gsd-sdk` | **gone** (ADR-0174). `gsd_run` (only gsd-core ships it) or `gsd-tools` (the old package ships a different `gsd-tools` too, so don't trust the name) | `bin/gsd-start:299,377,385,413`, `bin/gsd-doctor` T005, `lib/version.sh` |
| Claim | `gsd-sdk query phase.add "<d>" --project-dir D` | `gsd_run query phase.add "<d>" --project-dir D`, same JSON fields (`phase_number`, `padded`, `slug`, `directory`) | `gsd-start` |
| Insert | `gsd-sdk query phase.insert N "<d>" …` | same verb; `phase_number` is still a padded string (`"02.1"`) | `gsd-start` parses it with `sed` |
| TDD default | `gsd-sdk query config-set workflow.tdd_mode true …` | same verb | `gsd-start` |
| Version | `gsd-sdk -v` | `-v` is rejected. Use `gsd_run runtime-identity`, which prints `{"packageName":"@opengsd/gsd-core","version":…}`, or read `<config>/gsd-core/VERSION` | `lib/version.sh`, doctor |
| npm package | `get-shit-done-cc` | `@opengsd/gsd-core` | `GSD_GSD_UPDATE_CMD`, the npm latest check, the T005 and T008 fix text |
| Gemini | a GSD runtime; `/gsd-review --gemini` | **removed** in gsd-core 1.8.0. Google ended Gemini CLI on 2026-06-18; the successor is Antigravity | our `gemini` provider, `review_provider = gemini` (`lib/provider.sh` review flag) |

### Still the same

- Skill names: every `gsd-*` skill the flow and guard use still exists under
  the same name. 5 skills were added; none were renamed or removed.
- Phase artifacts and folders: CONTEXT, PLAN, SUMMARY, REVIEWS, REVIEW,
  VALIDATION, VERIFICATION, UI-SPEC, UI-REVIEW, SECURITY, UAT, RESEARCH.
- `.planning/` formats: ROADMAP headings, STATE.md (`Session Continuity`
  unchanged), the `config.json` keys we read, sketches with `winner:`.
- The upstream roadmap bug is still there: `phase.add`/`insert` write no
  checklist or Progress row. **Keep `lib/roadmap-rows.pl`**. The cross-phase
  tick looks fixed, but keep `lib/roadmap-audit.pl` as a cheap guard.
- Hook node paths: gsd-core finds node when the hook runs, so the nvm-upgrade
  breakage that led to T008 can't happen there. T008 already reads that
  format.

### Safe: the gsd-core installer won't delete our files

It decides what it owns by proof (its manifest, its own skill list, an exact
hook-name list), never by the `gsd-` prefix alone. Our skills,
`gsd-worktree-guard` hook entries, `~/.local/bin` links and repo `scripts/`
are left alone. One exception: if a user sets
`GSD_INSTALLER_MIGRATION_RESOLVE=remove`, the first-time migration would back
up and then remove copy-mode skill dirs (`install.sh --copy`). Our migration
guide says not to set it.

### To watch

- **Skill profiles:** gsd-core's `--profile=core` and `standard` leave out
  validate-phase, secure-phase, ui-phase, ui-review, sketch, spec-phase and
  others that the flow uses. gsd-worktrees needs `full`, which is the default.
- **`phase_id_convention: "bracket"`** (opt-in): this changes how phases are
  named, so our `### Phase N:` parsing, folder matching and the
  `phase-<N>-<slug>` branch names would all break.
- **New hook `gsd-worktree-path-guard.js`:** it blocks Edit/Write to absolute
  paths outside the current worktree. It needs a test with an agent working in
  a `phase-<N>` worktree.
- **"Phase complete"** now means a passing `*-VERIFICATION.md` on disk, not a
  ticked ROADMAP row. Our reconciler still uses the ticked row, so the two can
  disagree.
- **REVIEWS.md:** a section from a reviewer *instance* is headed
  `## X Review (inst)`. `gsd_reviews_problem` only sees headings that end in
  "Review", so it misses these.
- **Claude plugin form:** `/gsd-core:gsd-<name>` would reach the guard as an
  unknown name.
- **Codex:** gsd-core puts its global Codex skills in `~/.agents/skills`; we
  use `~/.codex/skills`. Hooks stay in `~/.codex/hooks.json`.

## Steps

Each step is one PR, with its tests. Run `tests/test-e2e.sh` after steps 1–2.

0. **Spike (no code kept).** Install gsd-core into a throwaway HOME
   (`--config-dir`), then:
   - wire `gsd_run` into a copy of gsd-start and run the e2e suite;
   - confirm the `phase.insert` output really is one key per line, and that
     `config-set workflow.tdd_mode` is accepted;
   - try an agent edit inside a phase worktree with `gsd-worktree-path-guard`
     on;
   - run the gsd-core installer over a copy-mode install of ours, and see
     whether it stops on our `.gsd-worktrees-skill` marker.

1. **One way to find GSD's CLI (gsd-core only).** Add `gsd_cli` to
   `lib/common.sh`. It tries, in order:
   - `$GSD_CLI` (an override, also used by tests);
   - `gsd_run` on PATH;
   - `<agent config>/gsd-core/bin/gsd_run`, because an `npx` install puts
     nothing on PATH.

   It checks `runtime-identity` so it never picks the old package's
   `gsd-tools`. Then the 4 `gsd-start` calls go through it. There is no
   `gsd-sdk` fallback. When only the old GSD is installed, `gsd-start` stops
   with "old GSD (get-shit-done-cc) — migrate: <command>" instead of failing
   halfway through a claim.

2. **Versions and updates.** `lib/version.sh`:
   - the installed version comes from `runtime-identity` or `VERSION`;
   - the latest comes from `npm view @opengsd/gsd-core`;
   - the update command becomes `npx @opengsd/gsd-core@latest`.

   Doctor:
   - T005 becomes "GSD (gsd-core) not found";
   - a new finding for "old get-shit-done-cc in use", with the migration
     command;
   - T008's fix text names gsd-core.

   Never compare 1.42.x against 1.18.x.

3. **Remove Gemini.**
   - `lib/provider.sh`: identity, instruction file, skill root, argv, review
     flag, hook metadata.
   - The CLI allowlists and help.
   - `install.sh --agent gemini`.
   - `lib/gsd_hook_payload.py`'s Gemini payload.
   - `tests/test-gemini-hook.sh` and the Gemini cases in
     `tests/test-providers.sh`.
   - `docs/gemini-hooks.md`, `docs/providers.md`.
   - The `~/.gemini` scan in T008.

   Cleanup of what we already installed (each step undoable and limited to
   what we own):
   - `install.sh` removes our `--global` guard entry from
     `~/.gemini/settings.json` and our marked skills from `~/.gemini/skills`.
   - `gsd-init` removes our marked block from `GEMINI.md` and our hook from the
     repo's `.gemini/settings.json`.

   A `.gsd.conf` that still says `providers = …gemini…` or
   `review_provider = gemini` gets a clear doctor finding ("Gemini was
   removed") and a clean refusal from `gsd-start`, never a crash. The legacy
   `--agent gemini` / `GSD_AGENT=gemini` inputs get the same refusal. This
   changes the "legacy configs keep working" invariant in `CLAUDE.md`, so
   update it there.

4. **Guard and gates.**
   - Map `gsd-core:gsd-x` to `gsd-x` in `lib/gsd_hook_payload.py`.
   - Read `## X Review (inst)` headings in `gsd_reviews_problem`.
   - Add doctor findings for `phase_id_convention = bracket` and for a profile
     that is not `full`.
   - Check the Codex skill dir.

5. **Docs and a user migration guide** (`docs/migration.md`). The steps:
   1. `npx -y --package=@opengsd/gsd-core@latest -- gsd-core --claude --global --dry-run`
   2. the same command without `--dry-run`
   3. `npm rm -g get-shit-done-cc`
   4. `gsd-doctor`

   Don't set `GSD_INSTALLER_MIGRATION_RESOLVE=remove`.

6. **CI.** Install `@opengsd/gsd-core` in CI so the e2e suite runs against
   it. Rename the test stubs from `gsd-sdk` to `gsd_run`. Add one test that an
   old-GSD-only machine gets the "migrate" refusal.

Before step 1: merge `flow-default` and `doctor-stale-hooks` (T008) into
`main`. Steps 2 and 3 edit T008.

Release: one breaking release, with all steps in it, the migration guide at
the top of its CHANGELOG entry, and this machine migrated with that guide on
the same day.

## Decisions (2026-10-23)

- **gsd-core only.** No `gsd-sdk` fallback. Old-GSD users get a clear
  "migrate" message from `gsd-start` and `gsd-doctor`.
- **Gemini is removed now**, with the cleanup in step 3. An Antigravity
  provider would be separate, later work.
