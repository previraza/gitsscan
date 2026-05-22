#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="${1:-}"
[[ -n "$VERSION" ]] || { echo "Usage: $0 vX.Y.Z"; exit 1; }

if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must match vX.Y.Z"
  exit 1
fi

git diff --quiet || { echo "Working tree is dirty"; exit 1; }

git tag "$VERSION"
git push origin "$VERSION"
echo "Tagged and pushed $VERSION"
