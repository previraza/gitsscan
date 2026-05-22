#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BIN="$(mktemp -d)"
trap 'rm -rf "$TMP_BIN"' EXIT

ln -s "$(command -v bash)" "$TMP_BIN/bash"
ln -s "$(command -v dirname)" "$TMP_BIN/dirname"
ln -s "$(command -v basename)" "$TMP_BIN/basename"
ln -s "$(command -v find)" "$TMP_BIN/find"
ln -s "$(command -v du)" "$TMP_BIN/du"
ln -s "$(command -v env)" "$TMP_BIN/env"

set +e
PATH="$TMP_BIN" bash "$ROOT/bin/gitss" . --summary >/tmp/gitss-no-path.out 2>/tmp/gitss-no-path.err
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo "expected failure when PATH has no required commands"
  exit 1
fi

if ! grep -q "Missing required commands" /tmp/gitss-no-path.err; then
  echo "expected missing command error"
  cat /tmp/gitss-no-path.err
  exit 1
fi

echo "missing-deps: ok"
