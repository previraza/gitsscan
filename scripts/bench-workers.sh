#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-.}"
SCAN_MODE="${2:-mixed}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Usage: $0 [target_dir] [scan_mode]"
  echo "Example: $0 /srv/projects mixed"
  exit 1
fi

if [[ "$SCAN_MODE" != "mixed" && "$SCAN_MODE" != "web" && "$SCAN_MODE" != "git" ]]; then
  echo "scan_mode must be one of: mixed, web, git"
  exit 1
fi

echo "Benchmark target: $TARGET_DIR"
echo "Scan mode: $SCAN_MODE"
echo
printf '%-10s %-12s\n' "workers" "elapsed"
printf '%-10s %-12s\n' "-------" "-------"

for n in 1 2 4 8; do
  start="$(date +%s)"
  "$ROOT/bin/gitss" "$TARGET_DIR" --scan-mode="$SCAN_MODE" --workers="$n" --summary >/dev/null
  end="$(date +%s)"
  elapsed=$((end - start))
  printf '%-10s %-12ss\n' "$n" "$elapsed"
done
