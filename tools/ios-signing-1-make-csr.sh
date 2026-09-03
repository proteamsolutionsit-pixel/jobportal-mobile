#!/usr/bin/env bash
# STEP 1 of 3 — run this FIRST, on this Windows machine (Git Bash).
#
# Creates the private key and the certificate signing request you upload to
# Apple. No Mac needed: this is what Keychain Access does on a Mac, done with
# OpenSSL instead.
#
#   bash tools/ios-signing-1-make-csr.sh
#
# Produces, in tools/signing/ (git-ignored):
#   ios_distribution.key   your PRIVATE KEY — never leaves this machine, never
#                          goes in the repo, never gets pasted anywhere
#   CertificateSigningRequest.certSigningRequest   upload THIS to Apple

set -euo pipefail

cd "$(dirname "$0")/.."
OUT="tools/signing"
mkdir -p "$OUT"

if [ -f "$OUT/ios_distribution.key" ]; then
  echo "A key already exists at $OUT/ios_distribution.key"
  echo
  echo "Reusing it is usually right — a new key means a new certificate and"
  echo "invalidates any profile built on the old one. Delete it by hand only if"
  echo "you know you want to start over."
  exit 1
fi

echo "Apple puts these in the certificate. They are cosmetic for App Store"
echo "distribution, but they must not be blank."
read -rp "  Your email: " EMAIL
read -rp "  Your name or company [ProTeam Solutions]: " CN
CN="${CN:-ProTeam Solutions}"

openssl genrsa -out "$OUT/ios_distribution.key" 2048
# MSYS_NO_PATHCONV: Git Bash rewrites arguments that look like unix paths, so
# -subj "/emailAddress=..." arrives as "C:/Program Files/Git/emailAddress=..."
# and openssl rejects it. Only this line needs it.
MSYS_NO_PATHCONV=1 openssl req -new \
  -key "$OUT/ios_distribution.key" \
  -out "$OUT/CertificateSigningRequest.certSigningRequest" \
  -subj "/emailAddress=${EMAIL}/CN=${CN}/C=IN"

echo
echo "Done."
echo
echo "  Private key   $OUT/ios_distribution.key   <- keep, never share"
echo "  Upload this   $OUT/CertificateSigningRequest.certSigningRequest"
echo
echo "Next: developer.apple.com -> Certificates, IDs & Profiles -> Certificates"
echo "-> + -> iOS Distribution (App Store Connect and Ad Hoc) -> upload the .certSigningRequest above."
echo "Download the resulting distribution.cer into $OUT/, then run:"
echo
echo "  bash tools/ios-signing-2-make-p12.sh"
