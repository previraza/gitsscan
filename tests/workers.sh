#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SCAN="$TMP/scan"
mkdir -p "$SCAN/a" "$SCAN/b"

(
  cd "$SCAN/a"
  git init >/dev/null
  git config user.name "t"
  git config user.email "t@e"
  echo '{"name":"a"}' >package.json
  git add package.json
  git commit -m "init" >/dev/null
)

(
  cd "$SCAN/b"
  git init >/dev/null
  git config user.name "t"
  git config user.email "t@e"
  echo 'package main' >main.go
  git add main.go
  git commit -m "init" >/dev/null
)

j1="$("$ROOT"/bin/gitss "$SCAN" --scan-mode=git --workers=1 --json)"
j4="$("$ROOT"/bin/gitss "$SCAN" --scan-mode=git --workers=4 --json)"

for key in '"displayed": 2' '"clean": 2' '"dirty": 0' '"no_git": 0'; do
  if ! printf '%s' "$j1" | grep -q "$key"; then
    echo "workers=1 missing key: $key"
    echo "$j1"
    exit 1
  fi
  if ! printf '%s' "$j4" | grep -q "$key"; then
    echo "workers=4 missing key: $key"
    echo "$j4"
    exit 1
  fi
done

echo "workers: ok"
