#!/usr/bin/env sh
# App Runner *start* command: sh run.sh
set -eu
cd "$(dirname "$0")"

# App Runner passes PORT by default (8080 unless configured otherwise).
if [ -x ".node/bin/node" ] && [ -x ".node/bin/npm" ]; then
  export PATH="$(pwd)/.node/bin:$PATH"
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node is not available at runtime. Ensure build step bundled Node into .node/." >&2
  exit 1
fi

npm start

