#!/usr/bin/env bash
# test-doctor.sh — the gsd-doctor checks added in 0.2.3: missing tools (T005,
# T006), stale skills (T007), .gsd.conf typos and bad values (T017, T018), a
# missing base branch (T015), the pre-merge gate (T019), duplicate phase
# headings (T025), failed worktree installs (T032), a ClickUp tracker with no
# token (T073), and the reinstall command it names. Also install.sh
# --reuse-install-config keeping recorded agents when --agent adds one.
# Everything runs in throwaway repos; HOME is a temp dir.
set -uo pipefail
PKG=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d); WORK=$(cd "$WORK" && pwd -P); trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"; mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GSD_NO_UPDATE_CHECK=1 GSD_CLAUDE_SKILL_DIR="$WORK/skills" GSD_CLICKUP_CONFIG="$WORK/clickup.env"
unset CLICKUP_API_TOKEN GSD_SKIP_GUARD
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ✘ %s\n' "$1"; [ $# -gt 1 ] && printf '%s\n' "$2" | sed 's/^/      /'; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { if grep -q -- "$2" "$3"; then ok "$1"; else bad "$1" "$(tail -8 "$3")"; fi; }
hasnt() { if grep -q -- "$2" "$3"; then bad "$1" "$(grep -- "$2" "$3" | head -3)"; else ok "$1"; fi; }
section() { printf '\n%s\n' "$1"; }

# A stand-in gsd-sdk so T005 only fires where a test removes it.
STUB="$WORK/stub"; mkdir -p "$STUB"
printf '#!/bin/sh\necho 1.0.0\n' > "$STUB/gsd-sdk"; chmod +x "$STUB/gsd-sdk"
BASEPATH="$PKG/bin:$PATH:$STUB"

# A PATH with every command except the named ones: a dir of links to the first
# copy of each executable on BASEPATH.
farm() {  # $1=dir  $2...=names to leave out
  local dir=$1 d f n; shift; mkdir -p "$dir"
  local IFS=:
  for d in $BASEPATH; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      n=${f##*/}
      [ -x "$f" ] && [ ! -d "$f" ] && [ ! -e "$dir/$n" ] && [ ! -L "$dir/$n" ] || continue
      case " $* " in *" $n "*) continue ;; esac
      ln -s "$f" "$dir/$n"
    done
  done
}

OUT="$WORK/out"
doc()  { PATH="${DPATH:-$BASEPATH}" gsd-doctor --repo "$1" > "$OUT" 2>&1; }
json() { PATH="${DPATH:-$BASEPATH}" gsd-doctor --json --repo "$1" > "$OUT" 2>&1; }

mkrepo() {  # $1=dir — a small GSD repo on develop with an origin
  git init -q -b develop "$1"
  mkdir -p "$1/.planning"
  printf '# Roadmap\n\n### Phase 1: One\n\n### Phase 2: Two\n' > "$1/.planning/ROADMAP.md"
  printf 'base = develop\n' > "$1/.gsd.conf"
  git -C "$1" add -A && git -C "$1" commit -qm init
  git init -q --bare "$1.origin.git"
  git -C "$1" remote add origin "$1.origin.git"
  git -C "$1" push -q -u origin develop
}
R="$WORK/repo"; mkrepo "$R"

section "missing tools"
json "$R"
hasnt "gsd-sdk on PATH → no T005" '"T005"' "$OUT"
hasnt "perl on PATH → no T006" '"T006"' "$OUT"
farm "$WORK/nosdk" gsd-sdk
DPATH="$WORK/nosdk" json "$R"
has "no gsd-sdk → T005" '"T005"' "$OUT"
has "T005 names the npm install" 'npm i -g get-shit-done-cc@latest' "$OUT"
farm "$WORK/noperl" perl
DPATH="$WORK/noperl" json "$R"
has "no perl → T006" '"T006"' "$OUT"
DPATH="$WORK/noperl" doc "$R"
has "no perl → roadmap row check is skipped, not passed" 'roadmap row check skipped' "$OUT"

section "skills (T007)"
doc "$R"
has "no skills → a note with the reinstall command" 'claude skills not installed' "$OUT"
mkdir -p "$WORK/skills"; cp -R "$PKG/skills/." "$WORK/skills/"
touch "$WORK/skills/gsd-flow/.gsd-worktrees-skill"
json "$R"
hasnt "skills same as the toolkit → no T007" '"T007"' "$OUT"
echo "old step" >> "$WORK/skills/gsd-flow/SKILL.md"
json "$R"
has "an edited skill → T007" '"T007"' "$OUT"
has "T007 names the stale skill" 'differ from this toolkit.*gsd-flow' "$OUT"
has "a checkout reinstalls with its install.sh" 'install.sh --reuse-install-config --agent claude' "$OUT"

# A release runtime has no .git: it re-runs its own get.sh for its version.
RT="$WORK/runtime"; mkdir -p "$RT"
cp -R "$PKG/bin" "$PKG/lib" "$PKG/shims" "$PKG/skills" "$PKG/install.sh" "$PKG/get.sh" "$PKG/VERSION" "$RT/"
PATH="$RT/bin:$PATH:$STUB" "$RT/bin/gsd-doctor" --json --repo "$R" > "$OUT" 2>&1
has "a release reinstalls with its get.sh and version" "get.sh --version $(cat "$PKG/VERSION") --reuse-install-config" "$OUT"
rm -rf "$WORK/skills"

section ".gsd.conf (T017, T018)"
json "$R"
hasnt "a clean .gsd.conf → no T017" '"T017"' "$OUT"
hasnt "a clean .gsd.conf → no T018" '"T018"' "$OUT"
cp "$R/.gsd.conf" "$WORK/conf.bak"
printf 'colour = red\nthis is not a setting\ntracker = none\nclaude_model = opus\n' >> "$R/.gsd.conf"
json "$R"
has "an unknown key → T017" 'unknown .gsd.conf key(s): colour' "$OUT"
has "a non key=value line → T017" '1 line(s) that are not' "$OUT"
hasnt "tracker and <provider>_model are known keys" 'key(s):[^"]*\(tracker\|claude_model\)' "$OUT"
cp "$WORK/conf.bak" "$R/.gsd.conf"
printf 'flow = on\nflow_since = soon\nstart_mode = go\n' >> "$R/.gsd.conf"
json "$R"
is "bad flow, flow_since and start_mode → 3× T018" "$(grep -o '"T018"' "$OUT" | wc -l | tr -d ' ')" 3
cp "$WORK/conf.bak" "$R/.gsd.conf"

section "base branch and origin (T015)"
printf 'base = nope\n' > "$R/.gsd.conf"
json "$R"
has "a base branch that is nowhere → T015" "base branch 'nope' does not exist" "$OUT"
git -C "$R" branch -q release && git -C "$R" push -q origin release && git -C "$R" branch -q -D release
printf 'base = release\n' > "$R/.gsd.conf"
json "$R"
has "a base only on origin → T015 with the track command" 'git branch --track release origin/release' "$OUT"
cp "$WORK/conf.bak" "$R/.gsd.conf"
json "$R"
hasnt "base present → no T015" '"T015"' "$OUT"
L="$WORK/local"; mkrepo "$L"; git -C "$L" remote remove origin
doc "$L"
has "no origin → a note" "no 'origin' remote" "$OUT"
json "$L"
hasnt "no origin is not a finding" 'origin remote' "$OUT"

section "pre-merge gate (T019)"
mkdir -p "$R/scripts"; printf '#!/bin/sh\nexit 0\n' > "$R/scripts/gsd-premerge-check.sh"
json "$R"
has "a pre-merge script that is not executable → T019" 'is not executable' "$OUT"
chmod +x "$R/scripts/gsd-premerge-check.sh"
json "$R"
hasnt "executable → no T019" '"T019"' "$OUT"
printf 'premerge = scripts/nope.sh\n' >> "$R/.gsd.conf"
json "$R"
has "a premerge path that does not exist → T019" 'premerge = scripts/nope.sh, but that file does not exist' "$OUT"
printf 'base = develop\npremerge = none\n' > "$R/.gsd.conf"
json "$R"
hasnt "premerge = none → no T019" '"T019"' "$OUT"
cp "$WORK/conf.bak" "$R/.gsd.conf"; rm -rf "$R/scripts"

section "duplicate phase headings (T025)"
cp "$R/.planning/ROADMAP.md" "$WORK/roadmap.bak"
printf '\n### Phase 02: Two again\n' >> "$R/.planning/ROADMAP.md"
json "$R"
has "Phase 2 and Phase 02 → T025" 'more than one heading for phase(s): 2' "$OUT"
cp "$WORK/roadmap.bak" "$R/.planning/ROADMAP.md"
json "$R"
hasnt "one heading per phase → no T025" '"T025"' "$OUT"

section "worktree installs (T032)"
git -C "$R" worktree add -q -b phase-1-one "$WORK/phase-1-one"
echo fail > "$WORK/phase-1-one/.gsd-install.status"
json "$R"
has "a failed install → T032" 'dependency install failed in phase-1-one' "$OUT"
echo running > "$WORK/phase-1-one/.gsd-install.status"
json "$R"
hasnt "a running install is not a finding" '"T032"' "$OUT"
doc "$R"
has "a running install is a note" 'install still running in phase-1-one' "$OUT"
git -C "$R" worktree remove --force "$WORK/phase-1-one"

section "ClickUp token (T073)"
printf 'tracker = clickup\n' >> "$R/.gsd.conf"
json "$R"
has "clickup with no token → T073" '"T073"' "$OUT"
echo 'CLICKUP_API_TOKEN=pk_test' > "$WORK/clickup.env"
json "$R"
hasnt "a token in the config file → no T073" '"T073"' "$OUT"
rm -f "$WORK/clickup.env"
CLICKUP_API_TOKEN=pk_env json "$R"
hasnt "a token in the env → no T073" '"T073"' "$OUT"
cp "$WORK/conf.bak" "$R/.gsd.conf"

section "doctor only reads"
before="$(git -C "$R" status --porcelain; git -C "$R" config --local --list | sort)"
DPATH="$WORK/nosdk" doc "$R"
is "the repo is unchanged" "$(git -C "$R" status --porcelain; git -C "$R" config --local --list | sort)" "$before"

section "--fix runs only the safe fixes, after asking"
F="$WORK/fixme"; mkrepo "$F"
git -C "$F" branch -q release && git -C "$F" push -q origin release && git -C "$F" branch -q -D release
printf 'base = release\n' > "$F/.gsd.conf"
mkdir -p "$F/scripts"; printf '#!/bin/sh\nexit 0\n' > "$F/scripts/gsd-premerge-check.sh"
mkdir -p "$F/.git/gsd-cmd.lock"; echo 999999 > "$F/.git/gsd-cmd.lock/pid"
git -C "$F" add -A && git -C "$F" commit -qm "fixture"; head_before=$(git -C "$F" rev-parse HEAD)
origin_before=$(git -C "$F.origin.git" rev-parse develop)
doc "$F"
has "without --fix it points at --fix" "gsd-doctor --fix" "$OUT"
PATH="$BASEPATH" gsd-doctor --fix --repo "$F" </dev/null > "$OUT" 2>&1
has "--fix lists what it would run" "--fix will run" "$OUT"
has "…no terminal: asks for --yes" "add --yes" "$OUT"
[ -d "$F/.git/gsd-cmd.lock" ] && ok "…and changed nothing" || bad "…and changed nothing"
PATH="$BASEPATH" gsd-doctor --fix --yes --repo "$F" > "$OUT" 2>&1
[ ! -d "$F/.git/gsd-cmd.lock" ] && ok "--yes: dead lock removed (T030)" || bad "--yes: dead lock removed (T030)" "$(tail -5 "$OUT")"
git -C "$F" show-ref --verify --quiet refs/heads/release && ok "--yes: base tracked from origin (T015)" || bad "--yes: base tracked from origin (T015)"
[ -x "$F/scripts/gsd-premerge-check.sh" ] && ok "--yes: pre-merge script made executable (T019)" || bad "--yes: pre-merge script made executable (T019)"
[ -f "$F/scripts/hooks/gsd-worktree-guard.sh" ] && ok "--yes: gsd-init ran (shims, T010)" || bad "--yes: gsd-init ran (shims, T010)"
is "--yes: nothing committed" "$(git -C "$F" rev-parse HEAD)" "$head_before"
is "--yes: nothing pushed" "$(git -C "$F.origin.git" rev-parse develop)" "$origin_before"
has "…checks again after fixing" "Checking again" "$OUT"
has "…and lists the changed files to review" "not committed" "$OUT"
json "$F"
hasnt "the safe findings are gone" '"T0\(10\|11\|12\|13\|14\|15\|19\|30\)"' "$OUT"
printf '\n### Phase 02: dup\n' >> "$F/.planning/ROADMAP.md"
PATH="$BASEPATH" gsd-doctor --fix --yes --repo "$F" > "$OUT" 2>&1
has "a judgment finding (T025) is not auto-fixed" "none of these findings has a safe automatic fix" "$OUT"
PATH="$BASEPATH" gsd-doctor --fix --json --repo "$F" > "$OUT" 2>&1
has "--fix and --json don't mix" "don't mix" "$OUT"
PATH="$BASEPATH" gsd-doctor --yes --repo "$F" > "$OUT" 2>&1
has "--yes alone is refused" "only goes with --fix" "$OUT"

section "install.sh --reuse-install-config keeps recorded agents"
export GSD_BIN_DIR="$WORK/ibin" GSD_CODEX_SKILL_DIR="$WORK/codex-skills"
export GSD_CLAUDE_SKILL_DIR="$WORK/claude-skills"
(cd "$PKG" && ./install.sh --agent claude) > "$OUT" 2>&1 || bad "first install" "$(tail -5 "$OUT")"
(cd "$PKG" && ./install.sh --reuse-install-config --agent codex) > "$OUT" 2>&1 || bad "reuse install" "$(tail -5 "$OUT")"
prov=$(awk -F'\t' '$1 == "providers" { print $2 }' "$GSD_BIN_DIR/.gsd-install-manifest")
case ",$prov," in *,claude,*) ok "claude is kept" ;; *) bad "claude is kept" "providers: $prov" ;; esac
case ",$prov," in *,codex,*) ok "codex is added" ;; *) bad "codex is added" "providers: $prov" ;; esac
[ -f "$GSD_CODEX_SKILL_DIR/gsd-flow/SKILL.md" ] && ok "codex skills installed" || bad "codex skills installed"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
