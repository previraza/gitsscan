#!/usr/bin/env bash
set -e

if [ -x /usr/local/bin/gitss ]; then
  /usr/local/bin/gitss --version || true
fi
