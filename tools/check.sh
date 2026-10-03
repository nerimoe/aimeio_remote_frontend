#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
flutter_bin=${FLUTTER_BIN:-flutter}
"$flutter_bin" pub get --enforce-lockfile
"$(dirname -- "$(command -v "$flutter_bin")")/dart" format --output=none --set-exit-if-changed lib test
"$flutter_bin" analyze
"$flutter_bin" test
"$flutter_bin" build web --release
