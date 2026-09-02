---
name: gsd-flow
description: "Drive ONE GSD phase through the agreed phase order, resumably: story → discuss → ui-phase (if screens) → plan → codex review + replan → execute → verify-work → code-review fix → ui-review → secure-phase → gsd-finish. Use when asked to run, drive, continue or resume a phase end-to-end, or 'what is the next step for phase N'. Runs inside the phase's worktree; each step is a normal /gsd-* Skill call, so the guard and the pre-merge gate still apply. `--dry-run` only prints the remaining steps."
---

# gsd-flow — one phase, in order, resumable

`/gsd-flow <N> [--dry-run] [--ui|--no-ui]`

You are the driver, not the worker: each step is the existing `/gsd-*` skill,
invoked through `Skill()`. Your job is to run them **in order**, **stop at the
three human decision points**, and never skip a step because it looks done.
The order comes from `gsd-flow-next`, which reads the phase folder — so the
same command resumes a half-finished phase after a crash or a `/clear`.

## Preconditions (check, do not assume)

1. You are inside the phase worktree: `git branch --show-current` is
   `phase-<N>-*`. If not, stop and relay `gsd-start -p <N>` to the user —
   never do phase work from the main checkout.
2. `command -v gsd-flow-next` exists (toolkit installed). If not: `gsd-sync`.

## The loop

```
Bash: gsd-flow-next <N> [--ui|--no-ui]
```

Read `step=`, `run=`, `then=`, `stop=`, `note=`. Then:

| step | what you do |
|---|---|
| `story` | Create the ClickUp story (product words, no tech; see the repo's CLAUDE.md / memory for the list). Write `<P>-STORY.md` as a snapshot. **Stop** if you need the user's intent. |
| `discuss` | `Skill(skill="gsd-discuss-phase", args="<N>")` — live, the user answers. Afterwards **update the ClickUp story** to the agreed scope (the `then=` line). |
| `ui-decision` | Ask the user once: does this phase have screens? Re-run `gsd-flow-next` with `--ui` or `--no-ui` and keep passing that flag for the rest of this session. |
| `ui-phase` | `Skill(skill="gsd-ui-phase", args="<N>")`. **Stop**: the user agrees the screens before planning. |
| `plan` | `Skill(skill="gsd-plan-phase", args="<N>")`. |
| `review` | `Skill(skill="gsd-review", args="--phase <N> --codex")`. **Stop**: show the codex findings, each one checked against the plans (never accepted on trust). Then, in the same turn, `Skill(skill="gsd-plan-phase", args="<N> --reviews")`. |
| `replan` | REVIEWS.md exists but no plan was committed after it — the `--reviews` replan did not happen. `Skill(skill="gsd-plan-phase", args="<N> --reviews")`. |
| `verifier` | Every plan has a SUMMARY but there is no VERIFICATION.md (the verifier errored). `Skill(skill="gsd-execute-phase", args="<N>")` — with all plans complete it only runs the verifier. |
| `execute` | `Skill(skill="gsd-execute-phase", args="<N>")`. It runs code review and the verifier itself. |
| `gaps` | `Skill(skill="gsd-plan-phase", args="<N> --gaps")` then `Skill(skill="gsd-execute-phase", args="<N> --gaps-only")`. |
| `verify-work` | `Skill(skill="gsd-verify-work", args="<N>")` — agent-driven (Playwright, screenshots), recorded as agent-verified. |
| `code-review` | `Skill(skill="gsd-code-review", args="<N> --fix")` (or without `--fix` if REVIEW.md is missing). |
| `ui-review` | `Skill(skill="gsd-ui-review", args="<N>")`. |
| `secure` | `Skill(skill="gsd-secure-phase", args="<N>")` — the LAST code gate, after every fix has landed. |
| `done` | Print the finish line. Do **not** run `gsd-finish` unless the user says so: it deletes the directory this session stands in and must be the session's last action. |

After every step: run `gsd-flow-next` again. Loop until `step=done`.

## Stops (exactly these, no others)

1. discuss — the user answers the questions.
2. ui-phase — the user agrees the screens.
3. review — the user sees the codex findings before the replan.

A `stop=` line on any other step means "surface it to the user", not "wait".

## `--dry-run`

```
Bash: gsd-flow-next <N> --all [--ui|--no-ui]
```

Print the remaining steps as a numbered list, one line each, and stop. Run
nothing. This is the safe way to answer "what is left on phase N".

## Rules

- If the guard blocks a step (`BLOCKED (flow = strict)…`), the folder and the
  engine disagree — run `gsd-flow-next` again and do what IT says. Never
  `GSD_SKIP_GUARD=1` unless the user asks.
- Never auto-answer discuss questions. This is the one thing that makes this
  skill different from `/gsd-autonomous`.
- One phase per session. For the next phase the user opens a new worktree
  session via `gsd-start`.
