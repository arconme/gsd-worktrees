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
#   ./install.sh [--copy]
#
# Env:
#   GSD_BIN_DIR   install target (default: ~/.local/bin)
set -euo pipefail

BIN_DIR="${GSD_BIN_DIR:-$HOME/.local/bin}"
MODE="link"
case "${1:-}" in
  --copy) MODE="copy" ;;
  '') ;;
  *) echo "usage: ./install.sh [--copy]" >&2; exit 1 ;;
esac

REPO="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$BIN_DIR"

for f in "$REPO"/bin/*; do
  name=$(basename "$f")
  dest="$BIN_DIR/$name"
  # A pre-existing REGULAR file: drop it if identical, back it up if it differs
  # (it may carry local changes that were never committed here).
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if cmp -s "$f" "$dest"; then
      rm "$dest"
    else
      mv "$dest" "$dest.bak"
      echo "• existing $name differed from the repo version — backed up to $name.bak"
    fi
  fi
  if [ "$MODE" = link ]; then
    ln -sfn "$f" "$dest"
  else
    rm -f "$dest"
    cp "$f" "$dest"
  fi
  chmod +x "$f"
  echo "✔ $name → $dest"
done

# Prune links left behind by commands DELETED from bin/ — a dangling symlink
# would otherwise sit on PATH forever as a broken command.
for dest in "$BIN_DIR"/*; do
  [ -L "$dest" ] || continue
  case "$(readlink "$dest")" in
    "$REPO"/bin/*) [ -e "$dest" ] || { rm -f "$dest"; echo "✂ $(basename "$dest") removed (deleted from the toolkit)"; } ;;
  esac
done

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "⚠ $BIN_DIR is not on your PATH — add it to your shell profile" ;;
esac
echo ""
echo "Done ($MODE mode). Try:  gsd-list --help"
