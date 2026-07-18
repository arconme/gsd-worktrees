#!/usr/bin/env bash
# gsd-worktrees shim — the real logic lives in the gsd-worktrees toolkit
# (bin/gsd-wt-new). This file exists so committed references keep working and
# never needs updating. Repo settings: .gsd.conf at the repo root.
command -v gsd-wt-new >/dev/null 2>&1 \
  || { echo "error: gsd-wt-new not found — install the gsd-worktrees toolkit (clone arconme/gsd-worktrees, run ./install.sh)" >&2; exit 1; }
exec gsd-wt-new "$@"
