#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR='/tmp/gitss-quote-"dir'
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

out="$("$ROOT"/bin/gitss "$TMP_DIR" --json)"

if ! printf '%s' "$out" | grep -q '\\"dir'; then
  echo "expected escaped quote in json output"
  echo "$out"
  exit 1
fi

echo "json-escape: ok"
