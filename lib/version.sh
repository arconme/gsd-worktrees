# shellcheck shell=bash
# lib/version.sh — the toolkit's version, and the "a newer release is out" check.
#
# Two things are checked:
#   gsd-worktrees  GitHub releases of $GSD_UPDATE_REPO (default below), vX.Y.Z
#   GSD itself     the get-shit-done-cc package on npm (gsd-sdk -v installed)
# Each latest version is cached for a day in ${XDG_CACHE_HOME:-~/.cache}/
# gsd-worktrees/ (latest-version, latest-gsd-version), so commands never wait
# on the network: gsd_update_notice reads the caches and refreshes stale ones
# in the background. GSD_NO_UPDATE_CHECK=1 turns every check off.
# Sourced after lib/common.sh; needs GSD_PKG.

GSD_UPDATE_REPO_DEFAULT=arconme/gsd-worktrees

gsd_version() {  # → X.Y.Z of this package ('unknown' without a VERSION file)
  local v; v=$(head -1 "$GSD_PKG/VERSION" 2>/dev/null | tr -d '[:space:]')
  printf '%s\n' "${v:-unknown}"
}

gsd_update_repo() { printf '%s\n' "${GSD_UPDATE_REPO:-$GSD_UPDATE_REPO_DEFAULT}"; }

gsd_version_gt() {  # $1 > $2 ? (X.Y.Z, a leading v is fine; anything else → false)
  local a=${1#v} b=${2#v} i x y
  printf '%s\n%s\n' "$a" "$b" | grep -qvE '^[0-9]+(\.[0-9]+){0,2}$' && return 1
  for i in 1 2 3; do
    x=$(printf '%s' "$a" | cut -d. -f"$i"); y=$(printf '%s' "$b" | cut -d. -f"$i")
    x=$((10#${x:-0})); y=$((10#${y:-0}))
    [ "$x" -gt "$y" ] && return 0
    [ "$x" -lt "$y" ] && return 1
  done
  return 1
}

gsd_update_cache() { printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/gsd-worktrees/latest-version"; }

gsd_latest_fetch() {  # → latest release version from GitHub ('' when unreachable)
  curl -fsSL --max-time 5 -H 'Accept: application/vnd.github+json' \
      "https://api.github.com/repos/$(gsd_update_repo)/releases/latest" 2>/dev/null \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([0-9][0-9.]*\)".*/\1/p' | head -1 || true
}

gsd_latest_refresh() {  # fetch now and cache; offline keeps the old value but waits a day
  local f v; f=$(gsd_update_cache)
  mkdir -p "$(dirname "$f")" 2>/dev/null || return 0
  v=$(gsd_latest_fetch)
  if [ -n "$v" ]; then printf '%s\n' "$v" > "$f.$$" && mv "$f.$$" "$f"
  else touch "$f" 2>/dev/null || true; fi
}

gsd_latest_stale() {  # true when the cache is missing or older than a day
  local f; f=$(gsd_update_cache)
  [ ! -f "$f" ] || [ -z "$(find "$f" -mmin -1440 2>/dev/null)" ]
}

gsd_latest_cached() { head -1 "$(gsd_update_cache)" 2>/dev/null | tr -d '[:space:]' || true; }

# ── GSD itself (npm) ─────────────────────────────────────────────────────────
gsd_gsd_cache() { printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/gsd-worktrees/latest-gsd-version"; }

gsd_gsd_installed() {  # → installed gsd-sdk X.Y.Z ('' when not installed)
  command -v gsd-sdk >/dev/null 2>&1 || return 0
  gsd-sdk -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

gsd_gsd_fetch() {  # → latest get-shit-done-cc on npm ('' when unreachable)
  command -v npm >/dev/null 2>&1 || return 0
  npm view get-shit-done-cc dist-tags.latest --fetch-retries=0 --fetch-timeout=5000 2>/dev/null \
    | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true
}

gsd_gsd_refresh() {  # like gsd_latest_refresh, for npm
  local f v; f=$(gsd_gsd_cache)
  mkdir -p "$(dirname "$f")" 2>/dev/null || return 0
  v=$(gsd_gsd_fetch)
  if [ -n "$v" ]; then printf '%s\n' "$v" > "$f.$$" && mv "$f.$$" "$f"
  else touch "$f" 2>/dev/null || true; fi
}

gsd_gsd_stale() {
  local f; f=$(gsd_gsd_cache)
  [ ! -f "$f" ] || [ -z "$(find "$f" -mmin -1440 2>/dev/null)" ]
}

gsd_gsd_cached() { head -1 "$(gsd_gsd_cache)" 2>/dev/null | tr -d '[:space:]' || true; }

GSD_GSD_UPDATE_CMD="npm i -g get-shit-done-cc@latest"

gsd_update_how() {  # the command that updates THIS install
  if [ -e "$GSD_PKG/.git" ]; then echo gsd-sync; else echo gsd-update; fi
}

# One stderr line per newer release known (this toolkit, GSD itself). Only for a person at a
# terminal (stderr is a tty), so piped / JSON / agent output stays clean;
# GSD_UPDATE_NOTICE=always forces it (tests). gsd-doctor always reports it.
gsd_update_notice() {
  [ -z "${GSD_NO_UPDATE_CHECK:-}" ] || return 0
  [ -t 2 ] || [ "${GSD_UPDATE_NOTICE:-}" = always ] || return 0
  if gsd_latest_stale; then ( gsd_latest_refresh ) >/dev/null 2>&1 </dev/null & fi
  if command -v gsd-sdk >/dev/null 2>&1 && gsd_gsd_stale; then ( gsd_gsd_refresh ) >/dev/null 2>&1 </dev/null & fi
  local new cur; new=$(gsd_latest_cached); cur=$(gsd_version)
  if [ -n "$new" ] && gsd_version_gt "$new" "$cur"; then
    printf '• gsd-worktrees %s is out (you have %s) — update: %s\n' "$new" "$cur" "$(gsd_update_how)" >&2
  fi
  new=$(gsd_gsd_cached)
  if [ -n "$new" ]; then
    cur=$(gsd_gsd_installed)
    if [ -n "$cur" ] && gsd_version_gt "$new" "$cur"; then
      printf '• GSD %s is out (you have %s) — update: %s\n' "$new" "$cur" "$GSD_GSD_UPDATE_CMD" >&2
    fi
  fi
  return 0
}
