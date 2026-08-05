---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: planning
stopped_at: Phase 10 context gathered
last_updated: "2026-08-05T09:34:25.661Z"
last_activity: "2026-08-05 - Completed quick task 260805-ghb: seed .planning/GLOSSARY.md + CLAUDE.md pointer"
status: ready_to_plan
stopped_at: Phase 11 complete (15/15) — ready to discuss Phase 12
last_updated: 2026-08-05T08:59:46.310Z
last_activity: 2026-08-05
progress:
  total_phases: 30
  completed_phases: 12
  total_plans: 96
  completed_plans: 96
  percent: 40
  total_phases: 28
  completed_phases: 11
  total_plans: 103
  completed_plans: 103
  percent: 39
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-02)

**Core value:** A member can see the state of their insurance approvals and act on them (verify at provider, view dispensed services) — the approvals flow is the product; everything else supports it.
**Current focus:** Phase 11 — catalogs and import framework
**Current focus:** Phase 12 — provider onboarding

## Current Position

Phase: 11
Phase: 12
Plan: Not started
Worktree: ../medyour-platform-worktrees/phase-28-canonical-card-treatment-...
Status: Ready to plan
Last activity: 2026-08-05 - Completed quick task 260805-ghb: seed .planning/GLOSSARY.md + CLAUDE.md pointer
Last activity: 2026-08-05

Progress: [██████████] 97%

**Outstanding human UAT:** Phase 26 (6 device items), Phase 27 (17 visual items) — both
deferred because device testing was off during those build sessions.

## Performance Metrics

**Velocity:**

- Total plans completed: 102
- Total plans completed: 109
- Average duration: - min
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 5 | - | - |
| 03 | 13 | - | - |
| 04 | 6 | - | - |
| 05 | 4 | - | - |
| 06 | 10 | - | - |
| 07 | 14 | - | - |
| 08 | 4 | - | - |
| 09 | 12 | - | - |
| 26 | 5 | - | - |
| 27 | 11 | - | - |
| 28 | 6/7 | - | - |
| 10 | 8 | - | - |
| 11 | 15 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*

**Recent plan durations:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 05 P01 | 16min | 2 tasks | 6 files |
| Phase 05 P02 | 15min | 2 tasks | 10 files |
| Phase 05 P03 | 25min | 3 tasks | 3 files |
| Phase 26 P03 | 5min | 2 tasks | 3 files |
| Phase 11 P15 | ~55min | 4 tasks | 9 files |

## Accumulated Context

### Roadmap Evolution

- Phase 9 added: Web foundation (TPA milestone 2)
- Phase 10 added: Delivery infra (TPA milestone 2)
- Phase 11 added: Catalogs and import framework (TPA milestone 2)
- Phase 12 added: Provider onboarding (TPA milestone 2)
- Phase 13 added: Client onboarding (TPA milestone 2)
- Phase 14 added: Consumption ledger (TPA milestone 2)
- Phase 15 added: Approval engine (TPA milestone 2)
- Phase 16 added: Manual review queue and notifications (TPA milestone 2)
- Phase 17 added: Staff intake tool (TPA milestone 2)
- Phase 18 added: Pilot configuration (TPA milestone 2)
- Phase 19 added: Provider portal requests and approvals (TPA milestone 2)
- Phase 20 added: Verify and dispense (TPA milestone 2)
- Phase 21 added: Branch self-service and admin queue (TPA milestone 2)
- Phase 22 added: Member app API integration (TPA milestone 2)
- Phase 23 added: Employer portal (TPA milestone 2)
- Phase 24 added: Claims adjudication and provider claims views (TPA milestone 2)
- Phase 25 added: Claim batches and settlement exports (TPA milestone 2)
- Phase 9 edited: edited fields: goal, design source, success_criteria (design-system-first framing)
- Phase 26 added: Manual governorate/city location fallback for Providers: when GPS is unavailable (location permission denied or services off), let the user pick an Egyptian governorate and city and show branches filtered by that city. Add a public cities-by-governorate endpoint, a governorate/city picker (reusing existing SelectField/SelectInput sheets), persist the selection in the location store, and switch the Providers list between nearby (GPS) and city-filtered modes; include the open/closed badge in manual mode and a change-location affordance.
- Phase 27 added: Canonical Sheet component + migrate all bottom sheets. Today every bottom sheet builds its own header/padding/separator on top of THREE divergent foundations (AppModal on BottomSheetModal with ModalHeader+paddingTop:10; AppBottomSheet on BottomSheet with an inline header+paddingBottom:5+own padding model; and ~5 sheets on raw BottomSheetModal/BottomSheet with fully hand-rolled chrome). Separators are ad-hoc across 5 components (ListLineSeparator/ListSeparator/Separator/DottedSeparator). The visual chrome IS already unified via ModalBackground (E0FDFF->FFF gradient, rounded top-left only, drag handle hidden) — keep it. Build ONE canonical Sheet built on BottomSheetModal that owns all shared chrome in a single place: a SheetHeader (title + close, one spacing), horizontalPadding applied to content ONCE and correctly (this fixes the class of bug where BottomSheetFlatList rows escape the wrapper padding — the CallProviderModal row-padding fix in quick task 260713-iyx was a symptom), a canonical Sheet.Separator, and a Sheet.List helper wrapping BottomSheetFlatList with standard row padding + separator so list-sheets stop re-inventing it. Loader/backdrop/safe-area/handle inherited as overridable defaults. Then migrate ALL ~20 sheets onto it (approvals/* sheets, Otp sheets, ConfirmModal, DeleteAccount, Notifications, SearchModal, GuestAccessGuard, CountryNotSupported, CallProviderModal, ProvidersMapModal, QuickServicesSheet, SwitchUserSheet, MoreSheet, DeleteConfirmationBottomSheet, ProfileImageEditor, DatePicker/Select field+input sheets) and retire AppBottomSheet + the raw-BottomSheet usages. Each migrated sheet must be screenshot-verified against its current look (no visual regression). Mobile app only (apps/mobile), strict tsconfig + eslint (nullish/optional-chain/type-imports).
- Phase 28 added: Canonical card treatment — unify all cards on the DiagonalCard/cardRadius Select shell (fold AppCard+ListCard into DiagonalCard, convert Paper Surface cards to diagonal shell, screenshot-verify each)
- Phase 13.1 inserted after Phase 13: Split of Phase 13: members/families/network mapping separated from the client+plan/TOB schema work (evidence: 13-TOB-INVENTORY.md). Also fixes a dependency bug — network mapping needs Phase 12's providers, so the combined Phase 13 could not run parallel with 12 as claimed.
- Phase 14 edited: depends_on corrected to Phase 13.1 after the Phase 13 split (ledger needs member records); requirements note added about multi-level pools from the TOB inventory

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Commerce retirement (Phase 3) pulled early, right after the nav shell (Phase 2), since nothing is live and deletion shrinks all later phases.
- Roadmap: Phases 4 (Home), 5 (Onboarding), 6 (Providers) are independent of each other — parallelizable/reorderable once Phase 1 + 2 land.
- Roadmap: Approvals zod contract (Phase 7) lives in `@medyour/shared` under the packages/shared purity rule (pure TS + zod only).
- [Phase 05-01]: property:'code' (not 'mobile') on the new otp/code endpoint's not-found errors, so mapFormErrors binds inline to the hero's code field (D-10/Pitfall 2)
- [Phase 05-01]: /auth/otp/code returns the real resolved mobile (D-10 accepted disclosure) so verify/signInWithOtp stay mobile-keyed and untouched
- [Phase 05-02]: memberCode() validator imposes no format regex (trim + non-empty only) since a member code is free-form, not a fixed-format identifier (D-02)
- [Phase 05-02]: onboarding brand tokens (tokens.onboarding.*) alias existing colors.json palette entries (teal/tealField/tealBlack/tealInk/cyan) rather than introducing new hex
- [Phase 05-03]: Used useAppBottomSheet (plain BottomSheet ref) instead of the plan's useModal note - AppBottomSheet wraps a plain BottomSheet, not BottomSheetModal
- [Phase 05-03]: OTP rate-limit errors (property:'mobile') surfaced via toast (formState.errors.mobile watch + clearErrors) instead of inline, since the OTP sheet renders no visible mobile field
- [Phase 26-03]: useSuggestedProvider gate left untouched so D-05 (hide Suggested in city mode) requires zero code change there
- [Phase 26-03]: ProviderCardProps.item.distance relaxed to optional (was required number) to match the real city-mode payload shape
- [Phase 11-15]: Phase 11's full automated suite is green in one run (backend e2e: categories/diagnoses/services-catalog/imports/cities/auth-code-otp pass; payment/orderTransaction/pwg-transaction/userTransaction are the pre-existing, documented failures — web Vitest 42/42, web Playwright 8/8 including the new import-wizard spec, both workspaces' typecheck, and web lint at zero warnings) — see 11-15-SUMMARY.md.
- [Phase 11-15]: Seeded Operators (SYSTEM_USER staff, PROVIDER_USER + a TypeORM-created Branch) directly via a throwaway script for live Playwright verification, since the legacy raw-SQL 11-branch.sql seed fixture fails against the branch table's generated location column
- [Phase 11-15]: Fixed a real Tabs orientation bug found during phase-gate visual verification (data-horizontal:/group-data-vertical/tabs: never matched Radix's real data-orientation attribute) rather than deferring it, since it broke the Items/Categories tab layout on every catalog screen

### Pending Todos

None yet.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260703-h32 | Fix phase-01 typography fidelity: map weight tokens to font families (fontWeight 300 is a no-op with custom-registered fonts) | 2026-07-03 | a14884d2 | [260703-h32-fix-phase-01-typography-fidelity-map-wei](./quick/260703-h32-fix-phase-01-typography-fidelity-map-wei/) |
| 260704-1kq | Update scope diagram in docs/medyour-scope-and-milestones.html: service-delivery node, employer portal node, cross-cutting strip (docs/ is git-ignored — no source commit) | 2026-07-03 | n/a (untracked file) | [260704-1kq-update-scope-diagram-module-nodes-in-med](./quick/260704-1kq-update-scope-diagram-module-nodes-in-med/) |
| 260704-fast | Scope-doc consistency edits: member-reimbursement deferred line, M4 service-delivery modules, swimlane terminology aligned to rejected/funder | 2026-07-03 | n/a (untracked docs) | — |
| 260713-iyx | Fix CallProviderModal call sheet: pad phone-number rows so numbers/Call button align with the sheet header (button no longer clips right edge) | 2026-07-13 | baa7565a | [260713-iyx-fix-callprovidermodal-call-sheet-row-hor](./quick/260713-iyx-fix-callprovidermodal-call-sheet-row-hor/) |
| 260713-uud | Restyle canonical Sheet chrome to Select design: flat n100 bg + both top corners rounded, 0.88 backdrop, title3 header + hairline divider, dark close icon — all sheets inherit | 2026-07-13 | e3758702 | [260713-uud-restyle-canonical-sheet-chrome-to-select](./quick/260713-uud-restyle-canonical-sheet-chrome-to-select/) |
| 260714-cuy | Favourites screen rich redesign (sketch 001 variant B): FavouriteEntry.type + store v2, two-tier FavouriteCard (icon tile, pin/city line, type chip, View details) with SwipeToDeleteCard remove + toast, count summary row | 2026-07-14 | aa0442f0 | [260714-cuy-favourites-screen-rich-redesign-sketch-0](./quick/260714-cuy-favourites-screen-rich-redesign-sketch-0/) |
| 260714-dd3 | Align home screen horizontal padding with the rest of the app (providers pattern): sections container, carousel item inset, offer card width all use theme.spacing.horizontalPadding | 2026-07-14 | ae4f284c | [260714-dd3-align-home-screen-horizontal-padding-wit](./quick/260714-dd3-align-home-screen-horizontal-padding-wit/) |
| 260714-fast | Change app identifier to com.medyour.select (app.config.ts ios/android + eas.json submit); Firebase configs + ASC app record still reference old id — external console follow-ups pending | 2026-07-14 | 3189c5a6 | — |
| 260714-fast | Replace google-services.json with new Firebase download containing com.medyour.select Android client (iOS plist + ASC record still pending) | 2026-07-14 | 797bb0b3 | — |
| 260714-fast | Replace GoogleService-Info.plist with new com.medyour.select Firebase iOS app — Firebase now fully on new id; only ASC app record (eas.json ascAppId) still pending | 2026-07-14 | 850b4079 | — |
| 260714-fast | Rename app display name Medyour → Select and scheme medyour → com.medyour.select in app.config.ts (slug/owner/projectId untouched — EAS project identity preserved) | 2026-07-14 | dab654a4 | — |
| 260714-fast | Rebrand EAS: slug medyour → select, removed stale extra.eas.projectId — user must run `eas init` from apps/mobile to link the new project before next EAS build | 2026-07-14 | 64da6dd2 | — |
| 260714-fast | Created + linked new EAS project @medyour/select (projectId 138fb66d-f140-443b-9a4b-c6f36d565995) via eas init; verified with eas project:info — rebrand complete except ASC record | 2026-07-14 | 0863fbe1 | — |
| 260714-fast | Update CLAUDE.md app identity: Select / com.medyour.select / EAS @medyour/select + stale-ascAppId note | 2026-07-14 | 65eced1f | — |
| 260714-dk1 | CI/CD: Dockerfile apps/web importer fix + deploy-backend.yml (WIF keyless, push-to-main auto-deploy to medyour-be-prod, first run green) + build-mobile-android.yml (EAS preview APK on main pushes; needs EXPO_TOKEN + Android keystore on @medyour/select) | 2026-07-14 | d8396e37 | [260714-dk1-backend-deploy-prep-dockerfile-apps-web-](./quick/260714-dk1-backend-deploy-prep-dockerfile-apps-web-/) |
| 260714-g93 | Profile details renders the active (switched) member from useActiveMemberStore (falls back to fetched profile for principal/null; mobile/birthDate rows guarded for sparse member payloads) | 2026-07-14 | 89bc76a9 | [260714-g93-profile-screen-shows-the-active-switched](./quick/260714-g93-profile-screen-shows-the-active-switched/) |
| 260715-qvg | Make home-screen "Our tips keeps you healthy" heading static — hoisted out of HomeCarousel renderItem to render once above `<Carousel>` (kept horizontal inset/position); CAROUSEL_HEIGHT 172→138 | 2026-07-15 | f1d9e9a3 | [260715-qvg-make-the-home-screen-tips-heading-static](./quick/260715-qvg-make-the-home-screen-tips-heading-static/) |
| 260715-r4m | Add client-side search to notifications screen — reuse SearchBar (debounce 300ms) above AppQueryList, memoized filterFn over title/message (case-insensitive); AppQueryList.filterFn already existed. New notifications.searchPlaceholder locale key (en/ar). Client-side only, no refetch | 2026-07-15 | cf238183 | [260715-r4m-add-a-client-side-search-input-to-the-no](./quick/260715-r4m-add-a-client-side-search-input-to-the-no/) |
| fast | Notifications screen: remove "You've got x new notifications" text row; move delete-all icon into nav header via navigation.setOptions headerRight (AppStackHeader renders it, white tint on teal bar); same visibility gate (notifications exist & unread>0) | 2026-07-15 | 054d2aef | — |
| fast | gitignore apps/mobile/design/verification generated images | 2026-07-13 | n/a | — |
| fast | Repair GSD bookkeeping: de-duplicate STATE.md (2 frontmatter blocks, duplicated focus/position/velocity sections) + ROADMAP.md (phases 5-8 listed twice, orphaned plan lists), add phases 26/27/28 to checklist + progress table, remove stale phase-9-home-rebuild worktree | 2026-08-02 | (this commit) | — |
| 260805-ghb | Seed `.planning/GLOSSARY.md` with domain/process/requirement-prefix/stack abbreviations (TOB, TPA, ICD, Seha/SehaOne, CR/WR, APPR/COMP/..., WIF, EAS) — each entry expansion + meaning + grounding artifact; CLAUDE.md `## Glossary` pointer carries the same-commit maintenance rule | 2026-08-05 | d63293d2 | [260805-ghb-domain-glossary](./quick/260805-ghb-domain-glossary/) |

### Blockers/Concerns

- Phase 7 (Approvals) needs the zod contract designed against `apps/mobile/design/figma-cache/select-app/` specs — no Figma MCP/API access, cache is source of truth.
- Milestone 2 (INTG-01/02, backend approvals) is blocked externally — backend work not yet defined; out of scope for milestone 1 execution.
- Backend commerce e2e suites (payment, orderTransaction, pwg-transaction, userTransaction) are pre-existing failures unrelated to auth - candidates for deletion alongside commerce retirement, logged in .planning/phases/05-onboarding-rebuild/deferred-items.md
- Phase 11 D-08 Operator rename: dev/e2e schema applies via the existing `DB_SYNC`/`synchronize()` convention (unchanged); production schema-apply for this rename has NO migration pipeline (none exists in this repo — confirmed in 11-RESEARCH.md) and is deliberately deferred as pre-existing tech debt, acceptable because nothing is live in production yet per the locked project constraint. A future phase must either stand up a real migration pipeline or run a manual one-off `ALTER TABLE employee RENAME TO operator` (+ FK/constraint/enum-type renames) before any real production data exists in this table.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-08-02T19:50:24.561Z
Stopped at: Phase 10 context gathered
Resume file: .planning/phases/10-delivery-infra/10-CONTEXT.md
Last session: 2026-08-05T08:34:41.834Z
Stopped at: Completed 11-15-PLAN.md — Phase 11 (Catalogs and Import Framework) complete, ready for verification
Resume file: None
Last session: 2026-07-13T18:20:45.051Z
Stopped at: Phase 26 executed — 5/5 plans complete, code review clean, UI review 19/24 + picker loading-state fix applied; verification human_needed (6 device UAT items pending)
Resume file: .planning/phases/26-manual-governorate-city-location-fallback-for-providers-when/26-HUMAN-UAT.md
Last session: 2026-07-13T15:31:01.056Z
Stopped at: Phase 27 executed — 8/8 structural must-haves verified; 17 visual UAT items pending (device testing off)
Resume file: .planning/phases/27-canonical-sheet-component-migrate-all-bottom-sheets-today-ev/27-HUMAN-UAT.md
Last session: 2026-07-11T10:46:45.849Z
Stopped at: Phase 8 closed: human UAT passed on develop (4/4), verification passed
Resume file: .planning/phases/08-policy-favourites/08-HUMAN-UAT.md
Last session: 2026-07-11T09:17:18.332Z
Stopped at: Phase 7 UI-SPEC approved
Resume file: .planning/phases/07-approvals-domain-mock-first/07-UI-SPEC.md
Last session: 2026-07-04T17:12:45.880Z
Stopped at: Phase 9 UI-SPEC approved
Resume file: .planning/phases/09-web-foundation/09-UI-SPEC.md
Last session: 2026-07-05T19:45:08.758Z
Stopped at: Completed 05-03-PLAN.md
Resume file: None
