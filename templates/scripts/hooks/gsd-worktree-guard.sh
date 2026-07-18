#!/usr/bin/env bash
#
# GSD worktree guard. Registered (see .claude/settings.json) on:
#   - UserPromptExpansion  → catches TYPED /gsd-… slash commands
#   - PreToolUse (Skill)   → catches model-initiated Skill calls
#
# Rules (independent of how the command was invoked):
#   1. /gsd-phase            → only on the 'develop' branch (the shared claim point).
#   2. per-phase commands    → only inside the matching 'phase-<N>-*' worktree.
#   3. /gsd-execute-phase    → also requires deps installed (background install done).
#
# Block = exit 2 (stderr shown). Escape hatch: GSD_SKIP_GUARD=1.
set -uo pipefail

[ -n "${GSD_SKIP_GUARD:-}" ] && exit 0
input=$(cat 2>/dev/null || true)

# Command + args from the known payload shapes:
#   UserPromptExpansion → .command_name / .command_args
#   PreToolUse(Skill)   → .tool_input.skill / .tool_input.args
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.command_name // .tool_input.skill // empty' 2>/dev/null || true)
  args=$(printf '%s' "$input" | jq -r '.command_args // .tool_input.args // empty' 2>/dev/null || true)
else
  cmd=$(printf '%s' "$input" | sed -n 's/.*"command_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  [ -z "$cmd" ] && cmd=$(printf '%s' "$input" | sed -n 's/.*"skill"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  args=$(printf '%s' "$input" | sed -n 's/.*"command_args"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
cmd="${cmd:-}"; args="${args:-}"
case "$cmd" in gsd-*) ;; *) exit 0 ;; esac   # not a GSD command → allow

N=$(printf '%s' "$args" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1 || true)

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

block() { printf '%s\n' "$@" >&2; exit 2; }

# Rule 1 — /gsd-phase only on develop
if [ "$cmd" = "gsd-phase" ]; then
  [ "$branch" = "develop" ] && exit 0
  block "BLOCKED: /gsd-phase must run on 'develop' (main checkout), not '$branch'." \
        "Claim the phase number on develop first. See CLAUDE.md > GSD planning system."
fi

# Per-phase ("feature work") commands
case " gsd-discuss-phase gsd-plan-phase gsd-execute-phase gsd-ui-phase gsd-mvp-phase gsd-spec-phase gsd-ai-integration-phase gsd-verify-work gsd-secure-phase gsd-validate-phase gsd-code-review gsd-add-tests gsd-extract-learnings gsd-ui-review gsd-eval-review " in
  *" $cmd "*) ;;
  *) exit 0 ;;   # progress, help, map-codebase, resume-work, … allowed anywhere
esac

[ "$branch" = "develop" ] && block \
  "BLOCKED: /$cmd is feature work — run it in the phase worktree, not on develop." \
  "Create/open it with: scripts/gsd-new-worktree-feature.sh  (then open a session in phase-${N:-<N>}-*). See CLAUDE.md."

[ -z "$N" ] && exit 0   # no phase number given; 'not develop' already satisfied

case "$branch" in
  phase-"$N"-*|phase-"$N") : ;;   # correct worktree
  phase-*) block "BLOCKED: you're in '$branch', but /$cmd targets phase $N. Switch to the phase-$N-* worktree." ;;
  *)       block "BLOCKED: /$cmd targets phase $N but '$branch' isn't a phase-$N-* worktree. See CLAUDE.md." ;;
esac

# Rule 3 — execute-phase needs deps installed
if [ "$cmd" = "gsd-execute-phase" ] && [ ! -d "$dir/node_modules" ]; then
  s=$(cat "$dir/.gsd-install.status" 2>/dev/null || echo running)
  [ "$s" = "ok" ] && exit 0   # install completed (repo may simply have no deps)
  [ "$s" = "fail" ] && block "BLOCKED: dependency install FAILED — see $dir/.gsd-install.log, then run 'pnpm install'."
  block "BLOCKED: dependencies still installing (no node_modules yet). Wait, or run 'pnpm install'. Log: $dir/.gsd-install.log"
fi

exit 0
