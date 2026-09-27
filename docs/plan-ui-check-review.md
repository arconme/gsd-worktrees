# Review of `plan-ui-check.md`

Reviewer: Codex (`gpt-6-astra`, read-only sandbox), 2026-09-27. Verdict:
**build with changes.** Each finding was then checked against the code by
Claude; the last two columns are that validation.

Checked facts (all 12 correct): `lib/ui.sh:78` (GSD_PLAYWRIGHT),
`bin/gsd-ui:143` (slug: `/a/b` and `/a-b` both give `a-b`), `bin/gsd-ui:146–154`
(PNGs written in place, `SHOTS.md` last, `taken:` to the second),
`bin/gsd-flow-next:218` (file existence only), `bin/gsd-worktree-guard:215–221`
(rule 5 covers ui-phase and ui-review only), `bin/gsd-wt-finish:152–169`
(finish validates with the premerge script or tests, no UI artifacts),
`bin/gsd-doctor:611,653` (T040 only under `flow = strict`), `bin/gsd-doctor:95,114`
(notes vanish in `--json`), `lib/ui.sh:39` (first match only), `lib/ui.sh:148`
(main button is a prose heading), no browser in `.github/workflows/tests.yml`.
Node module resolution was tested: a bare `import("@playwright/test")` from a
script outside the project fails (`ERR_MODULE_NOT_FOUND`); `createRequire`
anchored at the project's `package.json` finds it.

## Findings

| # | Sev. | Finding (short) | Valid? | Change to the plan |
|---|---|---|---|---|
| 1 | high | A toolkit `.mjs` cannot `import` the project's Playwright; finding `.bin/playwright` does not help | **yes** (tested) | Resolve with `createRequire` anchored at a chosen package root; same root for everything |
| 2 | low | Plan misdescribes today's lookup (omits `GSD_PLAYWRIGHT`; `url:` is 0.3.1) | yes | Fix the text |
| 3 | med | First match in `apps/*` may pick another app's Playwright | yes | `app:` in LAYOUT (package root of the phase's app); refuse when ambiguous; record path + version |
| 4 | high | Check, look and approval can go stale; only approval is tied to `taken:` | **yes** | One capture id per run; check, look and approval name it. Simpler than proposed: id + git commit + hash of uncommitted changes outside `.planning/` (no per-tool fingerprints) |
| 5 | high | "Has UI-REVIEW.md → skip everything" lets a new phase bypass all gates | **yes** | Exempt only phases whose UI-REVIEW.md is already on the base branch; one shared predicate for flow, guard, doctor |
| 6 | high | Nothing checks approval before `gsd-finish`; later fixes can change the page | **yes** | Under `strict`, `gsd-finish` validates the UI artifacts are current (GSD_SKIP_GUARD stays the escape) |
| 7 | high | A failed run can leave an older pass (or mixed pictures) in place | **yes** | Capture into a run folder, publish when complete, record failed attempts |
| 8 | med | Look is per page, not per screenshot; deleting rules could pass | yes | Validate the exact (page, size, rule) set; bind to the capture id |
| 9 | med | `shots --skip` silently skips check, look and approval | yes | Separate records: no runner / skipped capture / waived approval, each with the user's OK |
| 10 | med | Doctor debt only under `flow = strict`; screens detected differently than in the flow | yes | Shared predicates; spell out the mode matrix |
| 11 | med | C1 only sees page-level sideways scroll | yes, simpler | Rename to "page scrolls sideways", 1px tolerance, name the widest element |
| 12 | med | C2 is noisy | yes | C2 becomes "possible clipped text": needs an answer in the look file, never an automatic failure |
| 13 | high | axe returns `incomplete` (could not measure) — counting only violations reports a false pass | **yes** | Record violations / incomplete / errors apart; `strict` requires an answer for incomplete |
| 14 | med | C4 misses scaled text; excluding `aria-hidden` hides visible text | yes, simpler | Test rendered visibility, not `aria-hidden` / class names; validate `ui_min_font` |
| 15 | med | C5 misses lazy images, CSS backgrounds | yes, simpler | Scroll the page once to trigger lazy images; `<img>` only, stated as the scope |
| 16 | med | C6: every `console.error` blocks; reports may leak data | yes | Uncaught errors fail; console errors are listed; trim messages in the committed report |
| 17 | high | `main_button:` has no contract; one field for many pages; center hit test is weak | **yes** | Per page, exactly one match required, `none` allowed; missing = not configured, never a pass |
| 18 | high | C8 can pass a login redirect or an error shell (HTTP 200) | **yes** | Per page: final URL must match, plus an optional `expect:` text |
| 19 | med | `networkidle` + one retry is not readiness | yes, simpler | Wait for `load`, fonts and images, then the `expect:` text; fixed time budget |
| 20 | high | "Never handles credentials" is false: `storageState` holds login secrets | **yes** | State the trust model; require the file to be untracked; never copy it into reports. (Schema / origin validation: not adopted) |
| 21 | high | The runner runs project code with the user's rights | yes | Document it; never load the project's Playwright config; doctor never imports or launches |
| 22 | med | Ignored screenshots vanish with the worktree; tracked PNGs are not un-tracked | yes, simpler | Detect tracked PNGs; approval must happen before finish (covered by 6) |
| 23 | med | The HTML sheet can run injected content; slug collisions | **yes** (collision tested) | Escape all text; add a hash to file names |
| 24 | med | R1–R10 are taste, not law; free `n/a` neutralizes them | partly | Rules are defaults a project edits in DESIGN.md; `n/a` needs a reason (already planned) |
| 25 | med | Canonical instructions (`lib/provider.sh`) and doctor `--json` notes are missing from the plan | **yes** | Add both; T016 will then flag projects until they re-run gsd-init (intended) |
| 26 | high | Stub tests + an optional browser suite = an untested checker | **yes** | A real-browser CI job with fixture pages for C1–C8; `.mjs` syntax check |
| 27 | — | Q1: two files | agree | `UI-CHECK.md` (machine) + `UI-LOOK.md` (agent) |
| 28 | — | Q2: `check` replaces `shots` in the flow | agree | One step; `shots` stays for manual use |
| 29 | — | Q3: ship a pinned `axe-core` | agree | Vendor the bundle with its license (MPL-2.0) and version |
| 30 | — | Q4: separate approval file | agree | `<P>-UI-APPROVAL.md`, names the capture id |
| 31 | — | Q5: waivers in LAYOUT, structured | agree, simpler | check + page + size + target + reason. No expiry dates |

## Not adopted (and why)

- Per-tool version and config fingerprints (part of 4): a capture id plus the
  code state is enough to detect staleness.
- `storageState` schema and origin validation (part of 20): the browser
  already scopes cookies by origin; the real risk is the file being committed.
- Waiver expiry (part of 31): a waiver is tied to a phase, which ends.

## Effect on the plan

Scope grows from about 1 day to about 2. Suggested split:

- **0.4.0:** runner (module resolution, capture id, staged output), checks,
  sheet, look file, approval, finish gate, canonical text, real-browser CI.
- **0.4.1:** pages behind a login (`ui_auth`), add-on suggestions in doctor,
  structured waivers.
