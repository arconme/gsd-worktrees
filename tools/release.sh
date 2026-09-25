#!/usr/bin/env bash
#
# tools/release.sh — cut a release (maintainers only; not installed).
#
#   tools/release.sh <X.Y.Z> [--push]
#
# 1. Checks: on main, clean, level with origin/main, X.Y.Z newer than VERSION
#    (or equal, when VERSION was already bumped), and CHANGELOG.md has a
#    "## X.Y.Z" section (write it first — it becomes the release notes).
# 2. Writes VERSION, commits "release vX.Y.Z", adds the annotated tag vX.Y.Z.
# 3. With --push: pushes main and the tag. GitHub Actions (release.yml) then
#    runs every test suite and publishes the release; get.sh / gsd-update
#    pick it up from there. Without --push it prints the push command.
set -euo pipefail
die() { printf 'release: %s\n' "$*" >&2; exit 1; }
cd "$(dirname "$0")/.."
V=${1:-}; PUSH=0; [ "${2:-}" != --push ] || PUSH=1
printf '%s' "$V" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || die "usage: tools/release.sh X.Y.Z [--push]"
GSD_PKG=$PWD
# shellcheck source=../lib/common.sh
. lib/common.sh
# shellcheck source=../lib/version.sh
. lib/version.sh
CUR=$(gsd_version)
[ "$(git branch --show-current)" = main ] || die "not on main"
[ -z "$(git status --porcelain)" ] || die "uncommitted changes — commit or stash first"
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not level with origin/main — pull/push first"
! git rev-parse -q --verify "refs/tags/v$V" >/dev/null || die "tag v$V already exists"
[ "$V" = "$CUR" ] || gsd_version_gt "$V" "$CUR" || die "$V is older than VERSION ($CUR)"
grep -qE "^## \[?$V\]?" CHANGELOG.md || die "CHANGELOG.md has no '## $V' section — write the release notes first"

printf '%s\n' "$V" > VERSION
git add VERSION
git diff --cached --quiet || git commit -qm "release v$V"
git tag -a "v$V" -m "gsd-worktrees $V"
echo "✔ tagged v$V"
if [ "$PUSH" = 1 ]; then
  git push -q origin main "v$V"
  echo "✔ pushed — watch: gh run list --workflow release.yml"
else
  echo "next: git push origin main v$V"
fi
