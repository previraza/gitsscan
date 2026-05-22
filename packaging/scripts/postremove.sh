#!/usr/bin/env bash
set -e

if [ -f /etc/bash_completion.d/gitss ]; then
  rm -f /etc/bash_completion.d/gitss
fi
