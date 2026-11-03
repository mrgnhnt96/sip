#!/bin/bash
# Publish a sip_cli release: the version already merged on main goes to
# pub.dev and gets its tag.
#
#   tb release cut v0.20.2       the way to run it; the board records the
#                                release only if this succeeds
#   ./scripts/release.sh 0.20.2 --force
#                                without the board (when it's down)
#
# The version itself is prepared in a release PR first, as with every other
# change to main: a CHANGELOG.md entry, then `sip run prep` to sync
# pubspec.yaml, lib/src/version.dart and example/README.md. This script only
# publishes what that PR merged. It works in a throwaway worktree of
# origin/main, so the state of whatever checkout runs it doesn't matter.
#
# It is safe to re-run after a partial failure: a version already on pub.dev
# is not published again, and a tag already on origin at the same commit is
# left alone.
set -euo pipefail

force=
args=()
for a in "$@"; do
  if [ "$a" = --force ]; then force=1; else args+=("$a"); fi
done
set -- ${args[@]+"${args[@]}"}

if [ -z "${TB_RELEASE:-}" ] && [ -z "$force" ]; then
  v="${1:-<version>}"
  echo "Run tb release cut v${v#v} instead; it runs this script and records the release. (--force to run it without the board.)" >&2
  exit 1
fi

# Take the tag name too, so a release name passes straight through.
version="${1:-}"
version="${version#v}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "Usage: $0 <major.minor.patch[-pre]> [--force]" >&2
  exit 1
fi
tag="v$version"
package=sip_cli

# dvm puts dart here; a non-interactive shell may not have it on PATH.
if [ -d "$HOME/.dvm/shims" ]; then
  PATH="$HOME/.dvm/shims:$PATH"
fi
command -v dart >/dev/null || { echo "dart is not on PATH" >&2; exit 1; }

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"

git fetch -q origin main --tags
commit=$(git rev-parse origin/main)

work=$(mktemp -d "${TMPDIR:-/tmp}/sip-release.XXXXXX")
cleanup() {
  git -C "$repo" worktree remove --force "$work" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
git worktree add -q --detach "$work" "$commit"
cd "$work"

# The release PR must have merged this exact version everywhere.
pubspec=$(grep -m 1 '^version:' pubspec.yaml | awk '{print $2}')
code=$(grep -m 1 'const packageVersion' lib/src/version.dart | awk -F "'" '{print $2}')
changelog=$(grep -m 1 '^# ' CHANGELOG.md | awk '{print $2}')
if [ "$pubspec" != "$version" ] || [ "$code" != "$version" ] || [ "$changelog" != "$version" ]; then
  echo "origin/main is not at $version (pubspec.yaml $pubspec, version.dart $code, CHANGELOG.md $changelog)." >&2
  echo "Merge the release PR first: a CHANGELOG.md entry, then sip run prep." >&2
  exit 1
fi

# A tag on origin must already be this commit; never move a published tag.
remote_tag=$(git ls-remote origin "refs/tags/$tag^{}" | awk '{print $1}')
[ -n "$remote_tag" ] || remote_tag=$(git ls-remote origin "refs/tags/$tag" | awk '{print $1}')
if [ -n "$remote_tag" ] && [ "$remote_tag" != "$commit" ]; then
  echo "$tag is already on origin at ${remote_tag:0:7}, not origin/main (${commit:0:7})." >&2
  exit 1
fi

status=$(curl -s -o /dev/null -w '%{http_code}' "https://pub.dev/api/packages/$package/versions/$version" || true)
if [ "$status" = 200 ]; then
  echo "$package $version is already on pub.dev; not publishing it again."
else
  dart pub get >/dev/null
  # pub get can rewrite the lockfile; dart pub publish refuses a dirty tree.
  git checkout -q -- pubspec.lock 2>/dev/null || true

  echo "Analyzing"
  dart analyze . --fatal-infos --fatal-warnings
  echo "Testing"
  dart test

  if [ -n "$(git status --porcelain)" ]; then
    echo "The checkout changed while testing:" >&2
    git status --short >&2
    exit 1
  fi

  echo "Publishing $package $version"
  dart pub publish --force
fi

if [ -z "$remote_tag" ]; then
  echo "Tagging $tag at ${commit:0:7}"
  git tag -f -a "$tag" -m "$tag" "$commit"
  git push -q --no-verify origin "refs/tags/$tag"
else
  echo "$tag is already on origin at ${commit:0:7}"
fi

echo "Released $package $version"
