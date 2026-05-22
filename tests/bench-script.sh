#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/repo"
(
  cd "$TMP/repo"
  git init >/dev/null
  git config user.name "t"
  git config user.email "t@e"
  echo '{"name":"repo"}' > package.json
  git add package.json
  git commit -m init >/dev/null
)

out="$("$ROOT"/scripts/bench-workers.sh "$TMP" mixed)"
if ! printf '%s' "$out" | grep -q 'workers'; then
  echo "expected benchmark header"
  echo "$out"
  exit 1
fi

echo "bench-script: ok"
