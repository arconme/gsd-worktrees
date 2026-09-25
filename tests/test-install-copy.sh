#!/usr/bin/env bash
set -euo pipefail
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

PKG=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
COPY="$WORK/runtime"
SKILLS="$WORK/skills"

install_copy() {
  GSD_BIN_DIR="$BIN" GSD_COPY_DIR="$COPY" GSD_CLAUDE_SKILL_DIR="$SKILLS" \
    "$PKG/install.sh" --copy >/dev/null
}
mkdir -p "$BIN" "$COPY/lib" "$COPY/unrelated-dir"
printf 'local command\n' > "$BIN/gsd-list"
printf 'older backup\n' > "$BIN/gsd-list.bak"
printf 'local library\n' > "$COPY/lib/common.sh"
printf 'keep\n' > "$COPY/unrelated-dir/file"
install_copy
[ -L "$BIN/gsd-list" ]
[ "$(readlink "$BIN/gsd-list")" = "$COPY/bin/gsd-list" ]
[ "$(cat "$BIN/gsd-list.bak")" = 'older backup' ]
[ "$(cat "$BIN/gsd-list.bak.1")" = 'local command' ]
[ "$(cat "$COPY/lib/common.sh.bak")" = 'local library' ]
[ "$(cat "$COPY/unrelated-dir/file")" = keep ]
[ -f "$COPY/shims/scripts/gsd-init.sh" ] || [ -d "$COPY/shims/scripts" ]
[ -f "$COPY/skills/gsd-flow/SKILL.md" ]
[ -f "$SKILLS/gsd-flow/SKILL.md" ]

before=$(find "$WORK" -name '*.bak*' | wc -l | tr -d ' ')
install_copy
after=$(find "$WORK" -name '*.bak*' | wc -l | tr -d ' ')
[ "$before" = "$after" ]

# Move the source away without touching it: exercise a command from an isolated
# copy of the package, then remove only that temporary fixture.
FIXTURE="$WORK/source"
mkdir -p "$FIXTURE"
cp -R "$PKG/bin" "$PKG/lib" "$PKG/shims" "$PKG/skills" "$FIXTURE/"
cp "$PKG/install.sh" "$FIXTURE/install.sh"
# Sync must reuse both provider choice and relocated skill directory. This
# isolated source has no remote, so sync performs no network writes.
git -C "$FIXTURE" init -qb main
GSD_BIN_DIR="$WORK/sync-bin" GSD_CODEX_SKILL_DIR="$WORK/codex-skills" \
  "$FIXTURE/install.sh" --agent codex >/dev/null
GSD_CLAUDE_SKILL_DIR="$WORK/must-not-install-claude" \
  "$WORK/sync-bin/gsd-sync" >/dev/null
[ -L "$WORK/codex-skills/gsd-flow" ]
[ ! -e "$WORK/must-not-install-claude" ]
grep -q $'providers\tcodex' "$WORK/sync-bin/.gsd-install-manifest"
git -C "$FIXTURE" remote add origin "$WORK/missing-origin"
GIT_TRACE="$WORK/sync-trace" "$WORK/sync-bin/gsd-sync" --check >/dev/null
if grep -Eq 'git (fetch|pull|push)' "$WORK/sync-trace"; then
  echo 'sync --check attempted a mutating remote operation' >&2; exit 1
fi
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/bin/gsd-obsolete"
chmod +x "$FIXTURE/bin/gsd-obsolete"
GSD_BIN_DIR="$WORK/upgrade-bin" GSD_COPY_DIR="$WORK/upgrade-runtime" \
  GSD_CODEX_SKILL_DIR="$WORK/upgrade-skills" "$FIXTURE/install.sh" --copy --agent codex >/dev/null
rm "$FIXTURE/bin/gsd-obsolete"
ln -s "$WORK/unrelated-missing" "$WORK/upgrade-bin/unrelated"
GSD_BIN_DIR="$WORK/upgrade-bin" GSD_COPY_DIR="$WORK/upgrade-runtime" \
  "$FIXTURE/install.sh" --copy --reuse-install-config >/dev/null
[ ! -L "$WORK/upgrade-bin/gsd-obsolete" ]
[ ! -e "$WORK/upgrade-runtime/bin/gsd-obsolete" ]
[ -f "$WORK/upgrade-runtime/bin/gsd-obsolete.bak" ]
[ -L "$WORK/upgrade-bin/unrelated" ]
GSD_BIN_DIR="$WORK/isolated-bin" GSD_CLAUDE_SKILL_DIR="$WORK/isolated-skills" \
  "$FIXTURE/install.sh" >/dev/null
[ -L "$WORK/isolated-skills/gsd-flow" ]
GSD_BIN_DIR="$WORK/isolated-bin" GSD_COPY_DIR="$WORK/isolated-runtime" \
  GSD_CLAUDE_SKILL_DIR="$WORK/isolated-skills" "$FIXTURE/install.sh" --copy >/dev/null
[ -d "$WORK/isolated-skills/gsd-flow" ]
[ ! -L "$WORK/isolated-skills/gsd-flow" ]
rm -rf "$FIXTURE"
"$WORK/isolated-bin/gsd-sync" --check > "$WORK/sync-output"
rg -q 'standalone copy' "$WORK/sync-output"
"$WORK/isolated-bin/gsd-planning-repair" --help >/dev/null

if GSD_BIN_DIR="$PKG/bin" GSD_COPY_DIR="$WORK/unsafe" \
  GSD_CLAUDE_SKILL_DIR="$WORK/unused" "$PKG/install.sh" --copy > "$WORK/unsafe-output" 2>&1; then
  echo 'overlapping source destination was accepted' >&2; exit 1
fi
rg -q 'unsafe --copy destination' "$WORK/unsafe-output"
mkdir -p "$WORK/other-runtime"
printf 'keep\n' > "$WORK/other-runtime/marker"
ln -s "$WORK/other-runtime" "$WORK/runtime-link"
if GSD_BIN_DIR="$WORK/link-bin" GSD_COPY_DIR="$WORK/runtime-link" \
  GSD_CLAUDE_SKILL_DIR="$WORK/unused" "$PKG/install.sh" --copy > "$WORK/link-output" 2>&1; then
  echo 'symlink runtime root was accepted' >&2; exit 1
fi
[ "$(cat "$WORK/other-runtime/marker")" = keep ]
[ ! -e "$WORK/other-runtime/bin" ]
if GSD_BIN_DIR="$WORK/link-bin" GSD_COPY_DIR="$WORK/runtime-link/" \
  GSD_CLAUDE_SKILL_DIR="$WORK/unused" "$PKG/install.sh" --copy > "$WORK/link-output" 2>&1; then
  echo 'trailing slash symlink runtime root was accepted' >&2; exit 1
fi
[ ! -e "$WORK/other-runtime/bin" ]
if GSD_BIN_DIR="$WORK/unsafe-skill-bin" GSD_CODEX_SKILL_DIR="$PKG/skills" \
  "$PKG/install.sh" --agent codex > "$WORK/skill-output" 2>&1; then
  echo 'source-overlapping skill root was accepted' >&2; exit 1
fi
[ ! -e "$WORK/unsafe-skill-bin" ]
mkdir "$WORK/no-python"
for tool in bash dirname; do ln -s "$(command -v "$tool")" "$WORK/no-python/$tool"; done
if PATH="$WORK/no-python" GSD_BIN_DIR="$WORK/no-python-bin" \
  "$PKG/install.sh" --copy > "$WORK/python-output" 2>&1; then
  echo 'missing Python accepted' >&2; exit 1
fi
grep -q 'requires Python 3.7+' "$WORK/python-output"
[ ! -e "$WORK/no-python-bin" ]
echo 'copy installation: passed'
