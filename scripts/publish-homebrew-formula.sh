#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
SHA="${2:-}"
TAP_DIR="${3:-}"

if [[ -z "$VERSION" || -z "$SHA" || -z "$TAP_DIR" ]]; then
  echo "Usage: $0 <version_without_v> <sha256> <local_path_to_homebrew_tap_repo>"
  exit 1
fi

"$ROOT/scripts/update-homebrew-formula.sh" "$VERSION" "$SHA"

mkdir -p "$TAP_DIR/Formula"
cp "$ROOT/packaging/homebrew/gitss.rb" "$TAP_DIR/Formula/gitss.rb"

echo "Formula copied to: $TAP_DIR/Formula/gitss.rb"
echo "Next: cd $TAP_DIR && git add Formula/gitss.rb && git commit -m 'gitss ${VERSION}' && git push"
