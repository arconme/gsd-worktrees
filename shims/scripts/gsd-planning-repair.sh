#!/usr/bin/env bash
# gsd-worktrees shim — the real logic lives in the gsd-worktrees toolkit
# (bin/gsd-planning-repair). This file exists so committed references (CI jobs,
# git hooks, package.json scripts) keep working and never need updating.
# Repo settings: .gsd.conf at the repo root.
command -v gsd-planning-repair >/dev/null 2>&1 \
  || { echo "error: gsd-planning-repair not found — install the gsd-worktrees toolkit (clone arconme/gsd-worktrees, run ./install.sh)" >&2; exit 1; }
exec gsd-planning-repair "$@"
