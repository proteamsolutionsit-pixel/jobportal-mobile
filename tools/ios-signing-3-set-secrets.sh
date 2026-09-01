#!/usr/bin/env bash
# STEP 3 of 3 — pushes the secrets into GitHub.
#
#   bash tools/ios-signing-3-set-secrets.sh
#
# Everything goes straight from this machine to GitHub over gh. Nothing is
# printed, logged, committed, or shown to anyone — including me.
#
# Needs, in tools/signing/:
#   Certificates.p12                    from step 2
#   JobPortal_AppStore.mobileprovision  downloaded from Apple
#   AuthKey_XXXXXXXXXX.p8               downloaded from App Store Connect

set -euo pipefail

cd "$(dirname "$0")/.."
OUT="tools/signing"
REPO="proteamsolutionsit-pixel/jobportal-mobile"

gh auth status >/dev/null 2>&1 || { echo "Run: gh auth login"; exit 1; }
# The personal account is the default active one; this repo belongs to the
# business account.
gh auth switch --user proteamsolutionsit-pixel >/dev/null 2>&1 || true

set_secret () {  # name, value
  printf '%s' "$2" | gh secret set "$1" --repo "$REPO" --body -
  echo "  set $1"
}

echo "Setting secrets on $REPO"
echo

# --- certificate -------------------------------------------------------------
[ -f "$OUT/Certificates.p12" ] || { echo "Missing $OUT/Certificates.p12 (run step 2)"; exit 1; }
set_secret IOS_CERTIFICATE_BASE64 "$(base64 -w0 "$OUT/Certificates.p12")"

read -rsp "The .p12 export password from step 2: " P12PW; echo
[ -n "$P12PW" ] || { echo "Empty. Stopping."; exit 1; }
set_secret IOS_CERTIFICATE_PASSWORD "$P12PW"

# --- provisioning profile ----------------------------------------------------
PROFILE=""
for p in "$OUT"/*.mobileprovision; do [ -f "$p" ] && { PROFILE="$p"; break; }; done
[ -n "$PROFILE" ] || {
  echo
  echo "No .mobileprovision in $OUT/"
  echo "developer.apple.com -> Profiles -> + -> Distribution -> App Store Connect"
  exit 1
}
echo "  using profile: $PROFILE"
set_secret IOS_PROVISIONING_PROFILE_BASE64 "$(base64 -w0 "$PROFILE")"

# --- team id -----------------------------------------------------------------
echo
echo "Team ID: developer.apple.com -> Membership. Ten characters, e.g. A1B2C3D4E5"
read -rp "  IOS_TEAM_ID: " TEAM
[ -n "$TEAM" ] || { echo "Empty. Stopping."; exit 1; }
set_secret IOS_TEAM_ID "$TEAM"

# --- App Store Connect API key (optional) ------------------------------------
# Without these the workflow still builds a signed IPA; it just skips the
# TestFlight upload.
P8=""
for k in "$OUT"/AuthKey_*.p8; do [ -f "$k" ] && { P8="$k"; break; }; done
if [ -n "$P8" ]; then
  echo
  echo "  using API key: $P8"
  KEYID=$(basename "$P8" .p8); KEYID=${KEYID#AuthKey_}
  set_secret APPSTORE_KEY_ID "$KEYID"
  set_secret APPSTORE_PRIVATE_KEY "$(cat "$P8")"
  echo
  echo "Issuer ID: App Store Connect -> Users and Access -> Integrations."
  echo "A UUID, the same for every key in your account."
  read -rp "  APPSTORE_ISSUER_ID: " ISSUER
  [ -n "$ISSUER" ] && set_secret APPSTORE_ISSUER_ID "$ISSUER"
else
  echo
  echo "No AuthKey_*.p8 found — skipping the TestFlight upload secrets."
  echo "The workflow will still build a signed IPA you can download."
fi

echo
echo "Secrets now on the repo:"
gh secret list --repo "$REPO"

echo
echo "Run the build:  gh workflow run release-ios.yml --repo $REPO -f environment=staging"
echo
echo "SECURITY: tools/signing/ holds your private key, .p12 and .p8. It is"
echo "git-ignored. Back it up somewhere safe and do not email or paste it."
