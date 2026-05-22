#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$ROOT/dist"
VERSION_RAW="$("$ROOT/bin/gitss" --version | awk '{print $2}')"
VERSION="${VERSION_RAW#v}"
"$ROOT/scripts/build-release-assets.sh" "$VERSION" >/dev/null

if [[ ! -f "$ROOT/dist/gitss_${VERSION}_linux_amd64.tar.gz" ]]; then
  echo "missing release tarball"
  exit 1
fi

if [[ ! -f "$ROOT/dist/gitss_${VERSION}_linux_amd64.tar.gz.sha256" ]]; then
  echo "missing release checksum"
  exit 1
fi

echo "release-assets: ok"
