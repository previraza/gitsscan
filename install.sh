#!/usr/bin/env bash
set -Eeuo pipefail

PREFIX="/usr/local"
BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib/gitss"
INSTALL_NAME="gitss"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN="$PROJECT_DIR/bin/gitss"

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing dependency: $cmd"
    exit 1
  }
}

usage() {
  cat <<USAGE
Usage: ./install.sh [--prefix=/custom/path]
USAGE
}

for arg in "$@"; do
  case "$arg" in
  --prefix=*)
    PREFIX="${arg#*=}"
    BIN_DIR="$PREFIX/bin"
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $arg"
    usage
    exit 1
    ;;
  esac
done

for cmd in bash git find du wc tr sed head awk dirname basename install; do
  require_cmd "$cmd"
done

[[ -x "$SOURCE_BIN" ]] || {
  echo "Source binary not found: $SOURCE_BIN"
  exit 1
}

install_libs() {
  if [[ ! -w "$PREFIX/lib" ]]; then
    sudo mkdir -p "$LIB_DIR"
    sudo rm -rf "$LIB_DIR/lib"
    sudo cp -R "$PROJECT_DIR/lib" "$LIB_DIR/lib"
  else
    mkdir -p "$LIB_DIR"
    rm -rf "$LIB_DIR/lib"
    cp -R "$PROJECT_DIR/lib" "$LIB_DIR/lib"
  fi
}

if [[ ! -w "$BIN_DIR" ]]; then
  echo "Installing to $BIN_DIR requires elevated permissions."
  sudo mkdir -p "$BIN_DIR"
  sudo install -m 0755 "$SOURCE_BIN" "$BIN_DIR/$INSTALL_NAME"
else
  mkdir -p "$BIN_DIR"
  install -m 0755 "$SOURCE_BIN" "$BIN_DIR/$INSTALL_NAME"
fi

install_libs

echo "Installed: $BIN_DIR/$INSTALL_NAME"
"$BIN_DIR/$INSTALL_NAME" --version || true
