#!/usr/bin/env bash
# shellcheck disable=SC2034 # assertion strings intentionally expand test variables via eval
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); PKG=$(cd "$HERE/.." && pwd)
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ✔ %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf '  ✘ %s\n' "$1"; }
assert(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
repo(){ mkdir -p "$1"; git -C "$1" init -q -b develop; git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; }
export PATH="$PKG/bin:$WORK/fakebin:$PATH"; mkdir -p "$WORK/fakebin"
for x in claude codex gemini; do printf '#!/bin/sh\nprintf "%%s\\n" "$@"\n' > "$WORK/fakebin/$x"; chmod +x "$WORK/fakebin/$x"; done
. "$PKG/lib/common.sh"; . "$PKG/lib/provider.sh"

echo 'configuration and rendering'
R=$WORK/config; repo "$R"; printf 'provider = gemini\nagent_command = gem-x\n' > "$R/.gsd.conf"
gsd_provider_resolve "$R" "" ""; assert 'legacy provider still resolves' '[ "$GSD_PROVIDER_RESOLVED:$GSD_AGENT_COMMAND_RESOLVED" = gemini:gem-x ]'
printf 'provider = claude\nproviders = gemini,codex\nagent_command = gem-x\n' > "$R/.gsd.conf"
gsd_provider_resolve "$R" "" ""; assert 'ordered providers overrides legacy provider' '[ "$GSD_PROVIDER_RESOLVED:$GSD_AGENT_COMMAND_RESOLVED" = gemini:gem-x ]'
GSD_PROVIDER=codex GSD_AGENT_COMMAND=codex-x gsd_provider_resolve "$R" "" ""; assert 'environment overrides repo' '[ "$GSD_PROVIDER_RESOLVED:$GSD_AGENT_COMMAND_RESOLVED" = codex:codex-x ]'
GSD_PROVIDER=codex GSD_AGENT_COMMAND=codex-x gsd_provider_resolve "$R" claude /tmp/claude-x; assert 'CLI overrides environment' '[ "$GSD_PROVIDER_RESOLVED:$GSD_AGENT_COMMAND_RESOLVED" = claude:/tmp/claude-x ]'
gsd_provider_resolve "$R" nope "" >/dev/null 2>&1; assert 'unknown provider rejected' '[ $? -eq 64 ]'
gsd_provider_resolve "$R" custom 'bad command' >/dev/null 2>&1; assert 'shell template rejected' '[ $? -eq 64 ]'
gsd_start_mode_resolve "$R" ""; assert 'start mode compatibility default is discuss' '[ "$GSD_START_MODE_RESOLVED" = discuss ]'
printf 'start_mode = flow\n' >> "$R/.gsd.conf"; gsd_start_mode_resolve "$R" ""; assert 'repository start mode selects flow' '[ "$GSD_START_MODE_RESOLVED" = flow ]'
gsd_start_mode_resolve "$R" discuss; assert 'CLI start mode overrides repository' '[ "$GSD_START_MODE_RESOLVED" = discuss ]'
printf 'start_mode = invalid\n' > "$R/.gsd.conf"; gsd_start_mode_resolve "$R" "" >/dev/null 2>&1; assert 'invalid start mode rejected' '[ $? -eq 64 ]'
for p in claude codex gemini; do prompt=$(gsd_provider_prompt "$p" discuss 7); gsd_provider_argv "$p" "$p" "$prompt"; "$WORK/fakebin/$p" "${GSD_LAUNCH_ARGV[@]:1}" > "$WORK/$p-discuss.args"; prompt=$(gsd_provider_prompt "$p" flow 7); gsd_provider_argv "$p" "$p" "$prompt"; "$WORK/fakebin/$p" "${GSD_LAUNCH_ARGV[@]:1}" > "$WORK/$p-flow.args"; done
assert 'Claude discuss prompt remains backward compatible' "grep -q '^/gsd-discuss-phase 7$' '$WORK/claude-discuss.args'"
assert 'Claude flow prompt is explicit' "grep -q '^/gsd-flow 7$' '$WORK/claude-flow.args'"
assert 'Codex discuss prompt is natural language' "grep -q 'Discuss GSD phase 7' '$WORK/codex-discuss.args'"
assert 'Codex flow prompt is natural language' "grep -q 'gsd-flow skill' '$WORK/codex-flow.args'"
assert 'Gemini uses prompt-interactive for discuss' "grep -q '^--prompt-interactive$' '$WORK/gemini-discuss.args'"
assert 'Gemini uses prompt-interactive for flow' "grep -q '^--prompt-interactive$' '$WORK/gemini-flow.args'"
render=$(gsd_provider_render '/tmp/a b' fake 'quote " and $ safe'); assert 'rendering shell-quotes cwd and prompt' "printf '%s' \"\$render\" | grep -q '/tmp/a\\\\ b'"
assert 'missing executable still renders in print-only mode' "! command -v provider-does-not-exist >/dev/null && [ -n \"\$(gsd_provider_render /tmp provider-does-not-exist prompt)\" ]"
printf 'providers = claude,codex,gemini\nagent_command = default-claude\nclaude_command = custom-claude\ncodex_command = custom-codex\ngemini_command = custom-gemini\n' > "$R/.gsd.conf"
for spec in claude:custom-claude codex:custom-codex gemini:custom-gemini; do p=${spec%%:*}; want=${spec#*:}; gsd_provider_resolve "$R" "$p" ""; assert "$p uses its own command in one repo" '[ "$GSD_AGENT_COMMAND_RESOLVED" = "$want" ]'; done

echo 'gsd-start discuss/flow selection'
echo 'complete provider-list validation'
R=$WORK/invalid-list; repo "$R"
for invalid in 'claude,unknown-provider' 'claude,,codex' 'claude,' ',codex' 'claude,claude' 'claude, codex' ''; do
  printf 'providers = %s\n' "$invalid" > "$R/.gsd.conf"
  gsd_provider_resolve "$R" claude '' >/dev/null 2>&1
  assert "invalid full list rejected: [$invalid]" '[ $? -eq 64 ]'
done
printf 'providers = claude,unknown-provider\n' > "$R/.gsd.conf"
mkdir -p "$R/.planning"; printf '### Phase 7: Test\n' > "$R/.planning/ROADMAP.md"
for p in claude codex gemini; do
  gsd-start -p 7 --repo "$R" --provider "$p" --no-launch >/dev/null 2>&1; rc=$?
  assert "$p launch rejects invalid list before worktree creation" '[ "$rc" -eq 64 ] && [ "$(git -C "$R" worktree list --porcelain | grep -c "^worktree ")" -eq 1 ]'
done
out=$(gsd-doctor --repo "$R" --json 2>/dev/null || true)
assert 'doctor reports invalid secondary provider' 'printf "%s" "$out" | jq -e '\''any(.findings[]; .code == "T050")'\'' >/dev/null'

echo 'generated instructions follow effective repository settings'
R=$WORK/custom-layout; repo "$R"; git -C "$R" branch release
printf 'providers = codex\nbase = release\nwtdir = custom-trees\ninstall = none\n' > "$R/.gsd.conf"
(cd "$R" && gsd-init --no-commit --no-launch) >/dev/null
assert 'instructions use configured base' 'grep -q "base .release." "$R/.gsd/INSTRUCTIONS.md"'
assert 'instructions use configured worktree directory' 'grep -q "../custom-trees/" "$R/.gsd/INSTRUCTIONS.md"'
before=$(cksum "$R/.gsd.conf" "$R/.gsd/INSTRUCTIONS.md")
(cd "$R" && gsd-init --no-commit --no-launch) >/dev/null
assert 'custom layout rerun is idempotent' '[ "$before" = "$(cksum "$R/.gsd.conf" "$R/.gsd/INSTRUCTIONS.md")" ]'
(cd "$R" && gsd-init --base develop --no-commit --no-launch) >/dev/null
assert 'explicit base overrides configuration and instructions together' '[ "$(gsd_base "$R")" = develop ] && grep -q "base .develop." "$R/.gsd/INSTRUCTIONS.md"'

echo 'model selection and safe argv'
R=$WORK/models; repo "$R"
printf 'claude_model = claude-test\ncodex_model = codex-test\ngemini_model = gemini-test\n' > "$R/.gsd.conf"
for p in claude codex gemini; do
  gsd_model_resolve "$R" "$p" ""
  assert "$p resolves its own model" '[ "$GSD_MODEL_RESOLVED" = "$p-test" ]'
  gsd_provider_argv "$p" "$WORK/fakebin/$p" 'prompt with spaces' "$GSD_MODEL_RESOLVED"
  actual=$("${GSD_LAUNCH_ARGV[@]}")
  expected=$(printf '%s\n' --model "$p-test"; [ "$p" != gemini ] || printf '%s\n' --prompt-interactive; printf '%s\n' 'prompt with spaces')
  assert "$p receives exact model and prompt arguments" '[ "$actual" = "$expected" ]'
done
GSD_CODEX_MODEL=env-test gsd_model_resolve "$R" codex ""; assert 'provider model environment overrides config' '[ "$GSD_MODEL_RESOLVED" = env-test ]'
GSD_MODEL=global-test GSD_CODEX_MODEL=env-test gsd_model_resolve "$R" codex ""; assert 'session model environment overrides provider environment' '[ "$GSD_MODEL_RESOLVED" = global-test ]'
GSD_MODEL=global-test gsd_model_resolve "$R" codex cli-test; assert 'model CLI overrides environment' '[ "$GSD_MODEL_RESOLVED" = cli-test ]'
GSD_MODEL=global-test gsd_model_resolve "$R" codex default; assert 'explicit default clears model override' '[ -z "$GSD_MODEL_RESOLVED" ]'
gsd_provider_argv codex codex prompt "$GSD_MODEL_RESOLVED"; assert 'default emits no model flag' '[ "${#GSD_LAUNCH_ARGV[@]}" -eq 2 ]'
gsd_model_resolve "$R" custom unsupported >/dev/null 2>&1; assert 'custom model override is rejected' '[ $? -eq 64 ]'
gsd_model_resolve "$R" codex '--bad' >/dev/null 2>&1; assert 'model option injection rejected' '[ $? -eq 64 ]'
gsd_model_resolve "$R" codex 'two words' >/dev/null 2>&1; assert 'model whitespace rejected' '[ $? -eq 64 ]'
model_literal='model;$(touch never-created)'
gsd_model_validate codex "$model_literal" >/dev/null 2>&1; assert 'model command template with whitespace rejected' '[ $? -eq 64 ]'
model_literal='model;$(id)'
gsd_provider_argv codex "$WORK/fakebin/codex" prompt "$model_literal"
actual=$("${GSD_LAUNCH_ARGV[@]}"); expected=$(printf '%s\n' --model "$model_literal" prompt)
assert 'shell metacharacters remain a literal model argument' '[ "$actual" = "$expected" ]'
R=$WORK/init-model-invalid; repo "$R"; (cd "$R" && gsd-init --provider codex --model '--bad' --no-launch --no-commit) >/dev/null 2>&1
assert 'invalid init model fails before bootstrap writes' '[ $? -ne 0 ] && [ ! -e "$R/.gsd.conf" ]'
R=$WORK/init-model; repo "$R"; out=$(cd "$R" && gsd-init --new --provider codex --model model-test --no-launch --no-commit 2>&1)
assert 'init prints selected session model' '[[ "$out" == *"codex --model model-test"* ]]'
R=$WORK/start-mode; repo "$R"; mkdir -p "$R/.planning"; printf '# Roadmap\n\n### Phase 7: Test phase\n' > "$R/.planning/ROADMAP.md"; printf 'base = develop\nwtdir = start-worktrees\ninstall = none\nproviders = claude\n' > "$R/.gsd.conf"; git -C "$R" add .; git -C "$R" -c user.name=t -c user.email=t@t commit -qm planning
out=$(gsd-start -p 7 --repo "$R" --provider custom --agent-command fake-provider --no-launch 2>&1); assert 'gsd-start defaults to discuss-only' "printf '%s' \"\$out\" | grep -q 'fake-provider Discuss.*GSD.*phase.*7'"; assert 'gsd-start suppresses stale worker next steps' "! printf '%s' \"\$out\" | grep -q 'Open an agent session there'"
printf 'start_mode = flow\n' >> "$R/.gsd.conf"; out=$(gsd-start -p 7 --repo "$R" --provider custom --agent-command fake-provider --no-launch 2>&1); assert 'gsd-start honors repository flow mode' "printf '%s' \"\$out\" | grep -q 'fake-provider Drive.*GSD.*phase.*7'"
out=$(gsd-start -p 7 --repo "$R" --provider custom --agent-command fake-provider --flow --no-flow --no-launch 2>&1); assert '--no-flow overrides earlier --flow' "printf '%s' \"\$out\" | grep -q 'fake-provider Discuss.*GSD.*phase.*7'"
out=$(gsd-start -p 7 --repo "$R" --provider custom --agent-command fake-provider --no-flow --flow --no-launch 2>&1); assert '--flow overrides earlier --no-flow' "printf '%s' \"\$out\" | grep -q 'fake-provider Drive.*GSD.*phase.*7'"

echo 'bootstrap adapters and idempotence'
out=$(gsd-start -p 7 --repo "$R" --provider codex --model model-test --no-launch 2>&1)
assert 'start prints selected session model' '[[ "$out" == *"codex --model model-test"* ]]'

echo 'flow launch guard for every provider'
WT=$(git -C "$R" worktree list --porcelain | sed -n 's/^worktree //p' | tail -1)
mkdir -p "$WT/.planning/phases/07-test"
for artifact in TICKET CONTEXT REVIEWS; do : > "$WT/.planning/phases/07-test/07-$artifact.md"; done
: > "$WT/.planning/phases/07-test/07-01-PLAN.md"
git -C "$WT" add .planning
git -C "$WT" -c user.name=t -c user.email=t@t commit -qm ready
printf 'base = develop\nflow = strict\ninstall = npm install\n' > "$WT/.gsd.conf"
echo running > "$WT/.gsd-install.status"
mkdir -p "$WT/node_modules"
for p in claude codex gemini; do
  out=$(gsd-start -p 7 --repo "$R" --provider "$p" --flow --no-launch 2>&1); rc=$?
  assert "$p flow launch blocks pending install" '[ "$rc" -eq 2 ] && [[ "$out" != *"Next:  cd"* ]]'
done
echo ok > "$WT/.gsd-install.status"
for p in claude codex gemini; do
  out=$(gsd-start -p 7 --repo "$R" --provider "$p" --flow --no-launch 2>&1); rc=$?
  assert "$p flow launch permits completed install" '[ "$rc" -eq 0 ] && [[ "$out" == *"Next:  cd"* ]]'
done
for p in claude codex gemini; do
  R=$WORK/$p; repo "$R"; printf 'user content %s\n' "$p" > "$R/$(gsd_provider_instruction_file "$p")"
  (cd "$R" && gsd-bootstrap-repo --agent "$p") >/dev/null
  assert "$p canonical instructions" "grep -q 'gsd-worktrees:canonical' '$R/.gsd/INSTRUCTIONS.md'"
  assert "$p preserves unrelated instructions" "grep -q 'user content $p' '$R/$(gsd_provider_instruction_file "$p")'"
  assert "$p owns one marked block" "[ \"\$(grep -c 'provider:start' '$R/$(gsd_provider_instruction_file "$p")')\" -eq 1 ]"
  before=$(cksum "$R/.gsd/INSTRUCTIONS.md" "$R/$(gsd_provider_instruction_file "$p")"); (cd "$R" && gsd-bootstrap-repo --agent "$p") >/dev/null; after=$(cksum "$R/.gsd/INSTRUCTIONS.md" "$R/$(gsd_provider_instruction_file "$p")")
  assert "$p repeated bootstrap idempotent" '[ "$before" = "$after" ]'
done
assert 'Codex creates no Claude integration' "[ ! -e '$WORK/codex/CLAUDE.md' ] && [ ! -e '$WORK/codex/.claude/settings.json' ]"
assert 'Gemini creates no Claude integration' "[ ! -e '$WORK/gemini/CLAUDE.md' ] && [ ! -e '$WORK/gemini/.claude/settings.json' ]"
assert 'Claude native hook present' "grep -q gsd-worktree-guard '$WORK/claude/.claude/settings.json'"
assert 'Gemini native hook present' "grep -q gsd-worktree-guard '$WORK/gemini/.gemini/settings.json'"
R=$WORK/multi; repo "$R"; printf 'claude user\n' > "$R/CLAUDE.md"; printf 'codex user\n' > "$R/AGENTS.md"; printf 'gemini user\n' > "$R/GEMINI.md"; (cd "$R" && gsd-bootstrap-repo --agents claude,codex,gemini) >/dev/null
assert 'multi-provider config' "grep -q '^providers = claude,codex,gemini$' '$R/.gsd.conf'"
assert 'new config does not duplicate provider default' "! grep -q '^provider =' '$R/.gsd.conf'"
assert 'multi-provider files preserved' "grep -q 'claude user' '$R/CLAUDE.md' && grep -q 'codex user' '$R/AGENTS.md' && grep -q 'gemini user' '$R/GEMINI.md'"
R=$WORK/multi-commands; repo "$R"; (cd "$R" && gsd-bootstrap-repo --agents claude,codex,gemini --provider-command claude=claude-x --provider-command codex=codex-x --provider-command gemini=gemini-x) >/dev/null
assert 'bootstrap stores per-provider commands' "grep -q '^claude_command = claude-x$' '$R/.gsd.conf' && grep -q '^codex_command = codex-x$' '$R/.gsd.conf' && grep -q '^gemini_command = gemini-x$' '$R/.gsd.conf'"
for p in claude codex gemini; do gsd_provider_resolve "$R" "$p" ""; prompt=$(gsd_provider_prompt "$p" discuss 7); gsd_provider_argv "$p" "$GSD_AGENT_COMMAND_RESOLVED" "$prompt"; same_phase=$(gsd_provider_render "$R/phase-7-shared" "${GSD_LAUNCH_ARGV[@]}"); assert "same phase renders $p adapter" "printf '%s' \"\$same_phase\" | grep -q '$p-x'"; done
R=$WORK/legacy; repo "$R"; printf 'before\n## GSD planning system\nlegacy toolkit scripts/hooks/gsd-worktree-guard.sh\nrepo-specific policy\n## User section\nkeep me\n' > "$R/CLAUDE.md"; cp "$R/CLAUDE.md" "$R/CLAUDE.before"; (cd "$R" && gsd-bootstrap-repo --agent claude) >/dev/null
assert 'legacy Claude instructions preserved byte-for-byte' "head -n 6 '$R/CLAUDE.md' | cmp -s - '$R/CLAUDE.before'"
assert 'legacy Claude repository policy remains active' "grep -q 'repo-specific policy' '$R/CLAUDE.md' && grep -q 'keep me' '$R/CLAUDE.md'"
assert 'legacy Claude gets one marked canonical adapter' "[ \"\$(grep -c 'gsd-worktrees:provider:start' '$R/CLAUDE.md')\" -eq 1 ] && grep -q 'supersede older unmarked GSD text' '$R/CLAUDE.md'"
assert 'legacy Claude migration creates no backup debris' "[ ! -e '$R/CLAUDE.md.gsd-legacy.bak' ]"
R=$WORK/legacy-config; repo "$R"; printf 'base = develop\nprovider = codex\ncustom_setting = keep\n' > "$R/.gsd.conf"; (cd "$R" && gsd-bootstrap-repo) >/dev/null
assert 'legacy provider migrates to providers' "grep -q '^providers = codex$' '$R/.gsd.conf' && ! grep -q '^provider =' '$R/.gsd.conf'"
assert 'legacy provider migration preserves unrelated config' "grep -q '^custom_setting = keep$' '$R/.gsd.conf'"
R=$WORK/bad-json; repo "$R"; mkdir -p "$R/.claude"; printf '{not json\n' > "$R/.claude/settings.json"; sum=$(cksum "$R/.claude/settings.json"); (cd "$R" && gsd-bootstrap-repo --agent claude) >/dev/null; assert 'malformed provider settings preserved' '[ "$sum" = "$(cksum "$R/.claude/settings.json")" ]'

echo 'init launch failure and print-only fallback'
R=$WORK/init-print; repo "$R"; out=$(cd "$R" && gsd-init --new --provider custom --agent-command provider-does-not-exist --no-launch --no-commit 2>&1); rc=$?; assert 'print-only succeeds without provider executable' '[ "$rc" -eq 0 ]'; assert 'print-only prints safely rendered command' "printf '%s' \"\$out\" | grep -q 'provider-does-not-exist'"
R=$WORK/init-launch; repo "$R"; (cd "$R" && gsd-init --new --provider custom --agent-command provider-does-not-exist --launch --no-commit) >/dev/null 2>&1; assert 'launch fails safely when executable is missing' '[ $? -eq 127 ]'

echo 'multi-provider init'
R=$WORK/init-multi; repo "$R"; out=$(cd "$R" && gsd-init --new --providers claude,codex,gemini --provider codex --provider-command codex=codex-special --no-launch --no-commit 2>&1)
assert 'init writes explicit provider set' "grep -q '^providers = claude,codex,gemini$' '$R/.gsd.conf'"
assert 'init installs every selected adapter' "grep -q 'provider:start' '$R/CLAUDE.md' && grep -q 'provider:start' '$R/AGENTS.md' && grep -q 'provider:start' '$R/GEMINI.md'"
assert 'init renders selected provider command' "printf '%s' \"\$out\" | grep -q 'codex-special'"
R=$WORK/init-default-provider; repo "$R"; out=$(cd "$R" && gsd-init --new --providers gemini,codex --provider-command gemini=gemini-special --no-launch --no-commit 2>&1)
assert 'init defaults session to first listed provider' "printf '%s' \"\$out\" | grep -q 'gemini-special --prompt-interactive'"
R=$WORK/init-selected-command; repo "$R"; (cd "$R" && gsd-init --new --providers claude,codex --provider codex --agent-command codex-selected --no-launch --no-commit) >/dev/null
assert 'legacy command flag targets selected provider' "grep -q '^codex_command = codex-selected$' '$R/.gsd.conf' && ! grep -q '^agent_command =' '$R/.gsd.conf'"
R=$WORK/init-invalid-selection; repo "$R"; (cd "$R" && gsd-init --new --providers claude,gemini --provider codex --no-launch --no-commit) >/dev/null 2>&1; assert 'init rejects launch provider outside set' '[ $? -ne 0 ] && [ ! -e "$R/.gsd.conf" ]'
R=$WORK/init-invalid-command; repo "$R"; (cd "$R" && gsd-init --new --providers claude,gemini --provider-command codex=codex-x --no-launch --no-commit) >/dev/null 2>&1; assert 'init rejects command override outside set' '[ $? -ne 0 ] && [ ! -e "$R/.gsd.conf" ]'

echo 'installer isolation and preservation'
echo 'migration and malformed instruction regressions'
R=$WORK/switch-executable; repo "$R"
printf 'providers = claude\nagent_command = claude-special\n' > "$R/.gsd.conf"
(cd "$R" && gsd-bootstrap-repo --agent codex) >/dev/null
gsd_provider_resolve "$R" '' ''
assert 'provider switch does not reuse previous executable' '[ "$GSD_PROVIDER_RESOLVED:$GSD_AGENT_COMMAND_RESOLVED" = codex:codex ]'
gsd_provider_resolve "$R" claude ''
assert 'migration preserves previous provider executable' '[ "$GSD_AGENT_COMMAND_RESOLVED" = claude-special ]'
before=$(cksum "$R/.gsd.conf"); (cd "$R" && gsd-bootstrap-repo) >/dev/null
assert 'executable migration is idempotent' '[ "$before" = "$(cksum "$R/.gsd.conf")" ]'
R=$WORK/override-set; repo "$R"
printf 'providers = claude,codex\nclaude_command = old-claude\n' > "$R/.gsd.conf"
(cd "$R" && gsd-init --provider-command codex=codex-special --no-commit --no-launch) >/dev/null
assert 'command override preserves configured provider set' "grep -q '^providers = claude,codex$' '$R/.gsd.conf'"
(cd "$R" && gsd-bootstrap-repo --agent-command new-claude) >/dev/null
gsd_provider_resolve "$R" claude ''
assert 'explicit command overrides old provider-specific setting' '[ "$GSD_AGENT_COMMAND_RESOLVED" = new-claude ]'
R=$WORK/custom-repeat; repo "$R"
(cd "$R" && gsd-bootstrap-repo --agent custom --agent-command custom-cli) >/dev/null
(cd "$R" && gsd-bootstrap-repo) >/dev/null
assert 'custom bootstrap can reuse saved executable' '[ $? -eq 0 ]'
for p in claude codex gemini; do
  for shape in unmatched reversed duplicate nested inline; do
    R=$WORK/markers-$p-$shape; repo "$R"
    instruction_file="$R/$(gsd_provider_instruction_file "$p")"
    start='<!-- gsd-worktrees:provider:start -->'; end='<!-- gsd-worktrees:provider:end -->'
    case "$shape" in
      unmatched) printf '%s\n' "$start" 'user policy' > "$instruction_file" ;;
      reversed) printf '%s\n' "$end" 'user policy' "$start" > "$instruction_file" ;;
      duplicate) printf '%s\n' "$start" "$end" 'user policy' "$start" "$end" > "$instruction_file" ;;
      nested) printf '%s\n' "$start" "$start" 'user policy' "$end" "$end" > "$instruction_file" ;;
      inline) printf '%s\n' "user policy $start" "$end" > "$instruction_file" ;;
    esac
    before=$(cksum "$instruction_file")
    (cd "$R" && gsd-bootstrap-repo --agent "$p") >/dev/null 2>&1; rc=$?
    assert "$p $shape markers fail without changing files" '[ "$rc" -ne 0 ] && [ "$before" = "$(cksum "$instruction_file")" ] && [ ! -e "$R/.gsd.conf" ]'
  done
done
R=$WORK/owned-block-bytes; repo "$R"
printf 'user prefix\n<!-- gsd-worktrees:provider:start -->\nold owned block\n<!-- gsd-worktrees:provider:end -->\nuser tail' > "$R/AGENTS.md"
(cd "$R" && gsd-bootstrap-repo --agent codex) >/dev/null
assert 'owned-block update preserves user suffix without newline' '[ "$(tail -c 9 "$R/AGENTS.md")" = "user tail" ]'
before=$(cksum "$R/AGENTS.md"); (cd "$R" && gsd-bootstrap-repo --agent codex) >/dev/null
assert 'byte-preserving owned update is idempotent' '[ "$before" = "$(cksum "$R/AGENTS.md")" ]'
mkdir -p "$WORK/skills/claude/gsd-flow"; echo mine > "$WORK/skills/claude/gsd-flow/user.txt"
GSD_BIN_DIR=$WORK/bin GSD_CLAUDE_SKILL_DIR=$WORK/skills/claude GSD_CODEX_SKILL_DIR=$WORK/skills/codex GSD_GEMINI_SKILL_DIR=$WORK/skills/gemini "$PKG/install.sh" --all-agents >/dev/null
for p in claude codex gemini; do assert "$p skills installed" "[ -e '$WORK/skills/$p/gsd-flow/SKILL.md' ]"; done
assert 'real skill directory preserved as backup' "[ -f '$WORK/skills/claude/gsd-flow.bak/user.txt' ]"
GSD_BIN_DIR=$WORK/bin GSD_CLAUDE_SKILL_DIR=$WORK/skills/claude "$PKG/install.sh" --agent claude >/dev/null
assert 'repeated skill install stays usable' "[ -e '$WORK/skills/claude/gsd-flow/SKILL.md' ]"
mkdir -p "$WORK/skills-link/codex"; ln -s /tmp/unrelated-skill "$WORK/skills-link/codex/gsd-flow"
GSD_BIN_DIR=$WORK/bin2 GSD_CODEX_SKILL_DIR=$WORK/skills-link/codex "$PKG/install.sh" --agent codex >/dev/null
assert 'unrelated existing symlink preserved as backup' "[ -L '$WORK/skills-link/codex/gsd-flow.bak' ]"

echo 'provider-neutral guard and doctor'
printf 'codex_model = model-test\n' >> "$WORK/codex/.gsd.conf"
out=$(gsd-doctor --repo "$WORK/codex" --json 2>/dev/null || true)
assert 'doctor JSON reports resolved model' 'printf "%s" "$out" | jq -e '\''.session_model == "model-test"'\'' >/dev/null'
printf 'gemini_model = --invalid\n' >> "$WORK/gemini/.gsd.conf"
out=$(gsd-doctor --repo "$WORK/gemini" --json 2>/dev/null || true)
assert 'doctor reports invalid model configuration' 'printf "%s" "$out" | jq -e '\''any(.findings[]; .code == "T059")'\'' >/dev/null'
for p in claude codex gemini; do
  R=$WORK/guard-$p; repo "$R"; git -C "$R" checkout -q -b phase-7-test; mkdir -p "$R/.planning/phases/07-test"; printf 'providers = %s\nflow = strict\ninstall = none\n' "$p" > "$R/.gsd.conf"
  "$PKG/bin/gsd-worktree-guard" --command gsd-plan-phase --phase 7 --repo "$R" >/dev/null 2>&1; assert "$p strict flow blocks missing discuss" '[ $? -eq 2 ]'
  : > "$R/.planning/phases/07-test/07-CONTEXT.md"; "$PKG/bin/gsd-worktree-guard" --command gsd-plan-phase --phase 7 --repo "$R" >/dev/null 2>&1; assert "$p strict flow permits completed discuss" '[ $? -eq 0 ]'
  git -C "$R" checkout -q develop; "$PKG/bin/gsd-worktree-guard" --command gsd-plan-phase --phase 7 --repo "$R" >/dev/null 2>&1; assert "$p base branch remains blocked" '[ $? -eq 2 ]'
done
for p in claude codex gemini; do out=$(gsd-doctor --repo "$WORK/$p" --json 2>/dev/null || true); assert "$p doctor JSON provider" "printf '%s' \"\$out\" | grep -q '\"name\":\"$p\"'"; assert "$p doctor reports command guard" "printf '%s' \"\$out\" | grep -q '\"command_guard\":true'"; assert "$p doctor has no false duplicate-block finding" "! printf '%s' \"\$out\" | grep -q '\"code\":\"T055\"'"; done
out=$(gsd-doctor --repo "$WORK/multi" --json 2>/dev/null || true); assert 'doctor reports all configured providers' "printf '%s' \"\$out\" | grep -q '\"configured\":\[\"claude\",\"codex\",\"gemini\"\]'"
assert 'Codex reports unsupported native hook' "printf '%s' \"\$(gsd-doctor --repo '$WORK/codex' --json 2>/dev/null || true)\" | grep -q '\"native_hook\":\"unsupported\"'"
mv "$WORK/gemini/.gemini/settings.json" "$WORK/gemini/.gemini/settings.saved"; out=$(gsd-doctor --repo "$WORK/gemini" --json 2>/dev/null || true); assert 'doctor reports absent supported native hook' "printf '%s' \"\$out\" | grep -q '\"native_hook\":\"absent\"'"
printf 'providers = invalid\n' > "$WORK/codex/.gsd.conf"; out=$(gsd-doctor --repo "$WORK/codex" --json 2>/dev/null || true); assert 'doctor JSON reports invalid provider finding' "printf '%s' \"\$out\" | grep -q '\"code\":\"T050\"'"
printf 'provider = claude\nproviders = codex,gemini\n' > "$WORK/codex/.gsd.conf"; out=$(gsd-doctor --repo "$WORK/codex" --json 2>/dev/null || true); assert 'doctor reports contradictory legacy provider' "printf '%s' \"\$out\" | grep -q '\"code\":\"T056\"'"
printf 'providers = codex\n' > "$WORK/codex/.gsd.conf"; cp "$WORK/claude/CLAUDE.md" "$WORK/codex/CLAUDE.md"; out=$(gsd-doctor --repo "$WORK/codex" --json 2>/dev/null || true); assert 'doctor JSON reports stale provider artifact' "printf '%s' \"\$out\" | grep -q '\"code\":\"T054\"'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
