#!/usr/bin/env bash
# Provider adapters for launch syntax and integration locations.  This file
# deliberately contains no workflow/state-machine logic.

gsd_provider_known() {
  case "$1" in claude|codex|gemini|custom) return 0 ;; *) return 1 ;; esac
}

gsd_provider_list_validate() {
  local remaining=$1 p seen=,
  case "$remaining" in ''|,*|*,|*,,*)
    echo "malformed providers list '$remaining'; use comma-separated names, e.g. claude,codex" >&2
    return 64 ;;
  esac
  while :; do
    p=${remaining%%,*}
    gsd_provider_known "$p" || {
      printf "unknown provider '%s' in providers; expected claude, codex, gemini, or custom\n" "$p" >&2
      return 64
    }
    case "$seen" in *",$p,"*) echo "duplicate provider '$p' in providers; list each provider once" >&2; return 64 ;; esac
    seen="$seen$p,"
    case "$remaining" in *,*) remaining=${remaining#*,} ;; *) break ;; esac
  done
}

gsd_provider_default_command() {
  case "$1" in
    claude) printf '%s\n' claude ;;
    codex) printf '%s\n' codex ;;
    gemini) printf '%s\n' gemini ;;
    custom) return 1 ;;
  esac
}

gsd_provider_instruction_file() {
  case "$1" in
    claude) printf '%s\n' CLAUDE.md ;;
    codex) printf '%s\n' AGENTS.md ;;
    gemini) printf '%s\n' GEMINI.md ;;
    custom) printf '%s\n' AGENTS.md ;;
  esac
}

gsd_provider_skill_root() { # provider, optional home
  local p=$1 h=${2:-$HOME}
  case "$p" in
    claude) printf '%s\n' "${GSD_CLAUDE_SKILL_DIR:-${GSD_SKILL_DIR:-$h/.claude/skills}}" ;;
    codex) printf '%s\n' "${GSD_CODEX_SKILL_DIR:-$h/.codex/skills}" ;;
    gemini) printf '%s\n' "${GSD_GEMINI_SKILL_DIR:-$h/.gemini/skills}" ;;
    custom) return 1 ;;
  esac
}

gsd_provider_native_hook() {
  case "$1" in claude|gemini) printf '%s\n' supported ;; *) printf '%s\n' unsupported ;; esac
}

# Flags verified against the external GSD review skill. This toolkit prints
# its invocation; it does not install that skill or execute a reviewer itself.
gsd_provider_review_flag() {
  case "$1" in claude|codex|gemini) printf -- '--%s\n' "$1" ;; *) return 1 ;; esac
}

# Shared registration metadata. Unsupported providers have no settings file.
gsd_provider_hook_metadata() {
  case "$1" in
    claude) GSD_HOOK_SETTINGS=.claude/settings.json; GSD_HOOK_EVENT=PreToolUse; GSD_HOOK_MATCHER=Skill; GSD_HOOK_COMMAND='$CLAUDE_PROJECT_DIR/scripts/hooks/gsd-worktree-guard.sh' ;;
    gemini) GSD_HOOK_SETTINGS=.gemini/settings.json; GSD_HOOK_EVENT=BeforeTool; GSD_HOOK_MATCHER='activate_skill|run_shell_command'; GSD_HOOK_COMMAND='scripts/hooks/gsd-worktree-guard.sh' ;;
    *) return 1 ;;
  esac
}

gsd_provider_hook_state() { # repo, provider => present|absent|invalid|unverified|unsupported
  gsd_provider_hook_metadata "$2" || { echo unsupported; return; }
  local file=$1/$GSD_HOOK_SETTINGS
  [ -f "$file" ] || { echo absent; return; }
  command -v jq >/dev/null 2>&1 || { echo unverified; return; }
  if ! jq -e --arg e "$GSD_HOOK_EVENT" 'type == "object" and ((.hooks // {}) | type == "object") and ((.hooks[$e] // []) | type == "array")' "$file" >/dev/null 2>&1; then echo invalid; return; fi
  if jq -e --arg e "$GSD_HOOK_EVENT" --arg m "$GSD_HOOK_MATCHER" --arg c "$GSD_HOOK_COMMAND" '
    (.disableAllHooks != true) and (.hooksConfig.enabled != false) and
    any((.hooks[$e] // [])[]; .matcher == $m and .disabled != true and
      any((.hooks // [])[]; .type == "command" and .command == $c and .disabled != true))
  ' "$file" >/dev/null 2>&1; then echo present; else echo absent; fi
}

gsd_owned_markers_valid() { # file, marker kind; an absent block is valid
  [ -f "$1" ] || return 0
  awk -v start="<!-- gsd-worktrees:$2:start -->" -v end="<!-- gsd-worktrees:$2:end -->" '
    index($0,start) { if ($0 != start || state != 0 || starts++) bad=1; state=1 }
    index($0,end) { if ($0 != end || state != 1) bad=1; state=2 }
    END { exit (bad || state == 1) ? 1 : 0 }
  ' "$1"
}

gsd_provider_instruction_members() { # file; supports older generated headers
  sed -n '/^<!-- gsd-worktrees:provider:start -->$/,/^<!-- gsd-worktrees:provider:end -->$/p' "$1" 2>/dev/null |
    sed -n 's/^## GSD worktrees (\([^)]*\) adapter)$/\1/p'
}

gsd_provider_instruction_integrated() { # repo, provider
  local file members
  file=$1/$(gsd_provider_instruction_file "$2")
  gsd_owned_markers_valid "$file" provider || return 1
  grep -qx '<!-- gsd-worktrees:provider:start -->' "$file" 2>/dev/null || return 1
  members=$(gsd_provider_instruction_members "$file")
  case ",$members," in *",$2,"*) ;; *) return 1 ;; esac
  sed -n '/^<!-- gsd-worktrees:provider:start -->$/,/^<!-- gsd-worktrees:provider:end -->$/p' "$file" |
    grep -qF 'Read and follow `.gsd/INSTRUCTIONS.md`.' || return 1
  grep -qx '<!-- gsd-worktrees:canonical:start -->' "$1/.gsd/INSTRUCTIONS.md" 2>/dev/null &&
    gsd_owned_markers_valid "$1/.gsd/INSTRUCTIONS.md" canonical
}

gsd_replace_owned_block() { # file, kind, new block file; caller prevalidates
  local tmp; tmp=$(mktemp) || return 1
  [ ! -f "$1" ] || cp -p "$1" "$tmp"
  BLOCK_FILE=$3 BLOCK_KIND=$2 perl -0777 -pe '
    BEGIN { open my $b, "<", $ENV{BLOCK_FILE} or die $!; local $/; $block=<$b>; $kind=$ENV{BLOCK_KIND}; }
    if (/^<!-- gsd-worktrees:\Q$kind\E:start -->$/m) {
      s/^<!-- gsd-worktrees:\Q$kind\E:start -->\n.*?^<!-- gsd-worktrees:\Q$kind\E:end -->(?:\n|\z)/$block/msg;
    } else { $_ .= (length && !/\n\z/ ? "\n" : "") . "\n" . $block; }
  ' "${1:-/dev/null}" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$1"
}

gsd_command_guards_active() { # toolkit package; native hook/shim is not required
  [ -x "$1/bin/gsd-worktree-guard" ] && [ -x "$1/bin/gsd-start" ] &&
    [ -x "$1/bin/gsd-flow-next" ] &&
    grep -q 'gsd-worktree-guard.*--command' "$1/bin/gsd-start" &&
    grep -q 'gsd-worktree-guard.*--command' "$1/bin/gsd-flow-next"
}

gsd_provider_validate() { # provider, executable override
  local p=$1 c=${2:-}
  gsd_provider_known "$p" || {
    printf "unknown provider '%s' (expected claude, codex, gemini, or custom)\n" "$p" >&2
    return 64
  }
  if [ "$p" = custom ] && [ -z "$c" ]; then
    echo "provider 'custom' requires an explicit agent command" >&2
    return 64
  fi
  case "$c" in *[[:space:]]*)
    echo "agent command must be one executable path/name, not a shell template" >&2; return 64 ;;
  esac
}

gsd_provider_resolve() { # repo, cli provider, cli command
  local repo=$1 cli_p=${2:-} cli_c=${3:-} conf_p conf_default conf_c provider_conf_c provider_env_c="" legacy configured
  # The first entry in ordered `providers` is canonical. `provider` is read
  # only for repositories created before the provider-set configuration.
  configured=$(gsd_conf_get "$repo" providers)
  if [ -n "$configured" ] || grep -qE '^[[:space:]]*providers[[:space:]]*=' "$repo/.gsd.conf" 2>/dev/null; then
    gsd_provider_list_validate "$configured" || return
  fi
  if [ -n "$configured" ]; then conf_p=${configured%%,*}
  else conf_p=$(gsd_conf_get "$repo" provider)
  fi
  conf_default=${conf_p:-claude}
  GSD_PROVIDER_RESOLVED=${cli_p:-${GSD_PROVIDER:-$conf_p}}
  if [ -z "$GSD_PROVIDER_RESOLVED" ] && [ -n "${GSD_AGENT:-}" ]; then
    legacy=$GSD_AGENT
    if gsd_provider_known "$legacy"; then GSD_PROVIDER_RESOLVED=$legacy
    else GSD_PROVIDER_RESOLVED=custom; cli_c=$legacy; fi
  fi
  # Compatibility default for repositories created before providers existed.
  GSD_PROVIDER_RESOLVED=${GSD_PROVIDER_RESOLVED:-claude}
  gsd_provider_known "$GSD_PROVIDER_RESOLVED" || { gsd_provider_validate "$GSD_PROVIDER_RESOLVED" ""; return; }
  case "$GSD_PROVIDER_RESOLVED" in
    claude) provider_env_c=${GSD_CLAUDE_COMMAND:-} ;;
    codex) provider_env_c=${GSD_CODEX_COMMAND:-} ;;
    gemini) provider_env_c=${GSD_GEMINI_COMMAND:-} ;;
    custom) provider_env_c=${GSD_CUSTOM_COMMAND:-} ;;
  esac
  provider_conf_c=$(gsd_conf_get "$repo" "${GSD_PROVIDER_RESOLVED}_command")
  conf_c=""
  [ "$GSD_PROVIDER_RESOLVED" != "$conf_default" ] || conf_c=$(gsd_conf_get "$repo" agent_command)
  GSD_AGENT_COMMAND_RESOLVED=${cli_c:-${GSD_AGENT_COMMAND:-${provider_env_c:-${provider_conf_c:-$conf_c}}}}
  gsd_provider_validate "$GSD_PROVIDER_RESOLVED" "$GSD_AGENT_COMMAND_RESOLVED" || return
  if [ -z "$GSD_AGENT_COMMAND_RESOLVED" ]; then
    GSD_AGENT_COMMAND_RESOLVED=$(gsd_provider_default_command "$GSD_PROVIDER_RESOLVED") || return 64
  fi
}

gsd_model_validate() { # provider, optional model; default means CLI default
  local p=$1 model=${2:-}
  case "$model" in ''|default) return 0 ;; esac
  if [ "$p" = custom ]; then
    echo "custom provider has no model-flag adapter; configure its wrapper or use --model default" >&2
    return 64
  fi
  case "$model" in -*|*[[:space:]]*|*[[:cntrl:]]*)
    echo "model must be one model ID or alias, without whitespace or a leading '-'" >&2
    return 64 ;;
  esac
}

gsd_model_resolve() { # repo, provider, optional CLI override
  local repo=$1 p=$2 cli=${3:-} env_model="" configured
  case "$p" in
    claude) env_model=${GSD_CLAUDE_MODEL:-} ;;
    codex) env_model=${GSD_CODEX_MODEL:-} ;;
    gemini) env_model=${GSD_GEMINI_MODEL:-} ;;
  esac
  configured=$(gsd_conf_get "$repo" "${p}_model")
  GSD_MODEL_RESOLVED=${cli:-${GSD_MODEL:-${env_model:-$configured}}}
  gsd_model_validate "$p" "$GSD_MODEL_RESOLVED" || return
  [ "$GSD_MODEL_RESOLVED" != default ] || GSD_MODEL_RESOLVED=""
}

gsd_start_mode_resolve() { # repo, optional CLI override
  local repo=$1 cli_mode=${2:-} configured
  configured=$(gsd_conf_get "$repo" start_mode)
  GSD_START_MODE_RESOLVED=${cli_mode:-${configured:-discuss}}
  case "$GSD_START_MODE_RESOLVED" in
    discuss|flow) return 0 ;;
    *)
      printf "invalid start_mode '%s' (expected discuss or flow)\n" "$GSD_START_MODE_RESOLVED" >&2
      return 64
      ;;
  esac
}

gsd_provider_prompt() { # provider, kind, phase-or-empty
  local p=$1 kind=$2 n=${3:-}
  case "$kind" in
    discuss)
      case "$p" in
        claude) printf '/gsd-discuss-phase %s\n' "$n" ;;
        codex) printf 'Discuss GSD phase %s with the user and write its context artifact. Use the gsd-discuss-phase skill if available and obey .gsd/INSTRUCTIONS.md.\n' "$n" ;;
        gemini) printf 'Discuss GSD phase %s with the user and write its context artifact. Activate the gsd-discuss-phase skill if available and obey .gsd/INSTRUCTIONS.md.\n' "$n" ;;
        custom) printf 'Discuss GSD phase %s with the user and write its context artifact; obey .gsd/INSTRUCTIONS.md.\n' "$n" ;;
      esac ;;
    flow)
      case "$p" in
        claude) printf '/gsd-flow %s\n' "$n" ;;
        codex) printf 'Use the gsd-flow skill to drive phase %s. Start by running gsd-flow-next %s and obey every reported gate.\n' "$n" "$n" ;;
        gemini) printf 'Activate the gsd-flow skill and drive phase %s. Start by running gsd-flow-next %s and obey every reported gate.\n' "$n" "$n" ;;
        custom) printf 'Drive GSD phase %s by running gsd-flow-next %s before every phase step; obey every gate in .gsd/INSTRUCTIONS.md.\n' "$n" "$n" ;;
      esac ;;
    new)
      case "$p" in claude) echo /gsd-new-project ;; *) echo 'Initialize GSD planning for this repository. Use the gsd-new-project skill if available; otherwise follow the installed GSD planning documentation.' ;; esac ;;
    ingest)
      case "$p" in claude) echo /gsd-ingest-docs ;; *) echo 'Initialize GSD planning by ingesting the existing project documents. Use the gsd-ingest-docs skill if available; otherwise follow the installed GSD planning documentation.' ;; esac ;;
  esac
}

gsd_provider_argv() { # provider, executable, prompt, optional model
  local p=$1 c=$2 prompt=$3 model=${4:-}
  gsd_model_validate "$p" "$model" || return
  GSD_LAUNCH_ARGV=("$c")
  case "$p" in
    claude|codex|gemini)
      if [ -n "$model" ] && [ "$model" != default ]; then GSD_LAUNCH_ARGV+=(--model "$model"); fi ;;
  esac
  # shellcheck disable=SC2034 # output array is consumed by the caller
  case "$p" in
    gemini) GSD_LAUNCH_ARGV+=(--prompt-interactive "$prompt") ;;
    claude|codex|custom) GSD_LAUNCH_ARGV+=("$prompt") ;;
  esac
}

gsd_shell_quote() { printf '%q' "$1"; }
gsd_provider_render() { # cwd followed by argv
  local cwd=$1 a out
  shift
  out="cd $(gsd_shell_quote "$cwd") &&"
  for a in "$@"; do out="$out $(gsd_shell_quote "$a")"; done
  printf '%s\n' "$out"
}
