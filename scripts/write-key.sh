#!/bin/bash
# Writes the App Store Connect API key from $ASC_KEY_P8 to the file given as $1.
# Accepts the usual paste accidents: missing BEGIN/END lines, line breaks lost or turned into "\n", spaces, BOM.
# The logs of this repository are public: never print any part of the key here.
set -euo pipefail
export LC_ALL=C
out="$1"
fail() { echo "::error::$1"; exit 1; }

if printf '%s' "$ASC_KEY_P8" | grep -q 'BEGIN'; then begin=yes; else begin=no; fi
if printf '%s' "$ASC_KEY_P8" | grep -q 'END'; then end=yes; else end=no; fi
body=$(printf '%s' "$ASC_KEY_P8" | sed -E -e 's/[\][nr]//g' -e 's/(BEGIN|END) PRIVATE KEY//g' | tr -cd 'A-Za-z0-9+/=')
echo "ASC_KEY_P8: BEGIN line: $begin, END line: $end, key characters: ${#body} (about 200 expected)"

umask 077
{ echo '-----BEGIN PRIVATE KEY-----'; printf '%s\n' "$body" | fold -w 64; echo '-----END PRIVATE KEY-----'; } > "$out"
if ! openssl pkey -in "$out" -noout >/dev/null 2>&1; then
  rm -f "$out"
  fail "ASC_KEY_P8 is not a complete private key. Paste the full text of the AuthKey_XXXXXXXXXX.p8 file again."
fi
echo "ASC_KEY_P8: the private key is readable"

[[ "$ASC_KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "ASC_KEY_ID must be exactly 10 capital letters/digits, without spaces"
[[ "$ASC_ISSUER_ID" =~ ^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$ ]] || fail "ASC_ISSUER_ID must look like xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx, without spaces"
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "APPLE_TEAM_ID must be exactly 10 capital letters/digits, without spaces"
echo "Key ID, Issuer ID and Team ID have the right form"
