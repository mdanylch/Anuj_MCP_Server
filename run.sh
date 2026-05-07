#!/usr/bin/env sh
set -eu

# App Runner passes PORT by default (8080 unless configured otherwise).
if ! command -v node >/dev/null 2>&1; then
  echo "Node is not available at runtime. Ensure build step installed Node successfully." >&2
  exit 1
fi

npm start

