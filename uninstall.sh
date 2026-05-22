#!/usr/bin/env bash
set -Eeuo pipefail

PREFIX="/usr/local"
BIN_PATH="$PREFIX/bin/gitss"

for arg in "$@"; do
  case "$arg" in
  --prefix=*)
    PREFIX="${arg#*=}"
    BIN_PATH="$PREFIX/bin/gitss"
    ;;
  -h | --help)
    echo "Usage: ./uninstall.sh [--prefix=/custom/path]"
    exit 0
    ;;
  *)
    echo "Unknown option: $arg"
    exit 1
    ;;
  esac
done

if [[ ! -e "$BIN_PATH" ]]; then
  echo "Nothing to uninstall: $BIN_PATH"
  exit 0
fi

if [[ -w "$BIN_PATH" ]]; then
  rm -f "$BIN_PATH"
else
  sudo rm -f "$BIN_PATH"
fi

echo "Uninstalled: $BIN_PATH"
