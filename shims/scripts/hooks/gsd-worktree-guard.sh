#!/usr/bin/env bash
# gsd-worktrees shim — the real guard lives in the gsd-worktrees toolkit
# (bin/gsd-worktree-guard). Provider adapters may register this defense-in-depth
# native hook; the supported shell flow calls the shared guard directly. This
# shim fails open when the toolkit is missing.
command -v gsd-worktree-guard >/dev/null 2>&1 || exit 0
exec gsd-worktree-guard "$@"
