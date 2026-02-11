#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== CI WORKSPACE ==="
echo "PWD: $(pwd)"
echo "CI_WORKSPACE: ${CI_WORKSPACE:-<not set>}"

# Always operate from repo root
cd "$REPO_ROOT"

echo "=== Check tools ==="
command -v git || true
command -v ruby || true
command -v pod || true
command -v flutter || true

# Install Flutter if missing
if ! command -v flutter >/dev/null 2>&1; then
  echo "=== Flutter not found -> installing (stable) ==="
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

# Use explicit flutter path if needed
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/flutter/bin/flutter" ]; then
  export PATH="$HOME/flutter/bin:$PATH"
fi

echo "=== Flutter version ==="
flutter --version

echo "=== Flutter precache (iOS) ==="
flutter precache --ios

echo "=== Flutter pub get ==="
flutter pub get

echo "=== CocoaPods install ==="
cd ios
pod --version
pod install --repo-update
