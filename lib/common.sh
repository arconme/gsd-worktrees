# shellcheck shell=bash
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
  # substr, not $2: a checkout path with a space in it would be cut at the space
  git -C "${1:-.}" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10); exit}'
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

gsd_register_merge_driver() {  # $1=repo root — register the .planning merge driver
  # Merge drivers live in git config, which is NOT versioned, so a clone that
  # never ran gsd-bootstrap-repo would fall back to a plain conflict on the
  # union-merged planning files. Every gsd command that is about to merge
  # re-asserts the registration first; it is idempotent and costs one git call.
  # Worktrees share the main checkout's config, so one registration covers all
  # of them.
  command -v gsd-planning-merge >/dev/null 2>&1 || return 0
  local want="gsd-planning-merge %O %A %B %P"
  [ "$(git -C "$1" config --get merge.gsd-planning.driver 2>/dev/null)" = "$want" ] && return 0
  git -C "$1" config merge.gsd-planning.driver "$want"
  git -C "$1" config merge.gsd-planning.name \
    "GSD planning files: union, then reconcile single-value lines"
}

gsd_python() {  # → the interpreter for lib/gsd_planning.py; nonzero when none
  # Most systems have `python3`, but minimal images (and Windows) name it
  # `python`. Checking the NAME is not enough: `python` is still Python 2 on
  # older systems, which cannot run the reconciler at all — so verify the
  # version by asking the interpreter itself. Cached: the reconciler is called
  # several times per finish, and each probe is a process spawn.
  if [ -n "${GSD_PYTHON:-}" ]; then printf '%s\n' "$GSD_PYTHON"; return 0; fi
  local py
  for py in python3 python; do
    command -v "$py" >/dev/null 2>&1 || continue
    "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 7) else 1)' 2>/dev/null || continue
    GSD_PYTHON="$py"
    printf '%s\n' "$py"
    return 0
  done
  return 1
}

gsd__add_missing() { GSD_PLANNING_MISSING="${GSD_PLANNING_MISSING:+$GSD_PLANNING_MISSING }$1"; }

gsd_planning_hook() {  # $1=repo root → GSD_HOOK_PATH, GSD_HOOK_LABEL, GSD_HOOK_VERSIONED
  # Husky owns post-merge where it is installed (core.hooksPath points into
  # .husky/_, which husky regenerates), and there the hook is a VERSIONED file.
  #
  # Everywhere else, ASK GIT for the hooks dir and decide by WHERE IT LANDS —
  # do not assume .git/hooks. A repo may point core.hooksPath at a tracked
  # directory (scripts/git-hooks is a common convention), and there the hook
  # belongs in the commit like any other file. Assuming it was always
  # unversioned left it untracked in exactly such a repo: it worked for the
  # clone that ran the bootstrap and protected nobody else.
  local dir gitdir root
  if [ -d "$1/.husky" ]; then
    GSD_HOOK_PATH="$1/.husky/post-merge"
    GSD_HOOK_LABEL=".husky/post-merge"
    GSD_HOOK_VERSIONED=1
    return 0
  fi
  dir="$(git -C "$1" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)"
  gitdir="$(git -C "$1" rev-parse --path-format=absolute --git-dir 2>/dev/null)"
  # Take the root from GIT too, not from "$1": these are string comparisons, and
  # a caller-supplied path can spell the same directory differently (on macOS
  # /var vs /private/var), which would silently flip the answer.
  root="$(git -C "$1" rev-parse --path-format=absolute --show-toplevel 2>/dev/null)" || root="$1"
  [ -n "$root" ] || root="$1"
  GSD_HOOK_PATH="$dir/post-merge"
  # Order matters: .git/ is itself inside the working tree, so test it first.
  case "$dir/" in
    "$gitdir"/*) GSD_HOOK_VERSIONED=0 ;;   # per clone — cannot be committed
    "$root"/*)   GSD_HOOK_VERSIONED=1 ;;   # in the working tree — tracked
    *)           GSD_HOOK_VERSIONED=0 ;;   # outside the repo entirely
  esac
  if [ "$GSD_HOOK_VERSIONED" = 1 ]; then
    GSD_HOOK_LABEL="${GSD_HOOK_PATH#"$root"/}"
  else
    GSD_HOOK_LABEL="$(git -C "$1" rev-parse --git-path hooks)/post-merge (not versioned)"
  fi
}

gsd_planning_status() {  # $1=repo root → GSD_PLANNING_MISSING + GSD_ATTRS_STATE
  # The single source of truth for "is this repo's .planning merge safety
  # installed". gsd-bootstrap-repo applies what this reports missing and
  # gsd-doctor reports it — one predicate, so the two can never disagree about
  # what counts as installed. Three items; the repair SHIM is not one of them,
  # it rides along with the ordinary shims.
  local repo="$1" attrs="$1/.gitattributes"
  GSD_PLANNING_MISSING=""

  if grep -qE '^\.planning/(ROADMAP|STATE)\.md[[:space:]]+merge=union[[:space:]]*$' "$attrs" 2>/dev/null; then
    GSD_ATTRS_STATE=union            # the dangerous one: keeps BOTH sides
  elif [ "$(grep -cE '^\.planning/(ROADMAP|STATE)\.md[[:space:]]+merge=gsd-planning[[:space:]]*$' "$attrs" 2>/dev/null)" = 2 ]; then
    GSD_ATTRS_STATE=ok
  else
    GSD_ATTRS_STATE=absent
  fi
  [ "$GSD_ATTRS_STATE" = ok ] || gsd__add_missing attributes

  [ "$(git -C "$repo" config --get merge.gsd-planning.driver 2>/dev/null)" \
      = "gsd-planning-merge %O %A %B %P" ] || gsd__add_missing driver

  gsd_planning_hook "$repo"
  grep -q 'gsd-planning-repair' "$GSD_HOOK_PATH" 2>/dev/null || gsd__add_missing hook
}

gsd_planning_apply() {  # $1=repo root — install whatever gsd_planning_status reports missing
  local repo="$1" attrs="$1/.gitattributes" line
  gsd_planning_status "$repo"

  case " $GSD_PLANNING_MISSING " in *" attributes "*)
    if [ "$GSD_ATTRS_STATE" = union ]; then
      perl -pi -e 's{^(\.planning/(?:ROADMAP|STATE)\.md\s+merge=)union\s*$}{$1gsd-planning\n}' "$attrs"
      echo "✔ .gitattributes (migrated .planning merge=union → merge=gsd-planning)"
    fi
    for line in '.planning/ROADMAP.md merge=gsd-planning' '.planning/STATE.md merge=gsd-planning'; do
      grep -qxF "$line" "$attrs" 2>/dev/null || echo "$line" >> "$attrs"
    done
    echo "✔ .gitattributes (merge=gsd-planning for .planning/ROADMAP.md + STATE.md)"
  ;; esac

  case " $GSD_PLANNING_MISSING " in *" driver "*)
    if gsd_register_merge_driver "$repo" \
       && [ -n "$(git -C "$repo" config --get merge.gsd-planning.driver 2>/dev/null)" ]; then
      echo "✔ merge driver registered (merge.gsd-planning → gsd-planning-merge)"
    else
      echo "⚠ could not register the merge driver — gsd-finish re-asserts it on every run"
    fi
  ;; esac

  case " $GSD_PLANNING_MISSING " in *" hook "*)
    # The driver covers merges; the hook covers a plain `git pull` on the base
    # branch by someone who never runs gsd-finish.
    local body='#!/usr/bin/env sh
# Installed by gsd-bootstrap-repo (gsd-worktrees toolkit).
# .planning/ROADMAP.md and STATE.md merge with a union-then-reconcile driver.
# A pull whose driver was missing, or a merge done by another tool, can still
# leave both sides of a single-value line behind — reconcile them here.
command -v gsd-planning-repair >/dev/null 2>&1 || exit 0
[ -d .planning ] || exit 0
gsd-planning-repair || true
'
    mkdir -p "$(dirname "$GSD_HOOK_PATH")"
    if [ -e "$GSD_HOOK_PATH" ]; then
      printf '\n%s\n' "$body" | sed '1d' >> "$GSD_HOOK_PATH"
      echo "✔ $GSD_HOOK_LABEL (gsd reconcile appended to the existing hook)"
    else
      printf '%s' "$body" > "$GSD_HOOK_PATH"
      chmod +x "$GSD_HOOK_PATH"
      echo "✔ $GSD_HOOK_LABEL (created)"
    fi
  ;; esac
}

gsd_release_lock() { rm -rf "${GSD_LOCKDIR:-}" 2>/dev/null || true; }

gsd_acquire_lock() {  # $1=MAIN checkout — serialize gsd commands on this checkout
  # Two gsd commands on the SAME machine share the main checkout (index, HEAD,
  # ROADMAP); this lock serializes them. Sets GSD_LOCKDIR and installs a
  # release trap. Re-entrant: a no-op when the caller already holds the lock
  # (gsd-finish exports GSD_LOCK_HELD=1 before delegating to gsd-wt-finish).
  # NOT exported here: gsd-start execs an agent session after releasing, and an
  # inherited GSD_LOCK_HELD=1 would disable locking for that whole session.
  [ "${GSD_LOCK_HELD:-}" = 1 ] && return 0
  GSD_LOCKDIR="$1/.git/gsd-cmd.lock"
  local waited=0 lockpid
  until mkdir "$GSD_LOCKDIR" 2>/dev/null; do
    # Reclaim a stale lock left by a crashed run (owner PID gone). mv first so
    # only one waiter wins the reclaim.
    lockpid=$(cat "$GSD_LOCKDIR/pid" 2>/dev/null || true)
    if [ -n "$lockpid" ] && ! kill -0 "$lockpid" 2>/dev/null; then
      if mv "$GSD_LOCKDIR" "$GSD_LOCKDIR.stale.$$" 2>/dev/null; then
        rm -rf "$GSD_LOCKDIR.stale.$$"
        echo "▶ reclaimed stale gsd lock (owner PID $lockpid no longer running)"
      fi
      continue
    fi
    [ "$waited" -eq 0 ] && echo "▶ another gsd command is using this checkout — waiting (lock: $GSD_LOCKDIR)…"
    waited=$((waited + 1))
    if [ "$waited" -ge 300 ]; then
      echo "✖ gave up waiting after 300s — if no gsd command is running, remove the stale lock: rm -rf $GSD_LOCKDIR" >&2
      return 1
    fi
    sleep 1
  done
  echo "$$" > "$GSD_LOCKDIR/pid"
  trap gsd_release_lock EXIT INT TERM
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
