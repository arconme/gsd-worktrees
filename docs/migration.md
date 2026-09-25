# Migration guide

Run `gsd-init` from the desired base checkout. It delegates to the idempotent
bootstrap layer, does not touch existing `.planning/`, and never silently
changes providers.

- Remain Claude-only: `gsd-init --provider claude --no-launch`
- Switch to Codex: `gsd-init --provider codex --no-launch`
- Switch to Gemini: `gsd-init --provider gemini --no-launch`
- Support several: `gsd-init --providers claude,codex,gemini --provider claude --no-launch`

Use repeated `--provider-command provider=executable` flags for nonstandard
executable paths. `--provider` must be a member of `--providers`; invalid
selections fail before repository files are written.

For per-provider executable overrides, use `claude_command`, `codex_command`,
and `gemini_command`. Then hand the same phase between providers with repeated
`gsd-start -p <N> --provider <name> --no-launch` calls. This reuses the phase
worktree and planning state; do not run concurrent mutating sessions there.

Legacy Claude repositories receive `.gsd/INSTRUCTIONS.md`, a marked entrypoint
in `CLAUDE.md`, and an ordered `providers` key. A legacy singular `provider`
key remains readable when `providers` is absent; re-running `gsd-init` writes
the equivalent one-entry list and removes only that redundant key. Bootstrap never assumes that an
unmarked `## GSD planning system` section is wholly toolkit-owned: it preserves
that section byte-for-byte because it may contain repository-specific policy.
The marked adapter makes the canonical document authoritative for toolkit
command syntax and workflow order while retaining the older section's project
rules. After reviewing and relocating any project-specific rules, maintainers
may remove obsolete legacy wording manually. Invalid JSON settings are left
untouched with a warning.

Bootstrap validates generated instruction markers before writing any files.
Unmatched, nested, duplicate, reversed, or inline markers stop the migration
with a filename to repair; user content is preserved. Resolve the markers and
rerun `gsd-init`.

Canonical instructions now have `canonical:start` / `canonical:end` markers;
new bootstrap runs preserve text outside them. The older single-marker format
is backed up as `INSTRUCTIONS.md.bak` (numbered if necessary) before migrating
its recognizable generated span. Keep that backup until you verify local additions.

On migration, legacy `agent_command` is saved under its original provider's
`*_command` key and the generic key is removed. Changing the default provider
therefore cannot accidentally launch the old executable. An explicit command
override updates the provider-specific key, and `--provider-command` alone
preserves an existing configured provider set. To add a new provider, pass the
complete set with `gsd-init --providers ...`.

To remove one integration, remove its name from `providers =`, then delete only
the text between `gsd-worktrees:provider:start` and
`gsd-worktrees:provider:end` in its instruction file. Remove the matching hook
entry only if it calls `gsd-worktree-guard`; do not delete unrelated settings.
For Codex/custom, which share `AGENTS.md`, re-run `gsd-init --no-launch` after
editing the set; do not delete the shared block while either provider remains.

To roll back, remove only the marked provider and canonical instruction
blocks, then remove `providers` (and a legacy `provider`, if still present),
`agent_command`, and any `*_command` keys from `.gsd.conf`. Their absence restores the Claude
compatibility default. Existing `.planning/`, merge behavior, and shims remain
compatible. Preserve any user content outside the canonical block rather than
deleting its whole file. Restore the canonical `.bak` when rolling back a
single-marker migration, after checking for subsequent user edits.
