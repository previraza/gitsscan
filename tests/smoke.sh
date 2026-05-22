#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/bin/gitss" --version >/dev/null
"$ROOT/bin/gitss" --help >/dev/null
"$ROOT/bin/gitss" "$ROOT" --summary >/dev/null
"$ROOT/bin/gitss" "$ROOT" --json >/dev/null

echo "smoke: ok"
