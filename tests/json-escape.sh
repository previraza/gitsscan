#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_TMP="$(mktemp -d)"
TMP_DIR="$BASE_TMP/gitss-quote-\"dir"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$BASE_TMP"' EXIT

out="$("$ROOT"/bin/gitss "$TMP_DIR" --json)"

if ! printf '%s' "$out" | grep -q '\\"dir'; then
  echo "expected escaped quote in json output"
  echo "$out"
  exit 1
fi

echo "json-escape: ok"
