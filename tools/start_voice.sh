#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v node >/dev/null 2>&1; then
  for NODE_BIN in "$HOME"/.nvm/versions/node/*/bin; do
    if [ -x "$NODE_BIN/node" ]; then export PATH="$NODE_BIN:$PATH"; fi
  done
fi
exec node "$ROOT_DIR/tools/voice_server.mjs"
