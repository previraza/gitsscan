#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for cmd in bash git find du wc tr sed head awk dirname basename install; do
  if ! grep -q "for cmd in .*${cmd}" "$ROOT/install.sh"; then
    echo "expected install.sh to validate dependency: $cmd"
    exit 1
  fi
done

echo "install-deps: ok"
