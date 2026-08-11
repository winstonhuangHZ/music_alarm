#!/usr/bin/env bash
# Publish a GitHub Release for Music Alarm using the REST API.
#
# Creates release tag v1.0.0 (pushed if needed) and uploads:
#   - dist/MusicAlarm_v1.dmg   (universal: Intel + Apple Silicon)
#   - dist/MusicAlarm_v2.dmg   (universal: Intel + Apple Silicon)
#
# Auth (first one wins):
#   1. $GH_TOKEN environment variable
#   2. ./.gh_token file (plain token; git-ignored, never committed)
#   3. `gh auth token` (if the gh CLI is installed & logged in)
#
# Usage:
#   ./publish_release.sh
set -euo pipefail

TAG="${TAG:-v1.0.0}"
RELEASE_NAME="${RELEASE_NAME:-Music Alarm v1.0.0}"
BODY_FILE="RELEASE_NOTES.md"
ASSETS=("dist/MusicAlarm_v1.dmg" "dist/MusicAlarm_v2.dmg")

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}==>${NC} $1"; }
fail() { echo -e "${RED}ERROR:${NC} $1"; exit 1; }

# ---- Resolve repository ----------------------------------------------------
REMOTE_URL="$(git config --get remote.origin.url || true)"
REPO="$(echo "$REMOTE_URL" | sed -E 's#https://github.com/([^/]+/[^/]+)(\.git)?$#\1#; s#git@github.com:([^/]+/[^/]+)(\.git)?$#\1#')"
[ -n "$REPO" ] || fail "Could not determine GitHub repo from remote.origin.url"
info "Repository: $REPO"

# ---- Resolve token ----------------------------------------------------------
TOKEN="${GH_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f ".gh_token" ]; then
  TOKEN="$(tr -d '[:space:]' < .gh_token)"
fi
if [ -z "$TOKEN" ] && command -v gh >/dev/null 2>&1; then
  TOKEN="$(gh auth token 2>/dev/null || true)"
fi
[ -n "$TOKEN" ] || fail "No GitHub token found. Run: export GH_TOKEN=xxx  (or create a .gh_token file)"

API="https://api.github.com/repos/$REPO"
AUTH="Authorization: Bearer $TOKEN"
ACCEPT="Accept: application/vnd.github+json"

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

# ---- Create or reuse the release ---------------------------------------------
info "Creating release $TAG ..."
BODY="$(cat "$BODY_FILE")"
CREATE_JSON="$(jq -n --arg tag "$TAG" --arg name "$RELEASE_NAME" --arg body "$BODY" \
  '{tag_name:$tag, name:$name, body:$body, draft:false, prerelease:false}')"

CREATE_RESPONSE="$(curl -fsS -X POST -H "$AUTH" -H "$ACCEPT" -H "Content-Type: application/json" \
  -d "$CREATE_JSON" "$API/releases" 2>/dev/null || true)"
RELEASE_ID="$(echo "$CREATE_RESPONSE" | jq -r '.id // empty')"
if [ -z "$RELEASE_ID" ]; then
  echo "   Release may already exist; fetching existing..."
  RELEASE_ID="$(curl -fsS -H "$AUTH" -H "$ACCEPT" "$API/releases/tags/$TAG" | jq -r '.id // empty')"
fi
[ -n "$RELEASE_ID" ] || fail "Could not create/find the release for tag $TAG"

# ---- Upload assets -------------------------------------------------------------
for a in "${ASSETS[@]}"; do
  NAME="$(basename "$a")"
  info "Uploading $NAME ..."
  curl -fsS -X POST -H "$AUTH" -H "$ACCEPT" -H "Content-Type: application/octet-stream" \
    --data-binary "@$a" \
    "$API/releases/$RELEASE_ID/assets?name=$NAME" >/dev/null \
    || fail "Failed to upload $NAME"
  echo "   Uploaded $NAME"
done

echo ""
echo -e "${GREEN}Release published!${NC}"
echo "   https://github.com/$REPO/releases/tag/$TAG"
