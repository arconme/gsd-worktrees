# lib/common.sh — shared helpers for the gsd-worktrees commands. Sourced, not run.
#
# Per-repo settings come from an OPTIONAL committed `.gsd.conf` at the repo
# root (key = value); anything not set there falls back to detection, so most
# repos need no config at all:
#
#   base    = develop            # base branch (detect: develop, else main, else current)
#   wtdir   = myrepo-worktrees   # sibling dir for worktrees (detect: <repo-name>-worktrees)
#   install = pnpm install       # worktree bootstrap cmd; 'none' disables (detect: by lockfile)

gsd_main() {  # $1=any path inside the repo → the MAIN checkout (first worktree entry)
  git -C "${1:-.}" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}'
}

gsd_conf_get() {  # $1=repo root  $2=key → value ('' when unset)
  [ -f "$1/.gsd.conf" ] || return 0
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1/.gsd.conf" \
    | head -1 | sed -e 's/[[:space:]]*$//' -e 's/[[:space:]]*#.*$//'
}

gsd_base() {  # $1=repo root (any checkout — branch refs are shared)
  local v; v=$(gsd_conf_get "$1" base)
  if [ -n "$v" ]; then printf '%s\n' "$v"; return 0; fi
  if   git -C "$1" show-ref --verify --quiet refs/heads/develop; then echo develop
  elif git -C "$1" show-ref --verify --quiet refs/heads/main;    then echo main
  else git -C "$1" branch --show-current; fi
}

gsd_wtdir() {  # $1=MAIN checkout → NAME of the sibling worktrees dir
  local v; v=$(gsd_conf_get "$1" wtdir)
  printf '%s\n' "${v:-$(basename "$1")-worktrees}"
}

gsd_install_cmd() {  # $1=repo root → worktree bootstrap command ('' = skip)
  local v; v=$(gsd_conf_get "$1" install)
  if [ -n "$v" ]; then
    [ "$v" = none ] || printf '%s\n' "$v"
    return 0
  fi
  if   [ -f "$1/pnpm-lock.yaml" ];     then echo "pnpm install"
  elif [ -f "$1/yarn.lock" ];          then echo "yarn install"
  elif [ -f "$1/package-lock.json" ] || [ -f "$1/package.json" ]; then echo "npm install"
  fi
}
