#!/usr/bin/env bash
#
# tools/release-check.sh — should this checkout be released? (maintainers only;
# release.yml runs it before the tests.)
#
#   git ls-remote --tags origin | tools/release-check.sh
#
# Reads VERSION and CHANGELOG.md in the current directory, and the existing tags
# on stdin (any text holding refs/tags/vX.Y.Z or vX.Y.Z).
#   prints X.Y.Z   a new version: release it
#   prints nothing that version already has its tag: nothing to do
#   exit 1         VERSION is bad, older than the newest tag, or CHANGELOG.md has
#                  no notes for it
set -euo pipefail
die() { printf 'release-check: %s\n' "$*" >&2; exit 1; }
GSD_PKG=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../lib/common.sh
. "$GSD_PKG/lib/common.sh"
# shellcheck source=../lib/version.sh
. "$GSD_PKG/lib/version.sh"

V=$(head -1 VERSION | tr -d '[:space:]')
printf '%s' "$V" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || die "VERSION is not X.Y.Z: '$V'"

while IFS= read -r tag; do
  [ "$tag" != "$V" ] || exit 0
  ! gsd_version_gt "$tag" "$V" || die "VERSION $V is older than the tag v$tag"
done < <(grep -oE '\bv[0-9]+\.[0-9]+\.[0-9]+\b' | sed 's/^v//' || true)

# The same section release.yml turns into the release notes.
notes=$(awk -v v="$V" '$1 == "##" && ($2 == v || $2 == "[" v "]") {on=1; next} on && /^## / {exit} on {print}' CHANGELOG.md)
[ -n "$(printf '%s' "$notes" | tr -d '[:space:]')" ] || die "CHANGELOG.md has no notes under '## $V'"
echo "$V"
