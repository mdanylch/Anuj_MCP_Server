#!/bin/sh
# App Runner *build* command: sh start.sh
#
# Install wheels into ./deps so they are copied with /app into the runtime image.
set -e
cd "$(dirname "$0")"
python3 --version
rm -rf deps
pip3 install --no-cache-dir -r requirements.txt -t deps
