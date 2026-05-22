#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA="$ROOT/packaging/homebrew/gitss.rb"
VERSION="${1:-}"
SHA="${2:-}"

if [[ -z "$VERSION" || -z "$SHA" ]]; then
  echo "Usage: $0 <version_without_v> <sha256>"
  exit 1
fi

sed -i "s|releases/download/v[0-9]\+\.[0-9]\+\.[0-9]\+/gitss_[0-9]\+\.[0-9]\+\.[0-9]\+_linux_amd64.tar.gz|releases/download/v${VERSION}/gitss_${VERSION}_linux_amd64.tar.gz|g" "$FORMULA"
sed -i "s|sha256 \".*\"|sha256 \"${SHA}\"|g" "$FORMULA"
sed -i "s|gitss_[0-9]\+\.[0-9]\+\.[0-9]\+_linux_amd64|gitss_${VERSION}_linux_amd64|g" "$FORMULA"

echo "Updated formula: $FORMULA"
