#!/usr/bin/env bash
# gsd-worktrees shim — the real logic lives in the gsd-worktrees toolkit
# (bin/gsd-dev). This file exists so committed references (e.g. a `dev:wt`
# package script) keep working and never needs updating. The repo-specific
# part — the scripts/gsd-dev.conf manifest — stays in the repo.
command -v gsd-dev >/dev/null 2>&1 \
  || { echo "error: gsd-dev not found — install the gsd-worktrees toolkit (clone arconme/gsd-worktrees, run ./install.sh)" >&2; exit 1; }
exec gsd-dev "$@"
