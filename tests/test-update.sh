#!/usr/bin/env bash
# test-update.sh — releases: get.sh installs a release, gsd-update moves
# between releases, checksums are enforced, old releases are pruned, and the
# "newer release" notice / doctor note. CI-safe: GitHub is a curl stub serving
# fake releases built from this checkout.
set -uo pipefail
PKG=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d); WORK=$(cd "$WORK" && pwd -P); trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export XDG_CACHE_HOME="$WORK/cache" GSD_UPDATE_REPO=acme/gsd-worktrees
export GSD_BIN_DIR="$WORK/bin" GSD_CLAUDE_SKILL_DIR="$WORK/skills"
unset GSD_NO_UPDATE_CHECK GSD_UPDATE_NOTICE GSD_RELEASES_DIR GSD_COPY_DIR
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/      /'; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { if grep -q -- "$2" "$3"; then ok "$1"; else bad "$1" "$(tail -5 "$3")"; fi; }
hasnt() { if grep -q -- "$2" "$3"; then bad "$1" "$(grep -- "$2" "$3" | head -3)"; else ok "$1"; fi; }
section() { printf '\n%s\n' "$1"; }

GSD_PKG=$PKG; . "$PKG/lib/common.sh"; . "$PKG/lib/version.sh"
section "version compare"
if gsd_version_gt 0.10.0 0.9.9; then ok "0.10.0 > 0.9.9 (numeric, not text)"; else bad "0.10.0 > 0.9.9 (numeric, not text)"; fi
if gsd_version_gt v1.2.3 1.2.3; then bad "equal is not newer"; else ok "equal is not newer"; fi
if gsd_version_gt 1.2.3 1.3.0; then bad "older is not newer"; else ok "older is not newer"; fi
if gsd_version_gt garbage 1.0.0; then bad "garbage is never newer"; else ok "garbage is never newer"; fi
if gsd_version_gt 1.0.08 1.0.7; then ok "zero-padded parts are not octal"; else bad "zero-padded parts are not octal"; fi

# ── fake GitHub ──────────────────────────────────────────────────────────────
REL="$WORK/releases-served"
release() {  # $1=version [$2=bad] — build a release tarball + SHA256SUMS from this checkout
  local v=$1 d="$WORK/build/gsd-worktrees-$1"
  mkdir -p "$d" "$REL/v$v"
  cp -R "$PKG/bin" "$PKG/lib" "$PKG/shims" "$PKG/skills" "$PKG/install.sh" "$PKG/get.sh" "$d/"
  printf '%s\n' "$v" > "$d/VERSION"
  tar -czf "$REL/v$v/gsd-worktrees-$v.tar.gz" -C "$WORK/build" "gsd-worktrees-$v"
  if [ "${2:-}" = bad ]; then echo "0000  gsd-worktrees-$v.tar.gz" > "$REL/v$v/SHA256SUMS"
  else (cd "$REL/v$v" && { sha256sum "gsd-worktrees-$v.tar.gz" 2>/dev/null || shasum -a 256 "gsd-worktrees-$v.tar.gz"; } > SHA256SUMS); fi
}
for v in 9.9.7 9.9.8 9.9.9; do release "$v"; done
release 9.9.6 bad
echo 9.9.9 > "$WORK/latest"
mkdir -p "$WORK/stub"
cat > "$WORK/stub/curl" <<'CURL'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do case "$1" in -o) out=$2; shift ;; -H|--max-time) shift ;; http*) url=$1 ;; esac; shift; done
echo "$url" >> "$WORK/curl.log"
case "$url" in
  https://api.github.com/repos/acme/gsd-worktrees/releases/latest)
    [ -s "$WORK/latest" ] || exit 22
    body=$(printf '{"url":"x","tag_name": "v%s","name":"n"}' "$(cat "$WORK/latest")") ;;
  https://github.com/acme/gsd-worktrees/releases/download/*)
    f="$REL/${url#https://github.com/acme/gsd-worktrees/releases/download/}"
    [ -f "$f" ] || exit 22
    if [ -n "$out" ]; then cp "$f" "$out"; exit 0; fi; cat "$f"; exit 0 ;;
  *) exit 6 ;;
esac
if [ -n "$out" ]; then printf '%s' "$body" > "$out"; else printf '%s' "$body"; fi
CURL
chmod +x "$WORK/stub/curl"
export WORK REL PATH="$WORK/stub:$PATH"
BIN="$WORK/bin"; RUN="$WORK/share/gsd-worktrees/releases"
points() { readlink "$BIN/$1" | sed -E "s#^$RUN/([^/]+)/.*#\1#"; }

section "get.sh — fresh install of a release"
bash "$PKG/get.sh" --version 9.9.8 --agent claude > "$WORK/out" 2>&1
is  "installs"                          "$?" 0
is  "commands link into releases/9.9.8" "$(points gsd-list)" 9.9.8
is  "the runtime says 9.9.8"            "$(cat "$RUN/9.9.8/VERSION")" 9.9.8
if [ -f "$RUN/9.9.8/get.sh" ]; then ok "the runtime carries get.sh (for gsd-update)"; else bad "the runtime carries get.sh (for gsd-update)"; fi
if [ -f "$WORK/skills/gsd-flow/.gsd-worktrees-skill" ]; then ok "the skill copy is marked as the toolkit's"; else bad "the skill copy is marked as the toolkit's"; fi
"$BIN/gsd-list" --help >/dev/null 2>&1; is "an installed command runs" "$?" 0

section "gsd-update — check, update, go back, prune"
"$BIN/gsd-update" --check > "$WORK/out" 2>&1
has "--check shows the installed version" "installed : 9.9.8" "$WORK/out"
has "…the latest"                       "latest    : 9.9.9" "$WORK/out"
has "…and says an update is there"      "update available" "$WORK/out"
is  "--check changes nothing"           "$(points gsd-list)" 9.9.8
"$BIN/gsd-update" > "$WORK/out" 2>&1
is  "update succeeds"                   "$?" 0
is  "commands now link into 9.9.9"      "$(points gsd-finish)" 9.9.9
if [ -d "$RUN/9.9.8" ]; then ok "the previous release is kept"; else bad "the previous release is kept"; fi
is  "no .bak left in bin or skills"     "$(find "$BIN" "$WORK/skills" -name '*.bak*' | wc -l | tr -d ' ')" 0
if [ -f "$WORK/skills/gsd-flow/SKILL.md" ] && [ ! -L "$WORK/skills/gsd-flow" ]; then ok "the skill was replaced in place"; else bad "the skill was replaced in place"; fi
"$BIN/gsd-update" > "$WORK/out" 2>&1
has "on the latest → up to date"        "up to date" "$WORK/out"
"$BIN/gsd-update" --version 9.9.7 > "$WORK/out" 2>&1
is  "--version goes back"               "$(points gsd-list)" 9.9.7
if [ -d "$RUN/9.9.9" ]; then ok "…keeping the one it left"; else bad "…keeping the one it left"; fi
if [ -d "$RUN/9.9.8" ]; then bad "…and removing older ones"; else ok "…and removing older ones"; fi

section "refusals"
if "$BIN/gsd-update" --version 9.9.6 > "$WORK/out" 2>&1; then bad "a checksum mismatch is refused"; else ok "a checksum mismatch is refused"; fi
has "…saying so"                        "checksum mismatch" "$WORK/out"
is  "…commands unchanged"               "$(points gsd-list)" 9.9.7
if "$BIN/gsd-update" --version 1.2.3 > "$WORK/out" 2>&1; then bad "a missing release is refused"; else ok "a missing release is refused"; fi
if bash "$PKG/get.sh" --version latest > "$WORK/out" 2>&1; then bad "a non-version is refused"; else ok "a non-version is refused"; fi
"$PKG/bin/gsd-update" > "$WORK/out" 2>&1
has "a git checkout is sent to gsd-sync" "git checkout — update it with: gsd-sync" "$WORK/out"

section "the newer-release notice"
rm -rf "$XDG_CACHE_HOME"
GSD_UPDATE_NOTICE=always "$BIN/gsd-list" --repo "$WORK/nope" > /dev/null 2> "$WORK/err"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$(gsd_update_cache)" ] && break; sleep 0.5; done
is  "a stale cache is refreshed in the background" "$(gsd_latest_cached)" 9.9.9
GSD_UPDATE_NOTICE=always "$BIN/gsd-list" --repo "$WORK/nope" > /dev/null 2> "$WORK/err"
has "then one line names the new release" "gsd-worktrees 9.9.9 is out (you have 9.9.7) — update: gsd-update" "$WORK/err"
"$BIN/gsd-list" --repo "$WORK/nope" > /dev/null 2> "$WORK/err"
hasnt "not a terminal → no notice"      "is out" "$WORK/err"
GSD_NO_UPDATE_CHECK=1 GSD_UPDATE_NOTICE=always "$BIN/gsd-list" --repo "$WORK/nope" > /dev/null 2> "$WORK/err"
hasnt "GSD_NO_UPDATE_CHECK=1 → no notice" "is out" "$WORK/err"
: > "$WORK/curl.log"
GSD_UPDATE_NOTICE=always "$BIN/gsd-list" --repo "$WORK/nope" > /dev/null 2>&1; sleep 1
is  "a fresh cache → no GitHub call"    "$(grep -c api.github.com "$WORK/curl.log")" 0
# GSD itself (npm): stub gsd-sdk 1.0.0 installed, npm says 1.2.0
printf '#!/usr/bin/env bash\necho "gsd-sdk v1.0.0"\n' > "$WORK/stub/gsd-sdk"
printf '#!/usr/bin/env bash\necho 1.2.0\n' > "$WORK/stub/npm"
chmod +x "$WORK/stub/gsd-sdk" "$WORK/stub/npm"
rm -f "$(gsd_gsd_cache)"   # a real gsd-sdk on this machine may have filled it already
GSD_UPDATE_NOTICE=always "$BIN/gsd-list" --repo "$WORK/nope" > /dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$(gsd_gsd_cache)" ] && break; sleep 0.5; done
GSD_UPDATE_NOTICE=always "$BIN/gsd-list" --repo "$WORK/nope" > /dev/null 2> "$WORK/err"
has "a newer GSD on npm gets its own line" "GSD 1.2.0 is out (you have 1.0.0) — update: npm i -g get-shit-done-cc@latest" "$WORK/err"
git init -qb main "$WORK/fresh"
(cd "$WORK/fresh" && GSD_UPDATE_NOTICE=always "$BIN/gsd-init" --no-launch --no-commit) > /dev/null 2> "$WORK/err"
has "gsd-init tells about a newer gsd-worktrees" "gsd-worktrees 9.9.9 is out" "$WORK/err"
has "…and a newer GSD"                  "GSD 1.2.0 is out" "$WORK/err"

section "gsd-doctor — updates"
R="$WORK/proj"; mkdir -p "$R/.planning"; git -C "$R" init -qb main
"$BIN/gsd-doctor" --repo "$R" > "$WORK/out" 2>&1
has "gsd-doctor shows the newer release" "gsd-worktrees 9.9.7 installed, 9.9.9 available — update: gsd-update" "$WORK/out"
"$BIN/gsd-doctor" --repo "$R" --quiet > "$WORK/out" 2>&1
has "…even with --quiet (gsd-worktrees)" "gsd-worktrees 9.9.7 installed, 9.9.9 available" "$WORK/out"
has "…even with --quiet (GSD)"          "GSD 1.0.0 installed, 1.2.0 available — update: npm i -g get-shit-done-cc@latest" "$WORK/out"
"$BIN/gsd-doctor" --repo "$R" --json > "$WORK/out" 2>/dev/null
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); u={x["name"]:x["latest"] for x in d["updates"]}; sys.exit(0 if u=={"gsd-worktrees":"9.9.9","GSD":"1.2.0"} else 1)' "$WORK/out"; then
  ok "--json lists both under updates (valid JSON)"; else bad "--json lists both under updates (valid JSON)" "$(head -c 300 "$WORK/out")"; fi
GSD_NO_UPDATE_CHECK=1 "$BIN/gsd-doctor" --repo "$R" --quiet > "$WORK/out" 2>&1
hasnt "GSD_NO_UPDATE_CHECK=1 → no update lines" "available — update" "$WORK/out"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
