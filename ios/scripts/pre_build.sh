#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

resolve_flutter_bin() {
  if [[ -n "${FLUTTER_ROOT:-}" && -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
    echo "${FLUTTER_ROOT}/bin/flutter"
    return 0
  fi

  if [[ -x "${HOME}/flutter/bin/flutter" ]]; then
    echo "${HOME}/flutter/bin/flutter"
    return 0
  fi

  if command -v flutter >/dev/null 2>&1; then
    command -v flutter
    return 0
  fi

  return 1
}

FLUTTER_BIN="$(resolve_flutter_bin || true)"
if [[ -z "${FLUTTER_BIN}" ]]; then
  echo "ERROR: flutter not found. Expected one of:"
  echo "  - \$FLUTTER_ROOT/bin/flutter"
  echo "  - \$HOME/flutter/bin/flutter"
  echo "  - flutter in PATH"
  exit 127
fi

echo "Using Flutter binary: ${FLUTTER_BIN}"
cd "${REPO_ROOT}"
"${FLUTTER_BIN}" pub get
cd "${REPO_ROOT}/ios"
pod install
