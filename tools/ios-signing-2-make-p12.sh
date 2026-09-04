#!/usr/bin/env bash
# STEP 2 of 3 — run after downloading distribution.cer from Apple.
#
# Combines Apple's certificate with your private key into the .p12 that CI
# signs with, and prints the base64 you paste into a GitHub secret.
#
#   bash tools/ios-signing-2-make-p12.sh
#
# Put distribution.cer in tools/signing/ first.

set -euo pipefail

cd "$(dirname "$0")/.."
OUT="tools/signing"

[ -f "$OUT/ios_distribution.key" ] || {
  echo "No private key at $OUT/ios_distribution.key"
  echo "Run tools/ios-signing-1-make-csr.sh first."
  exit 1
}

CER=""
for c in "$OUT/distribution.cer" "$OUT/ios_distribution.cer" "$OUT"/*.cer; do
  [ -f "$c" ] && { CER="$c"; break; }
done
[ -n "$CER" ] || {
  echo "No .cer found in $OUT/"
  echo
  echo "Download it from developer.apple.com -> Certificates, after uploading"
  echo "the CSR that step 1 produced, and save it into $OUT/."
  exit 1
}
echo "Using certificate: $CER"

# A certificate carries only a PUBLIC key. It can only sign with the private key
# belonging to the CSR that produced it. Downloading an older certificate from
# Apple — one created on someone else's Mac, or from a different CSR — gives you
# a file that pairs with a key you do not have.
#
# openssl will happily bundle a mismatched pair into a .p12; the failure then
# surfaces on the CI runner as an unhelpful codesign error, half an hour later.
# Compare the public keys here instead, where it costs a second.
cert_pub=$(openssl x509 -inform DER -in "$CER" -noout -pubkey 2>/dev/null | openssl md5)
key_pub=$(openssl rsa -in "$OUT/ios_distribution.key" -pubout 2>/dev/null | openssl md5)
if [ "$cert_pub" != "$key_pub" ]; then
  echo
  echo "MISMATCH: that certificate does not belong to the private key here."
  echo
  echo "  certificate public key: $cert_pub"
  echo "  our private key:        $key_pub"
  echo
  echo "This happens when the certificate was created from a DIFFERENT CSR —"
  echo "usually one generated on another machine. Apple cannot re-issue the"
  echo "private key; only the Mac that made the original CSR has it."
  echo
  echo "Two ways forward:"
  echo "  1. Get a .p12 exported from the machine that created that certificate,"
  echo "     and skip this script entirely."
  echo "  2. Create a NEW certificate from our CSR:"
  echo "     $OUT/CertificateSigningRequest.certSigningRequest"
  echo "     If the certificate cap is full, revoke an unused one first."
  exit 1
fi
echo "Certificate matches the private key."

# Apple ships DER; OpenSSL wants PEM to bundle it with the key.
openssl x509 -inform DER -in "$CER" -out "$OUT/distribution.pem" -outform PEM

echo
echo "Choose an export password for the .p12. You will need it again as the"
echo "IOS_CERTIFICATE_PASSWORD secret, so put it in your password manager now."
echo "It protects the private key inside the file."
read -rsp "  Password: " P12PW; echo
read -rsp "  Again:    " P12PW2; echo
[ "$P12PW" = "$P12PW2" ] || { echo "They differ. Nothing written."; exit 1; }
[ -n "$P12PW" ] || { echo "An empty password is refused by Apple's tooling."; exit 1; }

# -legacy: Apple's codesign cannot read the AES-256 encryption OpenSSL 3
# defaults to. Without this the import fails on the runner with an unhelpful
# "MAC verification failed", which reads like a wrong password.
openssl pkcs12 -export -legacy \
  -inkey "$OUT/ios_distribution.key" \
  -in "$OUT/distribution.pem" \
  -out "$OUT/Certificates.p12" \
  -passout "pass:$P12PW"

base64 -w0 "$OUT/Certificates.p12" > "$OUT/certificate.base64.txt"

echo
echo "Wrote $OUT/Certificates.p12"
echo "Base64 for the secret is in $OUT/certificate.base64.txt"
echo
echo "Next: bash tools/ios-signing-3-set-secrets.sh"
