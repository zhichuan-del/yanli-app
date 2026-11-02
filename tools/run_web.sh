#!/bin/sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOOLS_DIR="$HOME/Developer/yanli-tools"
export PUB_CACHE="$TOOLS_DIR/pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true
export PATH="$TOOLS_DIR/flutter/bin:$PATH"
cd "$ROOT_DIR"
flutter pub get
./tools/start_voice.sh &
VOICE_PID=$!
trap 'kill "$VOICE_PID" 2>/dev/null || true' EXIT HUP INT TERM
flutter run -d chrome
