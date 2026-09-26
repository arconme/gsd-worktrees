#!/usr/bin/env bash
# test-ui.sh — the UI quality gates outside the flow engine: the gsd-ui command
# (design, layout, shots with a stub Playwright and a local web server, the
# port slot, --skip, status), gsd-doctor's UI checks (T080, T018 ui_gates) and
# gsd-bootstrap-repo --no-ui / the instruction text. The flow steps are in
# test-flow-next.sh and the strict guard rules in test-worktree-guard.sh.
set -uo pipefail
PKG=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d); WORK=$(cd "$WORK" && pwd -P)
SERVER=""
cleanup() { [ -z "$SERVER" ] || { kill "$SERVER"; wait "$SERVER"; } 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT
export HOME="$WORK/home"; mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GSD_NO_UPDATE_CHECK=1 GSD_CLAUDE_SKILL_DIR="$WORK/skills"
unset GSD_PLAYWRIGHT GSD_SKIP_GUARD GSD_TRACKER
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/      /'; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { if grep -q -- "$2" "$3"; then ok "$1"; else bad "$1" "$(tail -6 "$3")"; fi; }
hasnt() { if grep -q -- "$2" "$3"; then bad "$1" "$(grep -- "$2" "$3" | head -3)"; else ok "$1"; fi; }
section() { printf '\n%s\n' "$1"; }
export PATH="$PKG/bin:$PATH"
PY=$(command -v python3 || command -v python)
OUT="$WORK/out"

# A stub Playwright CLI: `screenshot --viewport-size=W,H --full-page URL FILE`
# writes FILE and logs the call.
STUB="$WORK/stub"; mkdir -p "$STUB"
cat > "$STUB/playwright" <<'EOF'
#!/bin/sh
echo "$*" >> "$(dirname "$0")/calls.log"
[ "$1" = screenshot ] || exit 1
for a; do last=$a; done
echo png > "$last"
EOF
chmod +x "$STUB/playwright"

# A GSD repo on a phase-5 worktree branch. The app's dev script derives its
# port from a base, the way projects wire gsd-derive-port.
R="$WORK/app"; git init -q -b develop "$R"
BASEPORT=$(( 20000 + RANDOM % 9000 )); PORT=$((BASEPORT + 5))
printf '{ "scripts": { "dev": "PORT=$(bash ../../scripts/gsd-derive-port.sh %s) next dev" } }\n' "$BASEPORT" > "$R/package.json"
mkdir -p "$R/.planning/phases/05-shop"
printf '# Roadmap\n\n### Phase 5: Shop\n' > "$R/.planning/ROADMAP.md"
printf 'base = develop\ninstall = none\n' > "$R/.gsd.conf"
git -C "$R" add -A && git -C "$R" commit -qm init
git -C "$R" checkout -q -b phase-5-shop
PD="$R/.planning/phases/05-shop"

section "gsd-ui design"
(cd "$R" && gsd-ui design) > "$OUT" 2>&1
has "creates the stub" "stub) and .planning/design/refs/ created" "$OUT"
[ -f "$R/.planning/design/refs/.gitkeep" ] && ok "refs/ is kept in git" || bad "refs/ is kept in git"
grep -q 'gsd:design-stub' "$R/.planning/design/DESIGN.md" && ok "stub carries the marker" || bad "stub carries the marker"
echo "## Tokens: ours" > "$R/.planning/design/DESIGN.md"
(cd "$R" && gsd-ui design) > "$OUT" 2>&1
has "a filled DESIGN.md is left alone" "is filled" "$OUT"
is "…and not overwritten" "$(cat "$R/.planning/design/DESIGN.md")" "## Tokens: ours"

section "gsd-ui layout"
(cd "$R" && gsd-ui layout) > "$OUT" 2>&1
has "phase from the branch; creates LAYOUT" "05-LAYOUT.md created" "$OUT"
grep -q '^sketch:' "$PD/05-LAYOUT.md" && grep -q '^pages:' "$PD/05-LAYOUT.md" && ok "template has sketch: and pages:" || bad "template has sketch: and pages:"
echo "pages: /, /cart" > "$PD/05-LAYOUT.md"
(cd "$R" && gsd-ui layout 5) > "$OUT" 2>&1
has "an existing LAYOUT is not overwritten" "already exists" "$OUT"
is "…content kept" "$(cat "$PD/05-LAYOUT.md")" "pages: /, /cart"
(cd "$R" && gsd-ui layout 9) > "$OUT" 2>&1; is "no phase folder → exit 1" "$?" 1

section "gsd-ui shots — refusals"
(cd "$R" && gsd-ui shots 5) > "$OUT" 2>&1; rc=$?
is "no Playwright → exit 1" "$rc" 1
has "…says how to install it" "npm i -D playwright" "$OUT"
export GSD_PLAYWRIGHT="$STUB/playwright"
(cd "$R" && gsd-ui shots 5) > "$OUT" 2>&1; rc=$?
is "nothing listening → exit 1" "$rc" 1
has "…names the derived address" "nothing answers at http://localhost:$PORT" "$OUT"
[ ! -f "$PD/05-SHOTS.md" ] && ok "…and records nothing" || bad "…and records nothing"

section "gsd-ui shots — against a running app"
mkdir -p "$WORK/site/cart"; echo home > "$WORK/site/index.html"; echo cart > "$WORK/site/cart/index.html"
(cd "$WORK/site" && exec "$PY" -m http.server "$PORT" --bind 127.0.0.1) >/dev/null 2>&1 &
SERVER=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do curl -s -o /dev/null "http://localhost:$PORT/" && break; sleep 0.3; done
(cd "$R" && gsd-ui shots 5) > "$OUT" 2>&1; rc=$?
is "shots succeed" "$rc" 0
has "2 pages × 3 sizes" "6 screenshot(s)" "$OUT"
for f in home-375 home-768 home-1440 cart-375 cart-768 cart-1440; do
  [ -f "$PD/05-SHOTS/$f.png" ] || bad "missing $f.png"
done
[ -f "$PD/05-SHOTS/cart-1440.png" ] && ok "files named <page>-<width>.png"
grep -q -- "--viewport-size=375,812 --full-page http://localhost:$PORT/cart " "$STUB/calls.log" && ok "calls the CLI with size, full page, url" || bad "calls the CLI with size, full page, url" "$(head -2 "$STUB/calls.log")"
has "SHOTS.md records the url" "url: http://localhost:$PORT" "$PD/05-SHOTS.md"
is "PNGs are ignored by git" "$(cat "$PD/05-SHOTS/.gitignore")" "*"
git -C "$R" add -A
is "…only SHOTS.md is staged, no PNG" "$(git -C "$R" diff --cached --name-only | grep -c '\.png$')" 0
git -C "$R" reset -q

printf 'ui_url = http://127.0.0.1:{port:%s}\n' "$BASEPORT" >> "$R/.gsd.conf"
(cd "$R" && gsd-ui shots 5) > "$OUT" 2>&1
has "{port:<base>} in ui_url" "url: http://127.0.0.1:$PORT" "$PD/05-SHOTS.md"
printf 'base = develop\ninstall = none\nui_url = http://localhost:%s\n' "$PORT" > "$R/.gsd.conf"
(cd "$R" && gsd-ui shots 5) > "$OUT" 2>&1
has "a fixed ui_url works too" "url: http://localhost:$PORT" "$PD/05-SHOTS.md"
printf 'base = develop\ninstall = none\n' > "$R/.gsd.conf"

section "gsd-ui shots --skip and status"
(cd "$R" && gsd-ui shots 5 --skip "no browser on this box") > "$OUT" 2>&1
has "--skip records the reason" "skipped: no browser on this box" "$PD/05-SHOTS.md"
(cd "$R" && gsd-ui status 5) > "$OUT" 2>&1
has "status: gates"       "ui_gates    warn" "$OUT"
has "status: design"      "design      ok" "$OUT"
has "status: layout"      "layout      nosketch" "$OUT"
has "status: screenshots" "screenshots skip" "$OUT"
(cd "$R" && gsd-ui shots 5 --skip) > "$OUT" 2>&1; is "--skip needs a reason" "$?" 1

section "gsd-doctor UI checks"
D="$WORK/doc"; git init -q -b develop "$D"
mkdir -p "$D/.planning/phases/03-web" "$D/.planning/phases/04-api"
: > "$D/.planning/phases/03-web/03-UI-SPEC.md"
printf '# Roadmap\n\n### Phase 3: Web\n\n### Phase 4: Api\n' > "$D/.planning/ROADMAP.md"
printf 'base = develop\ninstall = none\n' > "$D/.gsd.conf"
git -C "$D" add -A && git -C "$D" commit -qm init
gsd-doctor --repo "$D" > "$OUT" 2>&1
has "warn: a stub/missing DESIGN.md is a note" "DESIGN.md is missing" "$OUT"
gsd-doctor --json --repo "$D" > "$OUT" 2>&1
hasnt "…not a finding" '"T080"' "$OUT"
printf 'ui_gates = strict\nui_url = http://localhost:{port}\n' >> "$D/.gsd.conf"
gsd-doctor --json --repo "$D" > "$OUT" 2>&1
has "strict: T080" '"T080"' "$OUT"
hasnt "ui_gates and ui_url are known keys" '"T017"' "$OUT"
mkdir -p "$D/.planning/design"; echo "# filled" > "$D/.planning/design/DESIGN.md"
gsd-doctor --json --repo "$D" > "$OUT" 2>&1
hasnt "a filled DESIGN.md → no T080" '"T080"' "$OUT"
printf 'base = develop\ninstall = none\nui_gates = maybe\n' > "$D/.gsd.conf"
gsd-doctor --json --repo "$D" > "$OUT" 2>&1
has "a bad ui_gates value → T018" "ui_gates = 'maybe' is not a value" "$OUT"
printf 'base = develop\ninstall = none\nui_gates = off\n' > "$D/.gsd.conf"; rm -rf "$D/.planning/design"
gsd-doctor --repo "$D" > "$OUT" 2>&1
hasnt "ui_gates = off → no UI section" "DESIGN.md" "$OUT"
B="$WORK/backend"; git init -q -b develop "$B"; mkdir -p "$B/.planning/phases/01-api"
printf '# Roadmap\n' > "$B/.planning/ROADMAP.md"; git -C "$B" add -A && git -C "$B" commit -qm init
gsd-doctor --repo "$B" > "$OUT" 2>&1
hasnt "a project without screens gets no UI notes" "DESIGN.md" "$OUT"

section "gsd-bootstrap-repo: --no-ui and the instructions"
for name in plain noui; do
  T="$WORK/$name"; git init -q -b develop "$T"; git -C "$T" commit -q --allow-empty -m init
done
(cd "$WORK/plain" && gsd-bootstrap-repo) > "$OUT" 2>&1 || bad "bootstrap runs" "$(tail -5 "$OUT")"
has "instructions carry the screens rule" "Screens: every screen uses the design system" "$WORK/plain/.gsd/INSTRUCTIONS.md"
has "the flow order names the UI steps" "design" "$WORK/plain/.gsd/INSTRUCTIONS.md"
hasnt ".gsd.conf leaves ui_gates at the default" "^ui_gates" "$WORK/plain/.gsd.conf"
[ ! -e "$WORK/plain/.planning" ] && ok "no .planning/ is created (ingest-docs would switch to merge mode)" || bad "no .planning/ is created"
(cd "$WORK/noui" && gsd-bootstrap-repo --no-ui) > "$OUT" 2>&1 || bad "bootstrap --no-ui runs" "$(tail -5 "$OUT")"
has "--no-ui writes ui_gates = off" "^ui_gates = off" "$WORK/noui/.gsd.conf"
hasnt "…and no screens rule" "Screens:" "$WORK/noui/.gsd/INSTRUCTIONS.md"
(cd "$WORK/plain" && gsd-bootstrap-repo --no-ui) > "$OUT" 2>&1
has "--no-ui on an existing .gsd.conf sets the key" "^ui_gates = off" "$WORK/plain/.gsd.conf"
hasnt "…and drops the screens rule" "Screens:" "$WORK/plain/.gsd/INSTRUCTIONS.md"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
