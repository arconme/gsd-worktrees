# Provider-coupling audit

The pre-refactor hardcoded references were classified as follows.

| Area | Previous coupling | Classification | Result |
|---|---|---|---|
| `gsd-init`, `gsd-start` | one positional-prompt shape and Claude default | provider adapter + compatibility | argv rendering moved to `lib/provider.sh`; default remains compatibility-only |
| `gsd-bootstrap-repo` | unconditional `CLAUDE.md` and `.claude/settings.json` | provider adapter | explicit single/multi-provider generation with canonical shared instructions |
| `gsd-worktree-guard` | Claude hook JSON and `CLAUDE_PROJECT_DIR` | adapter input + core safety | explicit neutral CLI input added; Claude/Gemini payload/env parsing retained at the edge |
| `gsd-wt-new` | copies `.claude/settings.local.json` and recognizes Claude nested worktrees | compatibility behavior | retained so existing Claude sessions continue to work; no core phase policy depends on it |
| `install.sh` | `~/.claude/skills` only | provider adapter | per-provider destinations and overrides |
| `gsd-flow` | literal Claude-native skill calls | provider adapter leakage | removed; shared skill follows `gsd-flow-next` and the active provider's real mechanism |
| README/help/shim comments | Claude-only safety claims | documentation wording | replaced with provider capabilities and enforcement boundary |
| independent review default | Codex reviewer | workflow configuration/compatibility | `review_provider` is configurable; Codex remains the existing default |

Remaining `.claude`, `CLAUDE.md`, `claude`, and `Skill` strings are confined to
the Claude adapter, compatibility copying/nested-worktree logic, tests, and
documented examples. Shared planning reconciliation, phase state, worktree
claims, merge handling, and strict-order rules contain no provider selection.

Fresh-review recheck (2026-09-25): native-hook metadata and predicates now live
in `lib/provider.sh`; installer and doctor share skill-root resolution. The
bootstrap gitignore and worktree-local settings copy retain Claude paths only
for compatibility. CLI allowlists/help and manifest field names identify
adapters; they are not workflow policy. The hook payload helper's `--claude`
mode is a JSON adapter. No shared instruction contains a literal `Skill()` call.
`review_provider` uses verified external review flags with an explicit manual
handoff fallback, not a provider-native invocation in the core state machine.
