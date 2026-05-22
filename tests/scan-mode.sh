#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SCAN="$TMP/scan"
mkdir -p "$SCAN/webapp" "$SCAN/gorepo"

(
  cd "$SCAN/webapp"
  git init >/dev/null
  git config user.name "t"
  git config user.email "t@e"
  echo '{"name":"webapp"}' >package.json
  git add package.json
  git commit -m "init" >/dev/null
)

(
  cd "$SCAN/gorepo"
  git init >/dev/null
  git config user.name "t"
  git config user.email "t@e"
  echo 'package main' >main.go
  git add main.go
  git commit -m "init" >/dev/null
)

web_json="$("$ROOT"/bin/gitss "$SCAN" --scan-mode=web --json)"
if ! printf '%s' "$web_json" | grep -q '"path": ".*webapp"'; then
  echo "expected web mode to include webapp"
  echo "$web_json"
  exit 1
fi
if printf '%s' "$web_json" | grep -q '"path": ".*gorepo"'; then
  echo "expected web mode to exclude non-web git repos"
  echo "$web_json"
  exit 1
fi

git_json="$("$ROOT"/bin/gitss "$SCAN" --scan-mode=git --json)"
if ! printf '%s' "$git_json" | grep -q '"path": ".*webapp"'; then
  echo "expected git mode to include webapp"
  echo "$git_json"
  exit 1
fi
if ! printf '%s' "$git_json" | grep -q '"path": ".*gorepo"'; then
  echo "expected git mode to include gorepo"
  echo "$git_json"
  exit 1
fi

mixed_json="$("$ROOT"/bin/gitss "$SCAN" --json)"
if ! printf '%s' "$mixed_json" | grep -q '"path": ".*webapp"'; then
  echo "expected default mixed mode to include webapp"
  echo "$mixed_json"
  exit 1
fi
if ! printf '%s' "$mixed_json" | grep -q '"path": ".*gorepo"'; then
  echo "expected default mixed mode to include gorepo"
  echo "$mixed_json"
  exit 1
fi

echo "scan-mode: ok"
