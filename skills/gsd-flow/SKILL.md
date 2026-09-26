---
name: gsd-flow
description: "Drive one GSD phase through the provider-neutral resumable order. Use when asked to run, continue, or inspect a phase end-to-end. gsd-flow-next is the authoritative state machine and command-level guard."
---

# gsd-flow — one phase, in order, resumable

Start this installed skill through the active provider's supported mechanism.
Claude may use `/gsd-flow <N>`; Codex uses `$gsd-flow` with the phase number
in the request. The shell entrypoint is `gsd-flow-next <N>` for every provider.

You are the driver. Use this agent's real skill invocation mechanism when the
named GSD skill is installed. If it has no direct skill-chaining interface,
follow the `run=` text as a natural-language phase instruction and clearly
print the next step when a capability is unavailable. Never invent a universal
provider-native invocation API. Run steps in order. The planned approval
gates are discussion, the design system and sketch plus screen approval when
the phase has screens, and independent review;
the ticket and the UI/no-UI choice may also need a user answer.
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
| `ticket` | Only when the repo sets a tracker. With `run=`: run that `gsd-tracker snapshot … --out …` command, then commit the file. Without `run=`: the phase has no ticket — ask the user for its id (product words, no tech), then snapshot it. Never invent product intent. |
| `discuss` | Invoke or follow `gsd-discuss-phase <N>` live; the user answers. If `then=` says so, update the ticket to the agreed scope. |
| `ui-decision` | Ask the user once: does this phase have screens? Re-run `gsd-flow-next` with `--ui` or `--no-ui` and keep passing that flag for the rest of this session. |
| `design-system` | Run `gsd-ui design` (creates the stub). Agree the design system with the user — references, tokens, components, page templates — fill `.planning/design/DESIGN.md`, delete its stub line, commit. |
| `layout` | Run `run=` (`gsd-ui layout <N>` and/or `gsd-sketch`). The user picks the winning sketch variant; write its folder in `sketch:` and the URL paths in `pages:` of `<P>-LAYOUT.md` (plus `url:` for the app, e.g. `http://localhost:{port:3100}`, when the project has several apps), then commit. `sketch: skip <reason>` only when the user agrees. |
| `ui-phase` | Invoke/follow `gsd-ui-phase <N>`, following `note=` (DESIGN.md and the chosen sketch). Stop for screen approval. |
| `plan` | Invoke/follow `gsd-plan-phase <N>`. |
| `review` | Run the configured independent review. Stop and show verified findings, then replan with `--reviews`. If the review capability is unavailable, print the required next step and wait; do not treat the gate as complete. |
| `replan` | Invoke/follow `gsd-plan-phase <N> --reviews`. |
| `verifier` / `execute` | Invoke/follow `gsd-execute-phase <N>`; completed plans make it verifier-only. |
| `gaps` | Plan with `--gaps`, then execute with `--gaps-only`. |
| `verify-work` | Invoke/follow `gsd-verify-work <N>` and record agent-driven UAT. |
| `code-review` | Invoke/follow `gsd-code-review <N> --fix` when issues exist. |
| `screenshots` | Start the app in this worktree (its dev script), then run `gsd-ui shots <N>` and commit `<P>-SHOTS.md`. If that is impossible, ask the user, then `gsd-ui shots <N> --skip "<reason>"`. |
| `ui-review` | Invoke/follow `gsd-ui-review <N>`; look at the screenshots in `<P>-SHOTS/` and compare them with the chosen sketch and the layout rules, as `note=` says. |
| `secure` | Invoke/follow `gsd-secure-phase <N>` as the last code gate. |
| `done` | Print the finish line. Do **not** run `gsd-finish` unless the user says so: it deletes the directory this session stands in and must be the session's last action. |

After every step: run `gsd-flow-next` again. Loop until `step=done`.
Before executing a `then=` follow-up, validate that exact command too:
`gsd-worktree-guard --command <gsd-command> --args "<phase and flags>" --repo "$PWD"`.
Stop on a nonzero exit. A preview (`--all`) is not permission to execute future
steps; use a normal `gsd-flow-next` call at each step.

## Planned approval gates

1. discuss — the user answers the questions.
2. design-system and layout (phases with screens) — the user agrees the design
   system once per project, and picks the sketch for each phase.
3. ui-phase — the user agrees the screens.
4. review — the user sees the configured reviewer's findings before the replan.

The ticket may require clarification, and `ui-decision` asks whether the phase
has screens. Never guess those answers. A `stop=` line describes required user
input; pause when that input is unavailable.

## `--dry-run`

```
Bash: gsd-flow-next <N> --all [--ui|--no-ui]
```

Print the remaining steps as a numbered list, one line each, and stop. Run
nothing. This is the safe way to answer "what is left on phase N".

## Rules

- If the guard blocks a step, read the named prerequisite and resolve it
  before retrying. A running or failed install needs a completed install;
  missing planning artifacts need the named earlier step. Do not repeat an
  unchanged blocked command or use `GSD_SKIP_GUARD=1` unless the user asks.
- Never auto-answer discuss questions. This is the one thing that makes this
  skill different from `/gsd-autonomous`.
- One phase per session. For the next phase the user opens a new worktree
  session via `gsd-start`.
