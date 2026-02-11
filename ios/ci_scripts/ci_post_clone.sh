#!/bin/bash
set -euo pipefail

echo "=== CI WORKSPACE ==="
echo "PWD: $(pwd)"
echo "CI_WORKSPACE: ${CI_WORKSPACE:-<not set>}"

# immer ins Repo-Root
cd "${CI_WORKSPACE:-$(pwd)}"

echo "=== Check tools ==="
command -v git || true
command -v ruby || true
command -v pod || true
command -v flutter || true

# 1) Flutter installieren, falls nicht vorhanden
if ! command -v flutter >/dev/null 2>&1; then
  echo "=== Flutter not found -> installing (stable) ==="
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

echo "=== Flutter version ==="
flutter --version

echo "=== Flutter pub get ==="
flutter pub get

echo "=== CocoaPods install ==="
cd ios
pod --version
pod install --repo-update
