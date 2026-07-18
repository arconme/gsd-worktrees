#!/usr/bin/env bash
# gsd-worktrees shim — the real guard lives in the gsd-worktrees toolkit
# (bin/gsd-worktree-guard). Registered as a Claude Code hook in
# .claude/settings.json; this file exists so that committed registration keeps
# working and never needs updating. Fails OPEN: on a machine without the
# toolkit there is simply no guard enforcement.
command -v gsd-worktree-guard >/dev/null 2>&1 || exit 0
exec gsd-worktree-guard "$@"
