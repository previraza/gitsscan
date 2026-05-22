#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$ROOT/dist"
"$ROOT/scripts/build-release-assets.sh" 3.0.0 >/dev/null

if [[ ! -f "$ROOT/dist/gitss_3.0.0_linux_amd64.tar.gz" ]]; then
  echo "missing release tarball"
  exit 1
fi

if [[ ! -f "$ROOT/dist/gitss_3.0.0_linux_amd64.tar.gz.sha256" ]]; then
  echo "missing release checksum"
  exit 1
fi

echo "release-assets: ok"
