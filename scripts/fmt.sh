#!/usr/bin/env bash
set -Eeuo pipefail

shfmt -w -i 2 bin/gitss lib/*.sh install.sh uninstall.sh scripts/*.sh tests/*.sh packaging/scripts/*.sh
