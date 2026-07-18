#!/usr/bin/env bash
# gsd-worktrees shim — the real logic lives in the gsd-worktrees toolkit
# (bin/gsd-derive-port). Referenced from app package.json dev scripts, so it
# degrades gracefully: without the toolkit (CI, a teammate's machine) it
# prints the bare base port and plain `dev` keeps working.
command -v gsd-derive-port >/dev/null 2>&1 && exec gsd-derive-port "$@"
echo "${1:?usage: gsd-derive-port.sh <base-port>}"
