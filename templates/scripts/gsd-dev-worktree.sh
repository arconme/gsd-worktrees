#!/usr/bin/env bash
#
# gsd-dev-worktree.sh — convenience launcher: boot all of this repo's dev
# servers together in one terminal (`pnpm dev:wt`), tearing them all down on
# Ctrl-C. The servers to boot are listed in scripts/gsd-dev.conf.
#
# This carries NO port logic. Each app's own `dev` script derives its
# per-worktree port from scripts/gsd-derive-port.sh, so plain `pnpm dev` is
# already per-worktree correct; this just saves running each one by hand. A repo
# with no manifest simply doesn't use this.
#
# Usage:
#   scripts/gsd-dev-worktree.sh          boot every service in the manifest
#   scripts/gsd-dev-worktree.sh --plan   list what would boot, then exit
#   scripts/gsd-dev-worktree.sh -f FILE  use an alternate manifest path
set -euo pipefail

MANIFEST="scripts/gsd-dev.conf"
PLAN_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --plan|-n) PLAN_ONLY=1; shift ;;
    -f|--file) [ $# -ge 2 ] || { echo "✖ $1 needs a value" >&2; exit 1; }
               MANIFEST="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✖ unknown arg: $1 (see --help)" >&2; exit 1 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "✖ run this from inside a git worktree" >&2; exit 1; }
cd "$ROOT"
[ -f "$MANIFEST" ] || {
  echo "✖ no manifest at $MANIFEST" >&2
  echo "  copy scripts/gsd-dev.conf.example to $MANIFEST and list this repo's dev servers." >&2
  exit 1
}

# ── parse the manifest: `name | command` per non-comment line ────────────────
names=(); cmds=()
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%%#*}"
  case "$line" in *[![:space:]]*) : ;; *) continue ;; esac
  IFS='|' read -r f_name f_cmd <<EOF
$line
EOF
  trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }
  f_name="$(trim "$f_name")"; f_cmd="$(trim "${f_cmd:-}")"
  [ -n "$f_name" ] && [ -n "$f_cmd" ] || { echo "✖ malformed line (need name|command): $line" >&2; exit 1; }
  names+=("$f_name"); cmds+=("$f_cmd")
done < "$MANIFEST"
[ "${#names[@]}" -gt 0 ] || { echo "✖ manifest $MANIFEST declares no services" >&2; exit 1; }

branch="$(git rev-parse --abbrev-ref HEAD)"
printf '\n  worktree : %s\n' "$branch"
for ((i = 0; i < ${#names[@]}; i++)); do printf '  %-12s %s\n' "${names[$i]}" "${cmds[$i]}"; done
printf '\n'
[ "$PLAN_ONLY" = 1 ] && exit 0

# ── boot all in parallel; tear the whole group down on exit ──────────────────
# Job control (set -m) puts each service in its own process group, so teardown
# can kill the whole tree (pnpm AND its node children) — a plain kill on the
# direct child leaves grandchildren holding the dev ports.
set -m
pids=()
cleanup() { for p in "${pids[@]:-}"; do [ -n "$p" ] && kill -- "-$p" 2>/dev/null || true; done; }
trap cleanup EXIT INT TERM

for ((i = 0; i < ${#names[@]}; i++)); do
  bash -c "${cmds[$i]}" &
  pids+=("$!")
done

wait
