# Plan: spend the Max plan's monthly API credit on side jobs (0.6.0)

Status: **draft, not built**. Written 2026-10-25. Needs review before any code.

## Problem

Since 2026-10-07 a Claude Max plan comes with monthly API credit: $100 on
Max 5x, $200 on Max 20x. The credit pays for the Claude API, `claude -p`,
the Agent SDK and Managed Agents. It does **not** pay for interactive Claude
Code sessions. Unused credit is lost at the end of each billing cycle. It is
claimed by linking a Claude Console organization to the plan.
(Source: support.claude.com, "Use the Claude Agent SDK with your Claude plan".)

Today the toolkit spends nothing from that pool. Two pains it could fix:

1. **The plan review waits on Codex.** When Codex hits its usage limit, the
   flow stops until `gsd-codex-wait` sees the reset, which can take hours.
2. **The code review eats the session's Max limit.** `/gsd-code-review` runs
   the `gsd-code-reviewer` agent inside the interactive session, and every
   phase pays for it from the same 5-hour window as the real building.

A third, smaller one: `gsd-finish --pr` opens every PR with an empty body
(`bin/gsd-finish:202`).

## Goals and non-goals

Goals: move these jobs onto the credit, **each one switched on and off on its
own**; never let the credit run out by surprise; never weaken a gate; change
nothing when the switch is off (the default).

Non-goals: the security gate (`/gsd-secure-phase` must dig through the code
to check each threat, which is agent work and would burn the credit fast);
running whole phases headless; agent loops of any kind (every job here is
**one** API call); reading the real credit balance (the toolkit only keeps its
own estimate, see "Spend").

## Budget reality

$100 a month is small at Opus prices. Rough costs per job. These are **guesses,
to be replaced by the dry-run numbers from one real phase** before release:

| Job | Input | Output | Sonnet 5.5 ($2/$10 per MTok) | Opus 5.5 ($4/$20) |
|---|---|---|---|---|
| Plan review (plans + CONTEXT + REQUIREMENTS) | ~40k | ~8k | ~$0.16 | ~$0.32 |
| Code review (diff + changed files) | ~120k | ~12k | ~$0.36 | ~$0.72 |
| PR body / ticket comment (Haiku 5.5, $0.10/$0.50) | ~10k | ~1k | — | — (Haiku: < $0.01) |

At ~$0.50 a phase for both reviews on Sonnet, $100 covers a lot of phases.
An agent-style Opus review (many turns, reading files) would be $2–5 each.
That is why every job is one call, and why the default model is Sonnet.

## Settings (`.gsd.conf`)

```
api_credit            = off        # main switch. off = none of this exists
api_plan_review       = fallback   # off | fallback | always
api_code_review       = off        # off | on
api_small_jobs        = off        # off | on   (PR body, ticket comment)

api_plan_review_model  = claude-sonnet-5-5
api_plan_review_effort = medium     # low | medium | high | xhigh | max
api_code_review_model  = claude-sonnet-5-5
api_code_review_effort = high
api_small_jobs_model   = claude-haiku-5-5
api_small_jobs_effort  = low

api_month_cap  = 80      # dollars, toolkit estimate; stop before the credit is gone
api_cycle_day  = 1       # day of the month the billing cycle starts (resets the cap)
api_profile    =         # optional: ~/.config/gsd/anthropic-<profile>.env (like tracker_profile)
```

- `api_credit = off` wins over every other `api_*` key.
- `fallback` = use the API only when Codex is limited (see "Plan review").
  It is the default because Claude checking plans that Claude wrote is less
  independent than Codex checking them.
- A model value is checked against the toolkit's price table. Unknown model →
  `gsd-api` refuses (exit 64) and doctor reports it. Reason: the cap can't be
  kept for a model with no price.
- An effort value outside the five levels → refused, same as a bad model.

The key lives in `~/.config/gsd/anthropic.env` (or the `api_profile` file),
mode 600, holding `ANTHROPIC_API_KEY=…`. It must be a key from the Console org
linked to the Max plan, or the calls bill a card instead of the credit. Doctor
can't tell which org a key belongs to; the docs and `gsd-api setup` say so.

## Design

### One new command: `gsd-api`

```
gsd-api review-plan <N> [--dry-run]
gsd-api review-code <N> [--dry-run]
gsd-api pr-body     <N>                 # prints the body; used by gsd-finish --pr
gsd-api ticket-note <N>                 # prints the comment; used by gsd-tracker finish
gsd-api spend [--json]                  # this cycle's estimate vs the cap
gsd-api setup                           # writes the key file (asks, never echoes the key)
```

- Shell front end in `bin/gsd-api`; the HTTP call, JSON handling, price table
  and ledger live in a new `lib/gsd_api.py` (stdlib only: `urllib`, `json`).
  Target machines have Python 3.7+, not the Anthropic SDK, and the toolkit
  already depends on Python. No `curl | jq` (jq is optional here).
- One `POST /v1/messages` per job. Structured output
  (`output_config.format` with a JSON schema) so the reply is findings data,
  and the toolkit renders the Markdown itself. A reply that does not parse,
  or stops on `max_tokens` / `refusal`, is a failed job (see "Fail safe").
- `--dry-run` calls the free token-count endpoint and prints tokens + the
  estimated cost. It spends nothing and writes nothing.
- Prompts live in `lib/api-prompts/<job>.md`, one file per job, so they can be
  read and reviewed like code.

### Plan review

Output: `<P>-REVIEWS.md` in gsd-core's format: frontmatter
`reviewers: [claude-api]`, one `## Claude API Review` section. That passes
`gsd_reviews_problem` (a section with a real body), and
`/gsd-plan-phase --reviews` reads it like any other review.

Input: every `<P>-*-PLAN.md`, `<P>-CONTEXT.md`, `<P>-RESEARCH.md` if present,
`.planning/REQUIREMENTS.md`, the phase's ROADMAP entry. Over the size cap
(see "Limits") → refuse, never cut.

Flow wiring (`gsd-flow-next`, review step):

| `api_plan_review` | Codex state | Step shows |
|---|---|---|
| `off` | any | today's text, unchanged |
| `fallback` | not limited | today's text, unchanged |
| `fallback` | limited (`gsd_codex_limit.py` finds a run limited past now, or `rev_bad` names a limit) | `gsd-api review-plan N` first, `gsd-codex-wait` as the second choice |
| `always` | any | `gsd-api review-plan N` |

The guard needs no change: it already accepts any `REVIEWS.md` that
`gsd_reviews_problem` passes.

### Code review

Output: `<P>-REVIEW.md` in the `gsd-code-reviewer` schema (frontmatter
`phase`, `reviewed`, `depth`, `files_reviewed`, `files_reviewed_list`,
`findings`, `status: clean | issues_found`; sections Summary / Critical
Issues / Warnings / Info), so `/gsd-code-review N --fix` reads it unchanged.
The **fix** stays in the session; only the finding moves to the credit.

Input: `git diff <base>...<phase branch> -- . ':!.planning'` plus the full
text of each changed file. Over the size cap → refuse, never cut; the flow
then shows the normal `/gsd-code-review N`.

The catch: `/gsd-execute-phase` runs its own code review when gsd-core's
`workflow.code_review` is true, so both would run and both would cost.
Rules:

- `api_code_review = on` only takes effect when `workflow.code_review` is
  `false` in `.planning/config.json`. Otherwise `gsd-api review-code` still
  works by hand, but the flow keeps today's text and doctor warns (T092).
- The toolkit never edits `.planning/config.json` by itself. Doctor names the
  fix: `/gsd-settings`, or `gsd_run config-set workflow.code_review false`.
- With both set, the flow's code-review step (`bin/gsd-flow-next:237`) shows
  `gsd-api review-code N`, and its note drops "execute-phase normally
  produces this".

### Small jobs (Haiku)

- `gsd-finish --pr`: with `api_small_jobs = on`, the body comes from
  `gsd-api pr-body N` (the phase goal, the SUMMARY files, the REVIEW status).
  Any failure → today's empty body. The PR is never held up by it.
- `gsd-tracker finish`: same, for the ticket comment. Tracker calls are
  already best-effort; this keeps that.
- Both get a 30-second time limit.

### Spend

- Every call appends one line to `~/.local/state/gsd/api-spend.tsv`:
  time, repo, phase, job, model, input / cache / output tokens, dollars.
  Per user, not per repo: the credit belongs to the account. Writes take a
  lock (`mkdir` lock, same idea as the checkout lock) because phases run in
  parallel.
- Dollars come from `response.usage` × the price table in `lib/gsd_api.py`.
  It is the toolkit's own estimate. The real balance is in the Console;
  `gsd-api spend` says so.
- **Before** each call: the estimate (free token count + `max_tokens` worst
  case) is added to this cycle's total. Over `api_month_cap` → the job is
  refused and the normal path runs. The cap counts from `api_cycle_day`.

### Fail safe

The one rule: **an API job either produces a complete, valid file or produces
nothing.** Then the flow shows today's normal path.

- No key, a 4xx/5xx, a timeout, a parse failure, `max_tokens`, `refusal`, the cap:
  print one line saying why, write no file, exit non-zero.
- Write to a temp file and `mv` into place only after it is rendered.
- A failed job never leaves an older `REVIEWS.md` / `REVIEW.md` looking fresh.
  It never touches an existing one.
- Never "passed" for "not run". Same rule as the UI check.

### Doctor

| Code | Finding |
|---|---|
| T090 | `api_credit = on` but no key file, or the key file is not mode 600 |
| T091 | bad `api_*` value (unknown model, bad effort, cap not a number) |
| T092 | `api_code_review = on` while `workflow.code_review` is true (double review) |
| T093 | note: this cycle's estimate is over 80% of `api_month_cap` |

Read-only, like the rest. No new `--fix` action: the key is a secret, and
`workflow.code_review` belongs to gsd-core.

## Limits

- Input cap per call: 400k tokens (well under the 1M context, to keep a call
  under ~$1 on Sonnet). Over it → refuse.
- `max_tokens`: 16k reviews, 2k small jobs.
- Streaming is not needed at these sizes; a 10-minute HTTP timeout.

## Docs and tests

- Docs: `docs/providers.md` (keys), `docs/features.md`, README, a short
  "Using the Max API credit" section with the Console linking step.
- New suite `tests/test-api.sh`, using a stub HTTP server (the same idea as the
  curl stubs in `test-tracker.sh` / `test-update.sh`), never the real API:
  each switch off → no call and no change; the REVIEWS.md / REVIEW.md format
  passes `gsd_reviews_problem` and matches the reviewer schema; the cap refuses;
  every failure path writes nothing; the ledger under parallel writers;
  `api_cycle_day` roll-over; the flow text for each row of the table above.
- `tests/test-e2e.sh` after the flow change (CLAUDE.md rule).
- Add the suite to `.github/workflows/tests.yml` and the README test list.

## Build order

1. `lib/gsd_api.py` + `bin/gsd-api` (`spend`, `setup`, `--dry-run`) + ledger + cap.
2. Plan review + the flow's review step. **Measure one real phase with
   `--dry-run`, then for real, and fix the cost table above.**
3. Code review + T092.
4. Small jobs.
5. Doctor T090–T093, docs, release 0.6.0.

## Open questions

1. Does `claude -p` signed in with the Max plan draw from the credit or the
   5-hour limit? The support page says both are possible. This plan avoids the
   question by calling the API with a Console key. Check once by hand.
2. Plan review `always`: should doctor warn that Claude is reviewing its own
   plans when `providers` is Claude only?
3. Batch API (half price, slow): worth adding later for code review on phases
   no one is waiting on? Left out of 0.6.0.
