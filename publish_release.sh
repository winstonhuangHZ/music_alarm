#!/usr/bin/env bash
# Publish a GitHub Release for Music Alarm using the GitHub CLI.
#
# Creates a release tag from VERSION (pushed if needed) and uploads:
#   - dist/MusicAlarm.dmg   (universal: Intel + Apple Silicon)
#
# Authentication is provided by `gh auth login` or the GH_TOKEN environment
# variable. Tokens are never read from files or passed to curl arguments.
#
# Usage:
#   ./publish_release.sh
set -euo pipefail

VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="${TAG:-v$VERSION}"
RELEASE_NAME="${RELEASE_NAME:-Music Alarm $VERSION}"
BODY_FILE="RELEASE_NOTES.md"
ASSETS=("dist/MusicAlarm.dmg")

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
fail() { echo -e "${RED}ERROR:${NC} $1"; exit 1; }

# ---- Resolve repository ----------------------------------------------------
REMOTE_URL="$(git config --get remote.origin.url || true)"
REPO="$(echo "$REMOTE_URL" | sed -E 's#https://github.com/([^/]+/[^/]+)(\.git)?$#\1#; s#git@github.com:([^/]+/[^/]+)(\.git)?$#\1#')"
[ -n "$REPO" ] || fail "Could not determine GitHub repo from remote.origin.url"
info "Repository: $REPO"

command -v gh >/dev/null 2>&1 || fail "gh CLI is required; authenticate with gh auth login."
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated. Run gh auth login."

git diff --quiet && [ -z "$(git status --porcelain)" ] || fail "Working tree has uncommitted changes."
HEAD_SHA="$(git rev-parse HEAD)"

# ---- Ensure the tag exists on the remote ------------------------------------
info "Ensuring tag $TAG exists on remote..."
if ! git ls-remote --tags origin "$TAG" 2>/dev/null | grep -q "refs/tags/$TAG"; then
  git push origin "$TAG" || fail "Failed to push tag $TAG"
else
  echo "   Tag $TAG already on remote."
fi

# ---- Check assets -------------------------------------------------------------
for a in "${ASSETS[@]}"; do
  [ -f "$a" ] || fail "Missing asset: $a"
done

BUILD_INFO="dist/MusicAlarm.app/Contents/Resources/MusicAlarm.build-info"
[ -f "$BUILD_INFO" ] || fail "Build metadata missing; rebuild before publishing."
[ "$(sed -n 's/^version=//p' "$BUILD_INFO")" = "$VERSION" ] \
  || fail "DMG was not built from VERSION=$VERSION."
[ "$(sed -n 's/^commit=//p' "$BUILD_INFO")" = "$HEAD_SHA" ] \
  || fail "DMG was not built from the current commit."

TAG_SHA="$(git rev-list -n 1 "$TAG" 2>/dev/null || true)"
[ "$TAG_SHA" = "$HEAD_SHA" ] || fail "Tag $TAG does not point at HEAD."

info "Creating or updating release $TAG ..."
gh release create "$TAG" "${ASSETS[@]}" --title "$RELEASE_NAME" --notes-file "$BODY_FILE" --verify-tag

echo ""
echo -e "${GREEN}Release published!${NC}"
echo "   https://github.com/$REPO/releases/tag/$TAG"
