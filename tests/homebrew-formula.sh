#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA="$ROOT/packaging/homebrew/gitss.rb"
TMP="$(mktemp)"
cp "$FORMULA" "$TMP"
trap 'cp "$TMP" "$FORMULA"; rm -f "$TMP"' EXIT

"$ROOT/scripts/update-homebrew-formula.sh" 3.0.1 deadbeef

if ! grep -q 'releases/download/v3.0.1/gitss_3.0.1_linux_amd64.tar.gz' "$FORMULA"; then
  echo "formula url was not updated"
  exit 1
fi

if ! grep -q 'sha256 "deadbeef"' "$FORMULA"; then
  echo "formula sha was not updated"
  exit 1
fi

echo "homebrew-formula: ok"
