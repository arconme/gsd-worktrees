# Roadmap: Select (medyour-platform)

## Overview

Milestone 1 takes the existing medyour Expo app and pivots it, in place, to the
"Select" TPA design: a shared component foundation unlocks every re-skinned screen,
a 5-tab navigation shell (Home Â· Approvals Â· Policy Â· Favourites Â· More) replaces
the drawer, dead commerce code is deleted early while nothing is live, and three
independent UI rebuilds (Home, Onboarding, Providers) proceed off that foundation.
The net-new Approvals domain is built mock-first against a zod contract in
`@medyour/shared`, and Policy + Favourites close the milestone once their scope is
decided. Milestone 1 ships UI/UX complete on mock data; the real approvals backend
(Milestone 2, v2 requirements) integrates against the same contract afterward.

Source: ClickUp epic `869dyxt8d` (workspace `9012907554`), 9 stories. Design source
of truth: `apps/mobile/design/figma-cache/select-app/` (specs + 50 frame renders) â
not the Figma MCP/API.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Shared components foundation** - Finish the Select-design component library (SearchBar, TaskBarMenu, Tabs, Small_button/More-link) (gap closure in progress â 01-VERIFICATION.md found 2 gaps, see 01-04-PLAN.md) (completed 2026-07-03)
- [x] **Phase 2: Navigation shell** - Replace the drawer with the 5-tab bar + More hub (gap closure in progress â 02-VERIFICATION.md found 4 gaps, see 02-04/02-05-PLAN.md) (completed 2026-07-03)
- [x] **Phase 3: Retire commerce** - Delete cart/plans/points/referrals/invitations/balance/commerce-orders and their guard references (completed 2026-07-04)
- [x] **Phase 4: Home rebuild** - Complete Home to the Select design (notification states, scroll states, dark mode, TaskBarMenu) (completed 2026-07-05)
- [x] **Phase 5: Onboarding rebuild** - Rebuild welcome carousel, splash, sign-in + OTP UI over the unchanged auth engine (completed 2026-07-10)
- [x] **Phase 6: Providers flow** - Re-skin provider list/details, Switch User, Quick Services over existing APIs (completed 2026-07-11)
- [x] **Phase 7: Approvals domain (mock-first)** - Net-new approvals domain: shared zod contract, mock repository, all approvals screens (completed 2026-07-11)
- [x] **Phase 8: Policy + Favourites** - Scope and build the Policy (insurance card) and Favourites tabs (completed 2026-07-11)

**Parallelization note:** Phases 4 (Home), 5 (Onboarding), and 6 (Providers) are
independent of each other â each depends only on Phase 1 + Phase 2 and can be
executed in any order, or in parallel, once those two land.

**Milestone 2 â TPA platform (Select Phase 1).** Phases 9â25 build the TPA system
(scope: `docs/medyour-scope-and-milestones.html`; business milestones M1âM6, kickoff
15 Jun 2026 â completion mid-Dec 2026; go-live only after all milestones). The TPA
track leads (M1, due w/c 31 Aug, needs 9â13); mobile phases 4â6 run in parallel
opportunistically; mobile 7â8 deliberately wait until Phase 15 locks the approval
schema so the zod contract is real-schema-driven. Design source:
`design/figma-cache/provider-portal/INDEX.md`; decisions in memory `tpa-phase1-decisions`.

- [x] **Phase 9: Web foundation** - apps/web Vite SPA (TanStack Router/Query, shadcn, ar/en+RTL), Employee login, role-scoped shell (M1) (completed 2026-07-05)
- [x] **Phase 10: Delivery infra** - GitHub Actions CI, staging environment, resettable demo-seed dataset (M1) (completed 2026-08-03)
- [ ] **Phase 11: Catalogs and import framework** - ICD-10 + canonical service catalogs, Excel-import engine with validation-report UI (M1)
- [ ] **Phase 10: Delivery infra** - GitHub Actions CI, staging environment, resettable demo-seed dataset (M1)
- [x] **Phase 11: Catalogs and import framework** - ICD-10 + canonical service catalogs, Excel-import engine with validation-report UI (M1) (completed 2026-08-05)
- [ ] **Phase 12: Provider onboarding** - provider/branch model, contracts, effective-dated price lists, provider-itemâcanonical mapping (M1)
- [ ] **Phase 13: Client and plan setup (TOB)** - funder/client/policy, plan tiers, TOB benefit-rule schema, multi-level benefit pools, effective-dated TOB versions (M1)
- [ ] **Phase 13.1: Member and network onboarding** - members + families, bulk import, join/leave + old-vs-new flag, plan-to-network mapping with carve-outs (M1)
- [ ] **Phase 14: Consumption ledger** - policy-per-year, pools block/consume/release, append-only ledger + audit foundation (M2)
- [ ] **Phase 15: Approval engine** - config-driven rules, partial approvals, auto-approve thresholds, scenario test library (M2)
- [ ] **Phase 16: Manual review queue and notifications** - review UI, more-info/resubmission loop, in-app+email+push (M2)
- [ ] **Phase 17: Staff intake tool** - staff request intake for all channels, attachments, approval letters + codes/QR (M3)
- [ ] **Phase 18: Pilot configuration** - pilot client + providers loaded via imports, end-to-end dry run (M3)
- [ ] **Phase 19: Provider portal requests and approvals** - member search, insurance panel, request submission, status views incl. partial/resubmission, notifications page (M4)
- [ ] **Phase 20: Verify and dispense** - code/QR verification, OTP patient validation, dispenseâledger consume (M4)
- [ ] **Phase 21: Branch self-service and admin queue** - provider-admin branch requests + admin approval queue (M4)
- [ ] **Phase 22: Member app API integration** - backend serves phase-7 zod contract; mobile mock swapped for real API (M5)
- [ ] **Phase 23: Employer portal** - HR member management against policies, consumption views (M5)
- [ ] **Phase 24: Claims adjudication and provider claims views** - claims from dispensed services, service-date pricing, claims register + claim details (M6)
- [ ] **Phase 25: Claim batches and settlement exports** - batches, monthly closure per funder, corrections, settlement-ready exports â business Phase 1 complete (M6)

**Post-v1 mobile consolidation.** Phases 26-28 were claimed after Milestone 1 closed.
They are mobile-only polish/consolidation work, independent of the TPA track.

- [x] **Phase 26: Manual governorate/city location fallback** - governorate/city picker + city-filtered Providers mode when GPS is unavailable (completed 2026-07-13; 6 device-UAT items still pending)
- [x] **Phase 27: Canonical Sheet component** - one `Sheet` primitive; migrate all ~20 bottom sheets, retire AppBottomSheet/AppModal (completed 2026-07-13; 17 visual-UAT items still pending)
- [ ] **Phase 28: Canonical card treatment** - unify all cards on the DiagonalSurface/cardRadius shell, fold AppCard+ListCard in (IN PROGRESS - 6/7 plans; artifacts on branch `phase-28-canonical-card-treatment-...`)

## Phase Details

### Phase 1: Shared components foundation

**Goal**: The Select-design component library is complete enough that every later screen rebuild can consume it without inventing one-off UI.
**Depends on**: Nothing (first phase)
**ClickUp**: epic `869dyxt8d`, story `869dyxtcy` ("Finish shared components")
**Requirements**: COMP-01, COMP-02, COMP-03, COMP-04
**Success Criteria** (what must be TRUE):

  1. SearchBar is re-skinned to the Select design and used consistently across the screens that need it
  2. TaskBarMenu (quick-action grid) renders and is reusable across Home, Switch User, Quick Services, and More
  3. The generalized Tabs component supports both segmented and filter variants
  4. Small_button and More-link primitives exist, are token-driven, and are available for downstream screens

**Plans**: 4 plans
Plans:
**Wave 1**

- [x] 01-01-PLAN.md â Foundation: radii.xs token + i18n keys (common.moreLink.label, common.searchBar.noResults)
- [x] 01-02-PLAN.md â Correct existing primitives: SearchBar re-skin, TaskBarMenu activeKey/sizing, Tabs variant/typography

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-03-PLAN.md â New primitives: SmallButton, MoreLink

**Gap closure** *(from 01-VERIFICATION.md, blocked on 01-02 completion)*

- [x] 01-04-PLAN.md â Fix TaskBarMenu color contract + press feedback (COMP-02), Tabs filter-badge position + clipping (COMP-03)

**UI hint**: yes

### Phase 2: Navigation shell

**Goal**: Members navigate the app through the Select 5-tab bar instead of the drawer.
**Depends on**: Phase 1
**ClickUp**: epic `869dyxt8d`, story `869dyxtjq` ("Navigation shell â 5-tab bar + More hub")
**Requirements**: NAV-01, NAV-02, NAV-03
**Success Criteria** (what must be TRUE):

  1. Member navigates via a 5-tab bottom bar (Home Â· Approvals Â· Policy Â· Favourites Â· More); the drawer is removed
  2. Member opens the More tab and sees the hub screen (frame 21: TaskBarMenu + settings list)
  3. Member can open the Policy and Favourites tabs and see stub screens without errors, pending their scope (Phase 8)

**Plans**: 5 plans
Plans:
**Wave 1**

- [x] 02-01-PLAN.md â Foundation: i18n (tabs/more/comingSoon keys, drawer.* retired), tab-bar icons, guest-guard allow-list, ComingSoonStub component

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md â SelectTabBar (custom 5-item tab bar, frame 09) + MoreSheet (bottom-sheet hub, frame 21)

**Wave 3** *(blocked on Wave 1 + Wave 2 completion)*

- [x] 02-03-PLAN.md â Route restructure: Drawer â Stack + nested (tabs), home move, Policy/Favourites/Approvals stub screens, Support entry via Profile (D-10)

**Gap closure** *(from 02-VERIFICATION.md, blocked on 02-01/02-02/02-03 completion)*

- [x] 02-04-PLAN.md â Fix SelectTabBar RTL notch (CR-01), HeaderBack Drawer-fallback crash (WR-01), MoreSheet dismiss-before-navigate (CR-02) + RTL card digits (WR-02)
- [x] 02-05-PLAN.md â Human checkpoint: re-verify RTL notch/digits, More-sheet navigation, and deep-link crash fix on-device

**UI hint**: yes

### Phase 3: Retire commerce

**Goal**: Commerce/subscription code is fully removed from the app, and nothing else breaks as a result.
**Depends on**: Phase 2
**ClickUp**: epic `869dyxt8d`, story `869dyxtv5` ("Retire commerce")
**Requirements**: RETIRE-01, RETIRE-02
**Success Criteria** (what must be TRUE):

  1. `cart/`, `(plans)` group + `(app)/plans`, `points/`, `referrals/`, `invitations/`, `balance/`, and commerce `orders/` routes/screens no longer exist
  2. No remaining drawer entries, stores, or models reference the deleted commerce areas
  3. Sign-in â main app flow works end to end with no dead-guard redirects to removed routes (auth/plan guard logic stays consistent)

**Plans**: 13 plans (numbering skips 03-12)
Plans:
**Wave 1**

- [x] 03-01-PLAN.md â Wave 0 validation infra: react-native-mmkv jest mock + guards.test.ts (RED against current guards.ts)
- [x] 03-02-PLAN.md â De-fang Home & Profile screens (D-09, D-11) + Icons.tsx cleanup
- [x] 03-03-PLAN.md â De-fang sign-up destination (D-05), ProviderActionButton (D-10), Quick Services terminal action
- [x] 03-04-PLAN.md â De-fang providers browsing: delete orphaned section-items.tsx, strip branch-items.tsx (D-10)
- [x] 03-05-PLAN.md â De-fang NotificationsModal, notification.model.ts route map, support/contact.tsx
- [x] 03-06-PLAN.md â De-fang signup.store.ts and user.model.ts (D-08)

**Wave 2** *(blocked on 03-01 completion)*

- [x] 03-07-PLAN.md â Guard rewrite (D-04, D-06, D-07) + layout route de-registration â core RETIRE-02

**Wave 3** *(blocked on Wave 1 + Wave 2 completion)*

- [x] 03-08-PLAN.md â Delete CART cluster (route, store, components, hooks, VisitProviderModal)
- [x] 03-09-PLAN.md â Delete PLANS/SIGNUP cluster (routes, components, models, APIs)
- [x] 03-10-PLAN.md â Delete POINTS/REFERRALS/INVITATIONS + BALANCE clusters
- [x] 03-11-PLAN.md â Delete ORDERS/PAYMENT/OFFERS + misfiled cascades cluster

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 03-13-PLAN.md â Locale key cleanup (en.ts/ar.ts, D-14) + consolidated Images.ts cleanup (single writer for the shared file)

**Wave 5 â Phase gate** *(blocked on Wave 4 completion)*

- [x] 03-14-PLAN.md â Human checkpoint: on-simulator sign-in/guest/tab-nav verification pass

**UI hint**: no

### Phase 4: Home rebuild

**Goal**: The Home screen fully matches the Select design across all its states.
**Depends on**: Phase 1, Phase 2
**ClickUp**: epic `869dyxt8d`, story `869dyxtdz` ("Finish Home rebuild")
**Requirements**: HOME-01, HOME-02, HOME-03, HOME-04
**Success Criteria** (what must be TRUE):

  1. Home renders each notification-state variant matching frames 09-12
  2. Home's scroll states match frames 13-16
  3. Home renders correctly in dark mode (Home_screen-Dark-mode frame)
  4. Home's quick actions are powered by the TaskBarMenu component

**Plans**: 6 plans
Plans:
**Wave 1**

- [x] 04-01-PLAN.md â Foundation: color tokens, useAppTheme hook, SmallButton dangerDeep variant, TaskBarMenu tile variant, tab-bar icon/corner-radius fidelity fixes
- [x] 04-02-PLAN.md â Mock data-access layer (home-alerts-store, useHomeAlerts, useTips) + home.* i18n content

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-03-PLAN.md â AppHeader scroll-driven collapse (D-07) + Our Offers section (D-10)
- [x] 04-04-PLAN.md â AlertCard + HomeCarousel (D-01/D-02/D-03) + dev-harness alert-state toggle

**Wave 3** *(blocked on Wave 1 + Wave 2 completion)*

- [x] 04-05-PLAN.md â Full Home screen composition: delete ProviderTypesRow, dark-aware PromoCard, rebuilt home/index.tsx (dismissAll fix, TaskBarMenu Our Providers row, dark theme, corrected content inset)

**Wave 4 â Phase gate** *(blocked on Wave 3 completion)*

- [x] 04-06-PLAN.md â Human checkpoint: screenshot verification (all 9 frames + dark + RTL + guest), Our Offers real-data check, LogBox regression check

**UI hint**: yes

### Phase 5: Onboarding rebuild

**Goal**: New and returning members experience the redesigned start/sign-in flow while the underlying auth engine is untouched.
**Depends on**: Phase 1, Phase 2
**ClickUp**: epic `869dyxt8d`, story `869dyxtfg` ("Start/onboarding flow rebuild")
**Requirements**: ONBD-01, ONBD-02
**Success Criteria** (what must be TRUE):

  1. Member sees the Select welcome carousel and splash screen matching frames 01-07
  2. Member signs in through the redesigned sign-in + OTP screens and reaches the main app via the unchanged OTP auth engine

**Plans**: 4 plans
Plans:
**Wave 1**

- [x] 05-01-PLAN.md — Backend endpoint (TDD): POST /auth/otp/code (member code → resolve mobile → send OTP) + e2e cases 1-4 + no-mobile seed
- [x] 05-02-PLAN.md — Mobile foundation: memberCode zod validator, sendOtpByCode api call, en/ar onboarding copy, brand tokens + Select splash/hero assets

**Wave 2** *(blocked on 05-01 + 05-02)*

- [x] 05-03-PLAN.md — Redesigned sign-in: rewire useSigninForm (phone→code), new SignInOtpSheet bottom sheet (masked mobile), branded medyour-ID hero (guest/register/country removed)

**Wave 3 — Phase gate** *(blocked on 05-03)*

- [x] 05-04-PLAN.md — Human checkpoint: backend e2e green + native build + screenshot verification (hero/OTP/splash vs Figma) + on-device ID→OTP→Home flow

**UI hint**: yes

### Phase 6: Providers flow

**Goal**: Members browse and act on the provider network through re-skinned screens, reusing existing provider/services/family-member APIs.
**Depends on**: Phase 1, Phase 2
**ClickUp**: epic `869dyxt8d`, story `869dyxth8` ("Providers flow")
**Requirements**: PROV-01, PROV-02, PROV-03, PROV-04
**Success Criteria** (what must be TRUE):

  1. Member browses the redesigned provider list (frames 20, 22, 23, 25, 27 + alt list frame-1-7549)
  2. Member views the redesigned provider details screen (frames 24, 26, Provider-details_1-2698)
  3. Member switches the active family member via the redesigned Switch User screen (frame 17)
  4. Member uses Quick Services over existing services data (frames 18-19)

**Plans**: 10 plans
Plans:
**Wave 1**

- [x] 06-01-PLAN.md — Foundation: active-member-store + mock-card-number helper, colors.json additions, phase-wide i18n keys

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 06-02-PLAN.md — SwitchUserSheet + SwitchUserMemberCard (D-01/D-02/D-03/D-05), retire FamilyMemberSelector analog
- [x] 06-03-PLAN.md — QuickServicesSheet (D-06/D-07/D-08)
- [x] 06-04-PLAN.md — Provider details rebuild (D-13/D-14/D-15) + CallProviderModal re-skin; delete ProviderActionButton/SectionsModal/ProviderSectionsTabs/branch-items
- [x] 06-06-PLAN.md — Suggested Provider hook+card, ProviderCard re-skin, ProvidersListEmpty i18n (D-10, Pitfall 5)
- [x] 06-07-PLAN.md — Speciality drill re-skin + providers-map light re-skin (D-12)

**Wave 3** *(blocked on Wave 1 + Wave 2 completion)*

- [x] 06-05-PLAN.md — Provider list screen: dynamic tabs, search, count badges, Suggested Provider integration (D-09/D-10/D-11)
- [x] 06-08-PLAN.md — Home wiring: active-member-store integration, Switch User/Quick Services sheet mounts, MoreSheet repoint

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 06-09-PLAN.md — Retire family-members + services surfaces (D-05/D-06/D-07 cascade), guards.ts cleanup

**Wave 5 — Phase gate** *(blocked on Wave 4 completion)*

- [x] 06-10-PLAN.md — Full suite + screenshot verification + human checkpoint

**UI hint**: yes

### Phase 7: Approvals domain (mock-first)

**Goal**: The net-new approvals domain exists end to end on mock data, with a fixed wire contract that milestone 2 can swap in against.
**Depends on**: Phase 1, Phase 2
**ClickUp**: epic `869dyxt8d`, story `869dyxtmr` ("Approvals domain â mock-first")
**Requirements**: APPR-01, APPR-02, APPR-03, APPR-04, APPR-05
**Success Criteria** (what must be TRUE):

  1. The approvals wire contract is defined as zod schemas in `@medyour/shared` (status Approved/Partial/Rejected, requested/approved dates, verification code + QR, dispensed services, rating/delay feedback, provider ref), respecting the packages/shared purity rule (pure TS + zod, no decorators/Node-only imports)
  2. A mock approvals repository sits behind the app's existing data-access pattern (hooks/stores), so a future backend swap is implementation-only
  3. Member views the approvals list with status filtering (frames 28, 29, 36, Notification-Approvals_1-3265)
  4. Member views approval details in every status variant, including verification code/QR (frames 30-37)
  5. Member views dispensed/received services and can rate or report a delay via the bottom sheets/overlays (_1-3766, _1-4117 provider call, _1-4330 provider-list sheet, component frame-1-3981)

**Plans**: 14 plans
Plans:
**Wave 1**

- [x] 07-01-PLAN.md — Shared wire contract: zod schemas + enums in @medyour/shared, contract tests (APPR-01)
- [x] 07-02-PLAN.md — approvals.* i18n content pack (en/ar)

**Wave 2** *(blocked on Wave 1)*

- [x] 07-03-PLAN.md — Mock repository: fixtures, scenario store, getApprovals/getApproval/submitFeedback (APPR-02)
- [x] 07-04-PLAN.md — Visual primitives: status color tokens, ApprovalStatusBadge/ApprovalItemChip, ApprovalsHeader, formatEgp

**Wave 3** *(blocked on Wave 2)*

- [x] 07-05-PLAN.md — React Query hooks: useApprovals/useApproval/useSubmitFeedback
- [x] 07-06-PLAN.md — Detail sub-components: VerificationQrCode/VerificationCodeCard, ApprovalItemRow, CommentsBox, DownloadPdfButton
- [x] 07-07-PLAN.md — Details menu + dispensed summary sheets, CoverageBanner
- [x] 07-08-PLAN.md — Provider sheets: ProviderCallSheet, ProviderListSheet

**Wave 4** *(blocked on Wave 3)*

- [x] 07-09-PLAN.md — Home integration (D-08): persisted dismissal store, useHomeAlerts swap, dev scenario switcher
- [x] 07-10-PLAN.md — Approvals list screen: ApprovalCard, route directory conversion (D-09/D-10)
- [x] 07-11-PLAN.md — Feedback flow + Dispensed Services sheet composition

**Wave 5** *(blocked on Wave 4)*

- [x] 07-12-PLAN.md — Approval details screen assembly: status-driven layout, sheet wiring

**Wave 6** *(blocked on Wave 5)*

- [x] 07-13-PLAN.md — Notification integration (D-12): approval notification row + deep link

**Wave 7 — Phase gate** *(blocked on Wave 6)*

- [x] 07-14-PLAN.md — Full suite green + human checkpoint: on-device screenshot verification

**UI hint**: yes

### Phase 8: Policy + Favourites

**Goal**: Members can view their insurance policy card and use the Favourites tab per its agreed scope.
**Depends on**: Phase 2
**ClickUp**: epic `869dyxt8d`, story `869dyxttb` ("Policy + Favourites")
**Requirements**: POL-01, POL-02, POL-03
**Success Criteria** (what must be TRUE):

  1. Policy and Favourites scope is discussed and decided (documented before build starts)
  2. Member views their insurance card on the Policy tab (frame Card_1-3122: rotated full-screen card â name, card number, client, expiry)
  3. Favourites tab delivers the scope agreed in criterion 1

**Plans**: 4 plans
Plans:
**Wave 1**

- [x] 08-01-PLAN.md — Foundations: favourites-store + unit tests (Wave 0), useFavourites/usePolicyCard hooks, heart icons, gradient tokens, i18n keys

**Wave 2** *(blocked on Wave 1)*

- [x] 08-02-PLAN.md — PolicyCard rotated full-screen card + policy-card route + tab trigger + MoreSheet/Home unification (POL-02)
- [x] 08-03-PLAN.md — Heart toggles on provider rows/details + real Favourites tab with empty state (POL-03)

**Wave 3** *(blocked on Wave 2)*

- [x] 08-04-PLAN.md — Phase gate: automated suite + POL-01 artifact check + full simctl protocol (pixel/nav/RTL/dark/persistence/legacy)

**UI hint**: yes

## Future Milestones (v2)

**Milestone 2: Approvals backend** â not part of milestone-1 phase execution; scoped once milestone 1 ships.

- **INTG-01**: Approvals module implemented in `apps/backend` (NestJS/TypeORM) serving the shared zod contract from Phase 7
- **INTG-02**: Mobile mock repository (Phase 7) swapped for the real approvals API â a thin swap since the contract is already fixed

ClickUp: epic `869dyxt8d`, story `869dyxtq9` ("Approvals backend integration") â blocked externally on backend work not yet defined.

## Progress

**Execution Order:**
Milestone 1 (mobile): 1 â 2 â 3 â 4 â 5 â 6 â 7 â 8
(Phases 4, 5, 6 may be reordered or parallelized freely â see parallelization note above.
Phases 7â8 wait for Phase 15's approval schema â see Milestone 2 note.)
Milestone 2 (TPA) critical path: 9 â 11 â 13 â 14 â 15 â 16 â 17 â 18, with 10, 12â¥13,
19/20/21 (M4), 22/23 (M5), 24 â 25 (M6) hanging off it per each phase's Depends on.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Shared components foundation | 4/4 | Complete   | 2026-07-03 |
| 2. Navigation shell | 5/5 | Complete   | 2026-07-03 |
| 3. Retire commerce | 13/13 | Complete   | 2026-07-04 |
| 4. Home rebuild | 6/6 | Complete   | 2026-07-05 |
| 5. Onboarding rebuild | 4/4 | Complete   | 2026-07-10 |
| 6. Providers flow | 10/10 | Complete    | 2026-07-11 |
| 7. Approvals domain (mock-first) | 14/14 | Complete    | 2026-07-11 |
| 8. Policy + Favourites | 4/4 | Complete    | 2026-07-11 |
| 9. Web foundation | 12/12 | Complete   | 2026-07-05 |
| 10. Delivery infra | 8/8 | Complete    | 2026-08-03 |
| 11. Catalogs and import framework | 0/TBD | Not started | - |
| 10. Delivery infra | 0/TBD | Not started | - |
| 11. Catalogs and import framework | 15/15 | Complete    | 2026-08-05 |
| 12. Provider onboarding | 0/TBD | Not started | - |
| 13. Client onboarding | 0/TBD | Not started | - |
| 14. Consumption ledger | 0/TBD | Not started | - |
| 15. Approval engine | 0/TBD | Not started | - |
| 16. Manual review queue and notifications | 0/TBD | Not started | - |
| 17. Staff intake tool | 0/TBD | Not started | - |
| 18. Pilot configuration | 0/TBD | Not started | - |
| 19. Provider portal requests and approvals | 0/TBD | Not started | - |
| 20. Verify and dispense | 0/TBD | Not started | - |
| 21. Branch self-service and admin queue | 0/TBD | Not started | - |
| 22. Member app API integration | 0/TBD | Not started | - |
| 23. Employer portal | 0/TBD | Not started | - |
| 24. Claims adjudication and provider claims views | 0/TBD | Not started | - |
| 25. Claim batches and settlement exports | 0/TBD | Not started | - |
| 26. Manual governorate/city location fallback | 5/5 | Complete (6 UAT pending) | 2026-07-13 |
| 27. Canonical Sheet component | 11/11 | Complete (17 UAT pending) | 2026-07-13 |
| 28. Canonical card treatment | 6/7 | In progress | - |

### Phase 9: Web foundation

**Goal:** apps/web exists as the role-scoped portal shell AND the portal design system every later web phase consumes: design tokens extracted from the Figma cache, the shared chrome, and the recurring primitives — proven on two pixel-checked screens (sign-in, dashboard).
**Requirements**: SC-1..SC-6 (no REQUIREMENTS.md IDs mapped yet for TPA phases; ROADMAP's own numbered success criteria below are used as the traceability IDs for this phase's plans)
**Goal:** apps/web exists as the role-scoped portal shell AND the portal design system every later web phase consumes: design tokens extracted from the Figma cache, the shared chrome, and the recurring primitives â proven on two pixel-checked screens (sign-in, dashboard).
**Requirements**: TBD
**Depends on:** Nothing (parallel with the mobile track)
**Design source**: design/figma-cache/provider-portal/ (INDEX.md; full-res tiles/)
**Success Criteria** (what must be TRUE):

  1. apps/web runs as a Vite SPA (TanStack Router/Query, zod + RHF, Tailwind + shadcn/ui) with ar/en + RTL wired from the first screen
  2. An Employee signs in with email+password (existing PASSWORD grant) and lands in a role-scoped shell (/admin /staff /provider /employer)
  3. Design tokens (teal family, 4 status colors, typography, spacing) are extracted from the provider-portal cache via ui-phase and wired into the Tailwind/shadcn theme
  4. Shared chrome exists: header (language toggle, notification bell, user menu), nav drawer, breadcrumbs, footer â all RTL-aware
  5. Recurring primitives exist and are token-driven: FilterCard, DataTable (pagination + status chips), AppModal, FileUploadChip, EmptyState, form fields, toasts, OTP input
  6. Sign-in (default + error) and the portal dashboard are built with the system and pixel-checked against the Figma cache; later phases extend the UI kit as they meet new components (mobile phase-1 convention)

**Plans:** 12/12 plans complete

Plans:
**Wave 1**

- [x] 09-01-PLAN.md — Workspace scaffold: Vite+React 19+TS, ESLint/Prettier (D-14), Vitest+Playwright harness, full phase-wide dependency install, D-15 dev proxy, font legitimacy checkpoint

**Wave 2** *(blocked on Wave 1)*

- [x] 09-02-PLAN.md — Web-local Role enum in apps/web (D-05 prerequisite, D-17: zero backend/shared touch) + backend-parity test
- [x] 09-03-PLAN.md — Design tokens + Tailwind v4 @theme + shadcn CLI init/skin (D-09, D-12) + font wiring
- [x] 09-04-PLAN.md — api-client.ts: axios instance, D-01 localStorage token persistence, D-02 single-flight 401-refresh queue (TDD)

**Wave 3** *(blocked on Wave 1 + Wave 2)*

- [x] 09-05-PLAN.md — i18next + RTL wiring, all phase-9 locale copy (D-04, D-07 + consolidated keys for later plans)
- [x] 09-06-PLAN.md — auth-store.ts (sign-in/out/session) + route-guards.ts resolveArea (D-05, regression-tested against the clients-field bug)

**Wave 4** *(blocked on Waves 1-3)*

- [x] 09-07-PLAN.md — Shared chrome: Header, NavDrawer, Breadcrumbs, Footer (RTL-aware, D-06 live-entries-only)
- [x] 09-08-PLAN.md — Token-driven primitives: EmptyState, StatusChip, ErrorBanner, FileUploadChip, OtpInput, toast wrapper, AppModal, DataTable, FilterCard (D-12)

**Wave 5** *(blocked on Waves 1-4)*

- [x] 09-09-PLAN.md — TanStack Router wiring, requireArea() guard loader, AreaLayout, /admin /staff /employer landing shells (D-06)

**Wave 6** *(blocked on Wave 5)*

- [x] 09-10-PLAN.md — Sign-in screen: per-area copy (D-07), D-04 distinct error banners, full auth stack wiring — pixel-check target 1
- [x] 09-11-PLAN.md — Provider dashboard: Search By, Recent Activity (D-08 empty state), Quick Actions + coming-soon pages — pixel-check target 2

**Wave 7 — Phase gate** *(blocked on Wave 6)*

- [x] 09-12-PLAN.md — Playwright e2e (sign-in→dashboard smoke), pixel-check pass vs Figma cache, final human checkpoint

### Phase 10: Delivery infra

**Goal:** CI, an always-on staging environment, and a resettable demo-seed dataset exist so every milestone review runs on stable infrastructure.
**Requirements**: D-01..D-16 (10-CONTEXT.md locked decisions — no REQUIREMENTS.md IDs mapped to this infra phase)
**Depends on:** Nothing (parallel with Phase 9)
**Plans:** 8/8 plans complete

Plans:

**Wave 1**

- [x] 10-01-PLAN.md — CI quality gate: typecheck/lint x3/unit x3/e2e-backend/smoke-web (D-09, D-10, D-11, D-12)
- [x] 10-02-PLAN.md — GCP staging backend infra: medyour_staging DB, staging-only admin secrets, medyour-be-staging reconfig, domain mapping (D-01, D-04, D-13)
- [x] 10-03-PLAN.md — Web Firebase Hosting setup: IAM grant, firebase.json/.firebaserc, staging GH environment (D-02, D-03)
- [x] 10-04-PLAN.md — Mobile staging distribution: eas.json staging profile + develop-triggered EAS build (D-08)
- [x] 10-05-PLAN.md — Backend demo-seed code: SeederService extension, run-demo-seed.ts entrypoint, Dockerfile fix, shared demo/e2e credentials (D-14)

**Wave 2** *(blocked on relevant Wave 1 plans)*

- [x] 10-06-PLAN.md — CI-gated staging deploys: deploy-backend-staging + deploy-web-staging jobs in ci.yml (D-05, D-06, D-07)
- [x] 10-07-PLAN.md — Demo-seed reset: medyour-demo-seed Cloud Run Job + reset-staging-demo.yml (D-15, D-16)

**Wave 3 — Phase gate** *(blocked on all Wave 1 + Wave 2 plans)*

- [x] 10-08-PLAN.md — Full end-to-end verification: real develop push, staging URLs reachable, demo reset dispatched, human sign-off on all 4 portal logins + EAS staging build

### Phase 11: Catalogs and import framework

**Goal:** ICD-10 diagnosis and canonical service catalogs are loaded and manageable, and the reusable Excel-import engine with row-level validation reports powers all later onboarding imports.
**Requirements**: 14 ClickUp story scenarios (S1-S14, `11-STORY.md`) + CONTEXT.md decisions D-01..D-08 (no formal REQUIREMENTS.md IDs mapped to TPA phases)
**Depends on:** Phase 9
**Plans:** 15/15 plans complete

Plans:

**Wave 1**

- [x] 11-01-PLAN.md — Employee→Operator rename: entity/module/auth/cart/order-history (D-08, isolated opening plan)
- [x] 11-02-PLAN.md — Web design-system foundation: tokens, StatusBadge rename+extend, ESLint reuse guard, toast reconfig, shadcn select/switch

**Wave 2** *(blocked on Wave 1)*

- [x] 11-03-PLAN.md — Operator rename close-out: Metadata.updatedBy column, web comment touch-ups, BLOCKING schema-push regression
- [x] 11-04-PLAN.md — Web pattern components: DataTable server-pagination extension, PageHeader, EntityDrawer, ConfirmDialog, LocalizedField, AccessDenied

**Wave 3** *(blocked on Wave 2)*

- [x] 11-05-PLAN.md — Categories domain (TDD): entity/service/controller/e2e, shared by both catalogs (D-07)
- [x] 11-06-PLAN.md — Web Sidebar (staff area) + generic useCatalogResource hook

**Wave 4** *(blocked on Wave 3)*

- [x] 11-07-PLAN.md — Diagnoses + Services-catalog domains (TDD): entities, own-code sequence, eligibility metadata, e2e

**Wave 5** *(blocked on Wave 4)*

- [x] 11-08-PLAN.md — Web Diagnoses catalog screen: list + drawer + Categories tab
- [x] 11-10-PLAN.md — Import engine core + diagnoses import-type (TDD): staged upload→validate→commit/cancel→trail

**Wave 6** *(blocked on Wave 5)*

- [x] 11-09-PLAN.md — Web Services catalog screen: list + drawer + Categories tab
- [x] 11-11-PLAN.md — Services import-type registration (TDD): proves the engine generic (D-04), own-code/Seha-alias match key (D-03)

**Wave 7** *(blocked on Wave 6)*

- [x] 11-12-PLAN.md — Web ImportFlow wizard: dropzone→verdict→failed-rows→commit→success, wired into both catalog pages
- [x] 11-14-PLAN.md — Seha-docs conversion script: raw sources → official import templates (D-05)

**Wave 8** *(blocked on Wave 7)*

- [x] 11-13-PLAN.md — Web Imports list page + read-only run-detail view (D-06 trail)

**Wave 9 — Phase gate** *(blocked on Wave 8)*

- [x] 11-15-PLAN.md — Full suite + duplication sweep + 11-HUMAN-UAT.md + human checkpoint

### Phase 12: Provider onboarding

**Goal:** A provider can be onboarded end to end: provider/branch records, contract, effective-dated price-list import, and provider-item-to-canonical-code mapping.
**Requirements**: TBD
**Depends on:** Phase 11
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 12 to break down)

### Phase 13: Client and plan setup (TOB)

**Goal:** A client's insurance programme is recorded faithfully: funder (insurer) and client entities, a policy with period/currency/geographic scope, plan tiers with annual limits and room class, the TOB benefit-rule schema (the closed set of rule shapes), and multi-level benefit pools (member / family / whole-population; money / cases / sessions / days), with effective-dated TOB versions and TOB entry screens.
**Requirements**: TBD — schema evidence base in `.planning/phases/13-client-onboarding/13-TOB-INVENTORY.md` (all 10 real TOBs from `docs/seha-docs/Benefits tables.rar`, 7 insurers)
**Depends on:** Phase 11 (genuinely parallel with Phase 12 — no provider dependency)
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 13 to break down)

### Phase 13.1: Member and network onboarding

**Goal:** Real members and their families are loaded against the plans, and each tier knows which providers it can use: member entity with client membership and tier assignment, families/dependents with relationship and age rules, bulk member import on the Phase 11 import engine, join/leave dates and mid-term joiners with the old-vs-new subscriber flag, and plan-to-network mapping including per-provider carve-outs.
**Requirements**: TBD
**Depends on:** Phase 12 (providers must exist for network mapping) + Phase 13 (tiers must exist for assignment)
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 13.1 to break down)

### Phase 14: Consumption ledger

**Goal:** Every member has a policy-per-year with benefit pools tracked by an append-only ledger (block at approval, consume at dispense, release on expiry) with decision-grade audit.
**Requirements**: TBD — note: pools are multi-level (member / family / whole-population) and countable in money, cases, sessions or days; group-level pools appear in 5 of 10 real policies. See `.planning/phases/13-client-onboarding/13-TOB-INVENTORY.md`.
**Depends on:** Phase 13.1 (needs member records for policy-per-year; 13.1 itself depends on Phase 13's pools)
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 14 to break down)

### Phase 15: Approval engine

**Goal:** The approval engine decides correctly (approve / partial / reject / pend) from config-driven rules and is proven against a scenario test library that includes claims-shaped outcomes.
**Requirements**: TBD
**Depends on:** Phases 12, 14
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 15 to break down)

### Phase 16: Manual review queue and notifications

**Goal:** Approvals staff can review pended requests, request more info, and drive the resubmission loop, with in-app/email/push notifications wired.
**Requirements**: TBD
**Depends on:** Phase 15
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 16 to break down)

### Phase 17: Staff intake tool

**Goal:** Staff can create and track approval requests on behalf of members across all inbound channels, producing approval letters and verification codes/QR.
**Requirements**: TBD
**Depends on:** Phase 16
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 17 to break down)

### Phase 18: Pilot configuration

**Goal:** The pilot client and its providers are fully configured through the import tools and a real end-to-end dry run passes.
**Requirements**: TBD
**Depends on:** Phase 17
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 18 to break down)

### Phase 19: Provider portal requests and approvals

**Goal:** Provider desk users can find a member, see their insurance panel and approvals, and submit approval requests with attachments, including partial-approval and resubmission states plus the notifications page.
**Requirements**: TBD
**Depends on:** Phase 16 (parallel with Phase 17)
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 19 to break down)

### Phase 20: Verify and dispense

**Goal:** Approved services can be dispensed at the provider: code/QR verification, OTP patient validation, and consume-entries written to the ledger.
**Requirements**: TBD
**Depends on:** Phase 19
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 20 to break down)

### Phase 21: Branch self-service and admin queue

**Goal:** Provider admins can request branch add/edit/suspend/close/return-back, and medyour admins can review and approve those requests in a queue.
**Requirements**: TBD
**Depends on:** Phases 12, 19
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 21 to break down)

### Phase 22: Member app API integration

**Goal:** The backend serves the Phase-7 approvals zod contract and the mobile app runs on the real API instead of the mock repository (roadmap INTG-01/02).
**Requirements**: TBD
**Depends on:** Phase 15 + mobile Phase 7
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 22 to break down)

### Phase 23: Employer portal

**Goal:** Client HR can self-manage their members against policies and view consumption through the employer portal.
**Requirements**: TBD
**Depends on:** Phase 14 (parallel with M4 phases)
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 23 to break down)

### Phase 24: Claims adjudication and provider claims views

**Goal:** Dispensed services become adjudicated claims priced by service date, visible to providers via the claims register and claim-details views (invoice upload, return-service, PDF).
**Requirements**: TBD
**Depends on:** Phase 20
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 24 to break down)

### Phase 25: Claim batches and settlement exports

**Goal:** Claims can be grouped into batches, run through monthly closure per funder with corrections, and exported settlement-ready for finance - business Phase 1 complete.
**Requirements**: TBD
**Depends on:** Phase 24
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd-plan-phase 25 to break down)

### Phase 26: Manual governorate/city location fallback for Providers: when GPS is unavailable (location permission denied or services off), let the user pick an Egyptian governorate and city and show branches filtered by that city. Add a public cities-by-governorate endpoint, a governorate/city picker (reusing existing SelectField/SelectInput sheets), persist the selection in the location store, and switch the Providers list between nearby (GPS) and city-filtered modes; include the open/closed badge in manual mode and a change-location affordance.

**Goal:** When GPS is unavailable on Providers, a member can pick an Egyptian governorate + city and see branches filtered by that city (open-first), re-pick within city mode, and have the pick persist — with GPS silently reclaiming priority when it returns.
**Requirements**: D-01..D-09 (CONTEXT decisions; no formal REQ IDs mapped)
**Depends on:** Phase 6 Providers flow (complete)
**Plans:** 5/5 plans complete

Plans:

**Wave 1**

- [x] 26-01-PLAN.md — Backend cities-by-governorate endpoint (role-gated, e2e) [wave 1]
- [x] 26-02-PLAN.md — Mobile core: persisted manualLocation + mode selector + pure builders (params/open-first sort) [wave 1]
- [x] 26-05-PLAN.md — Seed-data ops: load Egyptian governorate/city rows into target DB (non-feature) [wave 1]

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 26-03-PLAN.md — Providers city-mode wiring (params branch, gate relax, open-first, distance guard) [wave 2]

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 26-04-PLAN.md — Fallback banner + two-step picker + change-city + locale (en/ar) [wave 3]

### Phase 27: Canonical Sheet component + migrate all bottom sheets

**Goal:** Every bottom sheet today builds its own header/padding/separator on top of THREE divergent foundations — `AppModal` (BottomSheetModal, `ModalHeader` + paddingTop:10), `AppBottomSheet` (BottomSheet, inline header + paddingBottom:5 + its own padding model), and ~5 sheets on raw `BottomSheetModal`/`BottomSheet` with fully hand-rolled chrome. Separators are ad-hoc across 5 components (`ListLineSeparator`/`ListSeparator`/`Separator`/`DottedSeparator`). The visual chrome is already unified via `ModalBackground` (E0FDFF→FFF gradient, rounded top-left only, drag handle hidden) — keep it.

Build ONE canonical `Sheet` on `BottomSheetModal` that owns all shared chrome in a single place:

- `SheetHeader` (title + close, one spacing)
- `horizontalPadding` applied to content ONCE and correctly — fixes the class of bug where `BottomSheetFlatList` rows escape the wrapper padding (the CallProviderModal row-padding fix in quick task 260713-iyx was a symptom)
- a canonical `Sheet.Separator`
- a `Sheet.List` helper wrapping `BottomSheetFlatList` with standard row padding + separator so list-sheets stop re-inventing it
- Loader/backdrop/safe-area/handle inherited as overridable defaults

Then migrate ALL ~20 sheets onto it (approvals/* sheets, Otp sheets, ConfirmModal, DeleteAccount, Notifications, SearchModal, GuestAccessGuard, CountryNotSupported, CallProviderModal, ProvidersMapModal, QuickServicesSheet, SwitchUserSheet, MoreSheet, DeleteConfirmationBottomSheet, ProfileImageEditor, DatePicker/Select field+input sheets) and retire `AppBottomSheet` + the raw-BottomSheet usages. Each migrated sheet must be screenshot-verified against its current look (no visual regression). Mobile app only (`apps/mobile`); strict tsconfig + eslint (nullish/optional-chain/type-imports).

**Requirements**: D-01..D-08 (27-CONTEXT.md locked decisions — no REQUIREMENTS.md IDs map to this post-v1 consolidation phase)
**Depends on:** Phase 26
**Plans:** 11/11 plans complete

Plans:

**Wave 1**

- [x] 27-01-PLAN.md — Canonical Sheet core module: Sheet.tsx, SheetHeader.tsx, SheetSeparator.tsx, SheetList.tsx, compound barrel + 2 Wave-0 unit tests (D-01, D-04)

**Wave 2** *(blocked on Wave 1 completion; all 8 plans below are file-disjoint and run in parallel)*

- [x] 27-02-PLAN.md — AppModal cluster A: CallProviderModal (Sheet.List reference case), GuestAccessGuardModal, SearchModal
- [x] 27-03-PLAN.md — AppModal cluster B: NotificationsModal, DatePicker (iOS), ConfigurationsModal
- [x] 27-04-PLAN.md — AppModal stragglers found during source audit: confirm-data.tsx (live), sign-in/otp.tsx, NetworkStatus.tsx, AuthMobileInput.tsx (both dead code)
- [x] 27-05-PLAN.md — Settings + notifications ConfirmModal cluster: ConfirmModal, DeleteAccountModal, settings/index.tsx, settings/account.tsx, notifications/index.tsx (fixes raw .expand() Pitfall 1)
- [x] 27-06-PLAN.md — Misc AppBottomSheet cluster: CountryNotSupportedModal (fixes last raw .expand()), ProfileImageEditorModal + profile-details.tsx
- [x] 27-07-PLAN.md — OTP cluster: OtpModal + sign-up.tsx, SignInOtpSheet + useSigninForm.ts
- [x] 27-08-PLAN.md — Drifted sheets (D-02/D-03/D-04): MoreSheet, QuickServicesSheet (enableDynamicSizing preserved), SwitchUserSheet — gradient chrome replaces flat/dark backgrounds
- [x] 27-09-PLAN.md — D-07 SelectSheet extraction: new SelectSheet.tsx + SelectInput.tsx/SelectField.tsx thin wrappers, retires BsBackDrop

**Wave 3** *(blocked on Wave 1 + 27-05 completion — DispensedServicesSheet nests the already-migrated ConfirmModal)*

- [x] 27-10-PLAN.md — Approvals sheets full cluster: DetailsMenuSheet, DispensedSummarySheet, ProviderCallSheet, ProviderListSheet, DispensedServicesSheet (3 nested refs) + approvals/[id].tsx repoint

**Wave 4 — Phase gate** *(blocked on all Wave 2 + Wave 3 plans)*

- [x] 27-11-PLAN.md — Retirement: delete AppBottomSheet/useAppBottomSheet/useConfirmationModal/AppModal/ModalHeader/BsBackDrop, delete DeleteConfirmationBottomSheet (D-06), D-05 ProvidersMapModal exception comment, full-suite phase gate

**UI hint**: yes

### Phase 28: Canonical card treatment — unify all cards on the DiagonalCard/cardRadius Select shell (fold AppCard+ListCard into DiagonalCard, convert Paper Surface cards to diagonal shell, screenshot-verify each)

**Goal:** Every card in the app renders on one canonical `DiagonalSurface` shell (the DiagonalCard/cardRadius Select treatment) — AppCard and ListCard folded in and deleted, all react-native-paper `Surface` cards converted, each screenshot-verified against the figma-cache.
**Requirements**: D-01..D-09 (28-CONTEXT.md locked decisions)
**Depends on:** Phase 27
**Plans:** 6/7 plans complete — IN PROGRESS

> Phase artifacts (28-01..28-07 PLAN/CONTEXT/UI-SPEC) live on branch
> `phase-28-canonical-card-treatment-...` until the phase is merged to develop.

Plans:

**Wave 1**

- [x] 28-01-PLAN.md — DiagonalSurface shell primitive + regression test (D-01, D-04)

**Wave 2**

- [x] 28-02-PLAN.md — Rebuild DiagonalCard on DiagonalSurface + API-preservation test (D-02); MoreSheet member card + rows (D-05, D-06)
- [x] 28-03-PLAN.md — Fold AppCard + ListCard into DiagonalSurface, delete both (D-03, D-06)
- [x] 28-04-PLAN.md — Tier-1 cards: Settings / Support / ProfileData (D-05, D-06, D-09)
- [x] 28-05-PLAN.md — ProviderCard + SuggestedProviderCard; ProviderCategoryCard + HomeProviderCategoryCard (D-05, D-06)
- [x] 28-06-PLAN.md — SectionCard, ServicesProviderCard, ProviderMapCard (D-05, D-06, D-07)

**Wave 3 — Phase gate** *(not autonomous — human checkpoint)*

- [ ] 28-07-PLAN.md — Phase gate: full suite + strict typecheck, screenshot-verify all 12 cards, dark-mode preview of theme.colors.light-backed cards

### Phase 29: Repo lint & test debt cleanup — make the CI gate fully green: migrate backend ESLint to flat config and clear its 619 prettier/type errors, configure ts-jest so the 7 never-run backend spec suites execute, clear 48 mobile lint errors, and re-evaluate pinning the e2e PostGIS container to Postgres 17 to match Cloud SQL

**Goal:** Every job in `ci.yml` passes on a push to `develop`, so the phase-10 gate actually blocks bad merges instead of sitting permanently red.

All items below are **pre-existing debt surfaced by phase 10's new CI gate**, each verified as untouched by phase 10 (diffed against `d21347e9`, the pre-merge baseline):

- `lint-backend` — 619 errors (mostly `prettier/prettier`; 129 auto-fixable). `.eslintrc.js` loads again as of phase 10, but ESLint 9 deprecates eslintrc and removes it in v10, so migrate to flat config here.
- `test-backend` — the backend has **no jest config at all**, so `jest` falls back to Babel, cannot parse TypeScript, and all 7 `.spec.ts` suites fail with 0 tests run. Needs ts-jest wiring, then triage of whatever those suites surface on their first-ever execution.
- `e2e-backend` — 19 of 30 tests fail (`expected 201, got 400`) across the Payments and Order Transactions suites. Confirmed pre-existing: identical failures reproduce with the pre-phase-10 seed files restored. These cover commerce flows the product is retiring, so decide fix-vs-delete.
- `lint-mobile` — 48 errors, 343 warnings.
- `test-mobile` — 1 failing test (`favourites-store › partialize shape`), dating from phase 08.
- The e2e PostGIS container is pinned to `postgis/postgis:16-3.4` while Cloud SQL runs Postgres 17. `17-3.5` publishes no arm64 build, so this needs a decision: accept the divergence, find an arm64-capable 17 image, or split the local and CI images.

**Requirements**: TBD
**Depends on:** Phase 28
**Plans:** 0 plans

Plans:

- [ ] TBD (run /gsd:plan-phase 29 to break down)
