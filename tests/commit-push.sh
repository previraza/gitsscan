#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

REMOTE="$WORKDIR/remote.git"
SCAN_ROOT="$WORKDIR/scan"
REPO="$SCAN_ROOT/app"

mkdir -p "$SCAN_ROOT"
git init --bare "$REMOTE" >/dev/null
mkdir -p "$REPO"

(
  cd "$REPO"
  git init >/dev/null
  git config user.name "GitSScan Test"
  git config user.email "gitss@example.test"
  git remote add origin "$REMOTE"

  echo '{"name":"app"}' > package.json
  echo "v1" > file.txt
  git add -A
  git commit -m "init" >/dev/null
  git branch -M main
  git push -u origin main >/dev/null
)

remote_head_before="$(git --git-dir="$REMOTE" rev-parse refs/heads/main)"

(
  cd "$REPO"
  echo "v2" >> file.txt
)

"$ROOT/bin/gitss" "$SCAN_ROOT" --dirty --commit="GitSScan integration" --push --unsafe --summary >/tmp/gitss-commit-push-unsafe.out 2>/tmp/gitss-commit-push-unsafe.err

remote_head_after_unsafe="$(git --git-dir="$REMOTE" rev-parse refs/heads/main)"
if [[ "$remote_head_before" == "$remote_head_after_unsafe" ]]; then
  echo "expected remote head to change after --commit --push --unsafe"
  exit 1
fi

(
  cd "$REPO"
  echo "v3" >> file.txt
)

set +e
"$ROOT/bin/gitss" "$SCAN_ROOT" --dirty --commit="GitSScan safe mode" --push --summary >/tmp/gitss-commit-push-safe.out 2>/tmp/gitss-commit-push-safe.err
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "expected safe mode run to complete"
  exit 1
fi

remote_head_after_safe="$(git --git-dir="$REMOTE" rev-parse refs/heads/main)"
local_head_after_safe="$(git -C "$REPO" rev-parse HEAD)"

if [[ "$remote_head_after_safe" == "$local_head_after_safe" ]]; then
  echo "expected safe mode non-interactive push to be skipped"
  exit 1
fi

if ! grep -q "Non-interactive mode detected: action skipped in safe mode" /tmp/gitss-commit-push-safe.err; then
  echo "expected safe mode non-interactive warning"
  cat /tmp/gitss-commit-push-safe.err
  exit 1
fi

echo "commit-push: ok"
