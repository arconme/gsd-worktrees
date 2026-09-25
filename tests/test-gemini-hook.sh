#!/usr/bin/env bash
set -uo pipefail

PKG=$(cd "$(dirname "$0")/.." && pwd)
GUARD="$PKG/bin/gsd-worktree-guard"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0

check() {  # label expected_exit payload
  local got
  printf '%s' "$3" | GEMINI_PROJECT_DIR="$WORK/main" "$GUARD" >"$WORK/out" 2>"$WORK/err"
  got=$?
  if [ "$got" -eq "$2" ]; then PASS=$((PASS + 1)); printf '  ✔ %s\n' "$1"
  else FAIL=$((FAIL + 1)); printf '  ✘ %s: expected %s, got %s: %s\n' "$1" "$2" "$got" "$(cat "$WORK/err")"; fi
}

mkdir -p "$WORK/main" "$WORK/phase"
git -C "$WORK/main" init -q -b develop
git -C "$WORK/main" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$WORK/main" worktree add -q -b phase-7-feature "$WORK/phase"
printf 'base = develop\ninstall = none\n' > "$WORK/main/.gsd.conf"

check 'skill phase on main blocked' 2 '{"tool_name":"activate_skill","tool_input":{"name":"gsd-plan-phase","args":"7"}}'
check 'skill phase in matching directory allowed' 0 "{\"tool_name\":\"activate_skill\",\"tool_input\":{\"name\":\"/gsd-plan-phase\",\"args\":\"7\",\"directory\":\"$WORK/phase\"}}"
check 'skill wrong phase in directory blocked' 2 "{\"tool_name\":\"activate_skill\",\"tool_input\":{\"name\":\"gsd-plan-phase\",\"args\":\"8\",\"directory\":\"$WORK/phase\"}}"
check 'direct shell phase on main blocked' 2 '{"tool_name":"run_shell_command","tool_input":{"command":"gsd-flow-next 7"}}'
check 'direct shell phase in cwd allowed' 0 "{\"tool_name\":\"run_shell_command\",\"cwd\":\"$WORK/phase\",\"tool_input\":{\"command\":\"./bin/gsd-flow-next 7\"}}"
check 'shell repo flag selects phase worktree' 0 "{\"tool_name\":\"run_shell_command\",\"tool_input\":{\"command\":\"gsd-flow-next --repo '$WORK/phase' 7\"}}"
check 'shell repo flag selects main and blocks' 2 "{\"tool_name\":\"run_shell_command\",\"cwd\":\"$WORK/phase\",\"tool_input\":{\"command\":\"gsd-flow-next --repo '$WORK/main' 7\"}}"
check 'compound GSD command blocked' 2 '{"tool_name":"run_shell_command","tool_input":{"command":"true && gsd-flow-next 7"}}'
check 'newline compound GSD command blocked' 2 '{"tool_name":"run_shell_command","tool_input":{"command":"gsd-flow-next 7\npwd"}}'
check 'shell wrapper around GSD blocked' 2 '{"tool_name":"run_shell_command","tool_input":{"command":"bash -c \"gsd-flow-next 7\""}}'
check 'quoted mention in another command conservatively blocked' 2 '{"tool_name":"run_shell_command","tool_input":{"command":"echo gsd-flow-next"}}'
check 'malformed Gemini payload blocked' 2 '{"tool_name":"run_shell_command","tool_input":{"command":42}}'
check 'unrelated shell command allowed' 0 '{"tool_name":"run_shell_command","tool_input":{"command":"pwd"}}'
check 'non-phase GSD launcher delegated to its own guard' 0 '{"tool_name":"run_shell_command","tool_input":{"command":"gsd-start -p 7"}}'

printf 'flow = strict\n' >> "$WORK/main/.gsd.conf"
check 'skill without phase infers phase and enforces strict flow' 2 "{\"tool_name\":\"activate_skill\",\"cwd\":\"$WORK/phase\",\"tool_input\":{\"name\":\"gsd-plan-phase\"}}"
mkdir -p "$WORK/phase/.planning/phases/07-feature"
: > "$WORK/phase/.planning/phases/07-feature/07-CONTEXT.md"
check 'skill without phase permits completed prerequisite' 0 "{\"tool_name\":\"activate_skill\",\"cwd\":\"$WORK/phase\",\"tool_input\":{\"name\":\"gsd-plan-phase\"}}"

# A missing or crashed parser must produce an empty result, which the hook
# treats as a block even on Bash 3 with nounset enabled.
mkdir -p "$WORK/broken/bin" "$WORK/broken/lib"
cp "$GUARD" "$WORK/broken/bin/gsd-worktree-guard"
cp "$PKG/lib/common.sh" "$WORK/broken/lib/common.sh"
printf '%s' '{"tool_name":"activate_skill","tool_input":{"name":"gsd-plan-phase","args":"7"}}' \
  | GEMINI_PROJECT_DIR="$WORK/main" bash "$WORK/broken/bin/gsd-worktree-guard" >"$WORK/out" 2>"$WORK/err"
got=$?
if [ "$got" -eq 2 ]; then PASS=$((PASS + 1)); printf '  ✔ missing parser blocks\n'
else FAIL=$((FAIL + 1)); printf '  ✘ missing parser: expected 2, got %s\n' "$got"; fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
