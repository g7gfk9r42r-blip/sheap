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

echo "=== Firebase plist setup (iOS) ==="
IOS_PLIST_PATH="$REPO_ROOT/ios/Runner/GoogleService-Info.plist"
if [[ ! -f "$IOS_PLIST_PATH" ]]; then
  if [[ -n "${FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST_BASE64:-}" ]]; then
    echo "Writing GoogleService-Info.plist from FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST_BASE64"
    if ! printf "%s" "$FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST_BASE64" | base64 --decode > "$IOS_PLIST_PATH" 2>/dev/null; then
      printf "%s" "$FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST_BASE64" | base64 -D > "$IOS_PLIST_PATH"
    fi
  elif [[ -n "${FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST:-}" ]]; then
    echo "Writing GoogleService-Info.plist from FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST"
    printf "%s" "$FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST" > "$IOS_PLIST_PATH"
  else
    echo "ERROR: Missing Firebase iOS plist for CI."
    echo "Set one of these Xcode Cloud environment variables:"
    echo "  - FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST_BASE64"
    echo "  - FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST"
    exit 1
  fi
fi

if [[ ! -s "$IOS_PLIST_PATH" ]]; then
  echo "ERROR: Generated $IOS_PLIST_PATH is empty."
  exit 1
fi

if ! grep -q "<plist" "$IOS_PLIST_PATH"; then
  echo "ERROR: $IOS_PLIST_PATH does not look like a valid plist."
  exit 1
fi

echo "=== CocoaPods install ==="
cd ios
pod --version
pod install --repo-update
