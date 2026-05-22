#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  VERSION="$("$ROOT/bin/gitss" --version | awk '{print $2}')"
fi

VERSION="${VERSION#v}"
PKG_NAME="gitss_${VERSION}_linux_amd64"
STAGE_DIR="$DIST_DIR/$PKG_NAME"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
mkdir -p "$DIST_DIR"

cp -R "$ROOT/bin" "$STAGE_DIR/bin"
cp -R "$ROOT/lib" "$STAGE_DIR/lib"
cp -R "$ROOT/completions" "$STAGE_DIR/completions"
cp "$ROOT/install.sh" "$STAGE_DIR/install.sh"
cp "$ROOT/uninstall.sh" "$STAGE_DIR/uninstall.sh"
cp "$ROOT/LICENSE" "$STAGE_DIR/LICENSE"
cp "$ROOT/README.md" "$STAGE_DIR/README.md"

chmod +x "$STAGE_DIR/bin/gitss" "$STAGE_DIR/install.sh" "$STAGE_DIR/uninstall.sh"

(
  cd "$DIST_DIR"
  tar -czf "${PKG_NAME}.tar.gz" "$PKG_NAME"
)

sha256sum "$DIST_DIR/${PKG_NAME}.tar.gz" >"$DIST_DIR/${PKG_NAME}.tar.gz.sha256"

echo "Built: $DIST_DIR/${PKG_NAME}.tar.gz"
echo "Built: $DIST_DIR/${PKG_NAME}.tar.gz.sha256"
