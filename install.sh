#!/usr/bin/env bash
#
# install.sh — link (or copy) the shared gsd commands into ~/.local/bin.
#
# Default is SYMLINK: `git pull` in this repo updates the live commands
# instantly, and any edit made to the live commands lands in the repo where it
# can be committed. Pass --copy for standalone copies instead (e.g. on a
# machine that won't keep this checkout around).
#
# Usage:
#   ./install.sh [--copy] [--agent claude|codex|gemini]... [--all-agents]
#
# Env:
#   GSD_BIN_DIR   install target (default: ~/.local/bin)
#   GSD_COPY_DIR  standalone runtime (default: GSD_BIN_DIR/../share/gsd-worktrees)
set -euo pipefail

BIN_DIR="${GSD_BIN_DIR:-$HOME/.local/bin}"
MODE="link"; PROVIDERS=""; REUSE=0
add_provider() { case ",$PROVIDERS," in *",$1,"*) ;; *) PROVIDERS="${PROVIDERS:+$PROVIDERS,}$1" ;; esac; }
while [ $# -gt 0 ]; do
  case "$1" in
    --copy) MODE=copy; shift ;;
    --reuse-install-config) REUSE=1; shift ;;
    --agent) [ $# -ge 2 ] || { echo '--agent needs a provider' >&2; exit 1; }; case "$2" in claude|codex|gemini) add_provider "$2" ;; *) echo "unknown provider: $2" >&2; exit 1 ;; esac; shift 2 ;;
    --all-agents) PROVIDERS=claude,codex,gemini; shift ;;
    -h|--help) echo 'usage: ./install.sh [--copy] [--agent claude|codex|gemini]... [--all-agents] [--reuse-install-config]'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done
REPO="$(cd "$(dirname "$0")" && pwd -P)"
. "$REPO/lib/common.sh"
. "$REPO/lib/provider.sh"
INSTALL_PYTHON=$(gsd_python) || { echo 'installation requires Python 3.7+ (python3 or python on PATH)' >&2; exit 1; }
backup_path() { local base=$1 out=$1.bak n=1; while [ -e "$out" ] || [ -L "$out" ]; do out=$base.bak.$n; n=$((n+1)); done; printf '%s\n' "$out"; }
absolute_path() { "$INSTALL_PYTHON" -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
within() { case "$1/" in "$2/"*) return 0 ;; *) return 1 ;; esac; }
# A command link or skill this toolkit placed earlier (from any checkout or
# release runtime) is replaced in place, not moved to .bak: a gsd-list.bak on
# PATH, or a gsd-flow.bak in an agent's skill dir, would be picked up as real.
toolkit_pkg() { [ -f "$1/install.sh" ] && [ -f "$1/lib/common.sh" ]; }
owned_link() {  # $1=symlink $2=bin|skills
  local t; t=$(readlink "$1") || return 1
  case "$t" in /*) ;; *) t="$(dirname "$1")/$t" ;; esac
  toolkit_pkg "$(dirname "$(dirname "$t")")" && return 0
  case "$t" in */gsd-worktrees/releases/*/"$2"/*) return 0 ;; esac   # a removed release
  return 1
}
BIN_DIR=$(absolute_path "$BIN_DIR")
if within "$BIN_DIR" "$REPO" || within "$REPO" "$BIN_DIR"; then
  echo "unsafe $([ "$MODE" = copy ] && printf '%s ' --copy)destination: bin and source directories must not overlap" >&2; exit 1
fi
MANIFEST=$BIN_DIR/.gsd-install-manifest
if [ "$REUSE" = 1 ] && [ -f "$MANIFEST" ]; then
  while IFS=$'\t' read -r key value; do
    case "$key" in
      # recorded agents are kept; any --agent given now is added to them
      providers) oldifs=$IFS; IFS=,; for p in $value; do add_provider "$p"; done; IFS=$oldifs ;;
      claude_skills) GSD_CLAUDE_SKILL_DIR=${GSD_CLAUDE_SKILL_DIR:-$value} ;;
      codex_skills) GSD_CODEX_SKILL_DIR=${GSD_CODEX_SKILL_DIR:-$value} ;;
      gemini_skills) GSD_GEMINI_SKILL_DIR=${GSD_GEMINI_SKILL_DIR:-$value} ;;
      *) echo "invalid install manifest key: $key" >&2; exit 1 ;;
    esac
  done < "$MANIFEST"
fi
[ -n "$PROVIDERS" ] || PROVIDERS=claude
gsd_provider_list_validate "$PROVIDERS"
case ",$PROVIDERS," in *,custom,*) echo 'custom provider has no installable skill format' >&2; exit 1 ;; esac
oldifs=$IFS; IFS=,
for provider in $PROVIDERS; do
  skillpath=$(gsd_provider_skill_root "$provider")
  case "$skillpath" in *$'\t'*|*$'\n'*) echo 'skill destination cannot contain tabs or newlines' >&2; exit 1 ;; esac
  skillpath=$(absolute_path "$skillpath")
  if within "$skillpath" "$REPO" || within "$REPO" "$skillpath"; then
    echo 'unsafe skill destination: skills and source directories must not overlap' >&2; exit 1
  fi
done
IFS=$oldifs

if [ "$MODE" = copy ]; then
  BIN_DIR=$(absolute_path "$BIN_DIR")
  COPY_REQUEST=${GSD_COPY_DIR:-$BIN_DIR/../share/gsd-worktrees}
  COPY_REQUEST=$("$INSTALL_PYTHON" -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$COPY_REQUEST")
  if [ -L "$COPY_REQUEST" ]; then
    echo "unsafe --copy destination: runtime root is a symlink ($COPY_REQUEST)" >&2
    exit 1
  fi
  COPY_DIR=$(absolute_path "$COPY_REQUEST")
  if within "$COPY_DIR" "$REPO" || within "$REPO" "$COPY_DIR" \
    || within "$BIN_DIR" "$REPO" || within "$REPO" "$BIN_DIR" \
    || within "$COPY_DIR" "$BIN_DIR" || within "$BIN_DIR" "$COPY_DIR"; then
    echo "unsafe --copy destination: runtime, bin, and source directories must not overlap" >&2
    exit 1
  fi
  # Merge only package-owned paths. Unrelated files remain in place; changed
  # paths get distinct backups, so repeated installs never clobber old copies.
  copy_tree() {
    local src=$1 dst=$2 path rel target bak
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      if [ ! -d "$dst" ] || [ -L "$dst" ]; then
        bak=$(backup_path "$dst"); mv "$dst" "$bak"
        echo "• existing $dst preserved at $bak"
      fi
    fi
    mkdir -p "$dst"
    while IFS= read -r path; do
      rel=${path#"$src"/}; target="$dst/$rel"
      if [ -d "$path" ] && [ ! -L "$path" ]; then
        if [ -e "$target" ] || [ -L "$target" ]; then
          if [ ! -d "$target" ] || [ -L "$target" ]; then
            bak=$(backup_path "$target"); mv "$target" "$bak"
            echo "• existing $target preserved at $bak"
          fi
        fi
        mkdir -p "$target"
      else
        if [ -e "$target" ] || [ -L "$target" ]; then
          if [ -L "$path" ] && [ -L "$target" ] && [ "$(readlink "$path")" = "$(readlink "$target")" ]; then continue; fi
          if [ -f "$path" ] && [ -f "$target" ] && [ ! -L "$target" ] \
            && cmp -s "$path" "$target" && { [ ! -x "$path" ] || [ -x "$target" ]; }; then continue; fi
          bak=$(backup_path "$target"); mv "$target" "$bak"
          echo "• existing $target preserved at $bak"
        fi
        cp -P "$path" "$target"
      fi
    done < <(find "$src" -mindepth 1 -type d -name __pycache__ -prune -o -mindepth 1 -print)
  }
  mkdir -p "$COPY_DIR"
  # Only retire commands named by our previous inventory. Preserve their bytes
  # in backups and leave unrelated runtime files and PATH links alone.
  if [ -f "$COPY_DIR/.gsd-owned-commands" ]; then
    while IFS= read -r old; do
      case "$old" in gsd-*) ;; *) echo 'invalid copied command inventory' >&2; exit 1 ;; esac
      case "$old" in */*|*..*) echo 'unsafe copied command inventory' >&2; exit 1 ;; esac
      [ ! -e "$REPO/bin/$old" ] || continue
      if [ -e "$COPY_DIR/bin/$old" ] || [ -L "$COPY_DIR/bin/$old" ]; then
        bak=$(backup_path "$COPY_DIR/bin/$old"); mv "$COPY_DIR/bin/$old" "$bak"
        echo "• retired command preserved at $bak"
      fi
      if [ -L "$BIN_DIR/$old" ] && [ "$(readlink "$BIN_DIR/$old")" = "$COPY_DIR/bin/$old" ]; then rm -f "$BIN_DIR/$old"; fi
    done < "$COPY_DIR/.gsd-owned-commands"
  fi
  for component in bin lib shims skills; do copy_tree "$REPO/$component" "$COPY_DIR/$component"; done
  for top in install.sh get.sh VERSION; do
    [ -f "$REPO/$top" ] || continue
    if [ -e "$COPY_DIR/$top" ] || [ -L "$COPY_DIR/$top" ]; then
      if ! { [ -f "$COPY_DIR/$top" ] && [ ! -L "$COPY_DIR/$top" ] && cmp -s "$REPO/$top" "$COPY_DIR/$top"; }; then
        bak=$(backup_path "$COPY_DIR/$top"); mv "$COPY_DIR/$top" "$bak"
        cp -P "$REPO/$top" "$COPY_DIR/$top"
      fi
    else
      cp -P "$REPO/$top" "$COPY_DIR/$top"
    fi
  done
  inventory=$(mktemp)
  for command_file in "$REPO"/bin/*; do basename "$command_file" >> "$inventory"; done
  mv "$inventory" "$COPY_DIR/.gsd-owned-commands"
fi
mkdir -p "$BIN_DIR"

for f in "$REPO"/bin/*; do
  name=$(basename "$f")
  dest="$BIN_DIR/$name"
  # Preserve any command already at this path unless it points to this runtime.
  target=$f
  [ "$MODE" = link ] || target="$COPY_DIR/bin/$name"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$target" ]; then
    echo "✔ $name → $dest"; continue
  fi
  if [ -L "$dest" ] && owned_link "$dest" bin; then
    rm -f "$dest"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    bak=$(backup_path "$dest"); mv "$dest" "$bak"
    echo "• existing $name preserved at $bak"
  fi
  ln -s "$target" "$dest"
  echo "✔ $name → $dest"
done

# Prune links left behind by commands DELETED from bin/ — a dangling symlink
# would otherwise sit on PATH forever as a broken command. Links into another
# toolkit runtime (an older release) for a command this version no longer has
# go too.
for dest in "$BIN_DIR"/gsd-*; do
  [ -L "$dest" ] || continue
  [ ! -e "$REPO/bin/$(basename "$dest")" ] || continue
  case "$(readlink "$dest")" in
    "$REPO"/bin/*) [ -e "$dest" ] || { rm -f "$dest"; echo "✂ $(basename "$dest") removed (deleted from the toolkit)"; } ;;
    *) if owned_link "$dest" bin; then rm -f "$dest"; echo "✂ $(basename "$dest") removed (not in this version)"; fi ;;
  esac
done

# ── the agent-facing skill ───────────────────────────────────────────────────
# Follows the chosen mode like bin/ does: --copy exists for machines that
# won't keep this checkout around, and a symlinked skill would dangle there.
install_skills() {
  local provider=$1 SKILL_DIR d name dest bak
  SKILL_DIR=$(gsd_provider_skill_root "$provider")
  mkdir -p "$SKILL_DIR"
  for d in "$REPO"/skills/*/; do
    name=$(basename "$d")
    dest="$SKILL_DIR/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if [ -L "$dest" ] && [ "$(readlink "$dest")" = "${d%/}" ] && [ "$MODE" = link ]; then :
      elif [ "$MODE" = copy ] && [ -d "$dest" ] && [ ! -L "$dest" ] \
        && diff -qr -x .gsd-worktrees-skill "${d%/}" "$dest" >/dev/null 2>&1; then
        echo "• $provider skill $name already current"; continue
      elif [ -L "$dest" ] && owned_link "$dest" skills; then
        rm -f "$dest"
      elif [ -d "$dest" ] && [ ! -L "$dest" ] && [ -f "$dest/.gsd-worktrees-skill" ]; then
        rm -rf "$dest"
      else
        bak=$(backup_path "$dest"); mv "$dest" "$bak"
        echo "• existing $provider skill $name preserved at $bak"
      fi
    fi
    if [ "$MODE" = link ]; then
      ln -sfn "${d%/}" "$dest"
    else
      cp -R "${d%/}" "$dest"
      # marks the copy as the toolkit's, so the next update replaces it in place
      head -1 "$REPO/VERSION" 2>/dev/null > "$dest/.gsd-worktrees-skill" || : > "$dest/.gsd-worktrees-skill"
    fi
    echo "✔ $provider skill $name → $dest"
  done
  for dest in "$SKILL_DIR"/*; do
    [ -L "$dest" ] || continue
    case "$(readlink "$dest")" in "$REPO"/skills/*) [ -e "$dest" ] || echo "⚠ stale toolkit skill link: $dest (re-run install after updating the toolkit)" ;; esac
  done
}
oldifs=$IFS; IFS=,; for provider in $PROVIDERS; do install_skills "$provider"; done; IFS=$oldifs
manifest_tmp=$(mktemp)
printf 'providers\t%s\n' "$PROVIDERS" > "$manifest_tmp"
oldifs=$IFS; IFS=,
for provider in $PROVIDERS; do
  printf '%s_skills\t%s\n' "$provider" "$(absolute_path "$(gsd_provider_skill_root "$provider")")" >> "$manifest_tmp"
done
IFS=$oldifs
if { [ -e "$MANIFEST" ] || [ -L "$MANIFEST" ]; } && ! cmp -s "$manifest_tmp" "$MANIFEST"; then
  bak=$(backup_path "$MANIFEST"); mv "$MANIFEST" "$bak"
  echo "• previous installation settings preserved at $bak"
fi
mv "$manifest_tmp" "$MANIFEST"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "⚠ $BIN_DIR is not on your PATH — add it to your shell profile" ;;
esac
echo ""
echo "Done ($MODE mode). Try:  gsd-list --help"
