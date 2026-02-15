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

first_non_empty_var() {
  for name in "$@"; do
    if [[ -n "${!name:-}" ]]; then
      echo "$name"
      return 0
    fi
  done
  return 1
}

present_secret_names() {
  env | cut -d= -f1 | grep -E "GOOGLESERVICE|GOOGLE_SERVICE|FIREBASE_IOS.*PLIST" || true
}

if [[ ! -f "$IOS_PLIST_PATH" ]]; then
  PLIST_B64_VAR="$(first_non_empty_var \
    FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST_BASE64 \
    FIREBASE_IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64 \
    GOOGLE_SERVICE_INFO_PLIST_BASE64 \
    GOOGLESERVICE_INFO_PLIST_BASE64 \
  || true)"
  PLIST_RAW_VAR="$(first_non_empty_var \
    FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST \
    FIREBASE_IOS_GOOGLE_SERVICE_INFO_PLIST \
    GOOGLE_SERVICE_INFO_PLIST \
    GOOGLESERVICE_INFO_PLIST \
  || true)"

  if [[ -n "$PLIST_B64_VAR" ]]; then
    echo "Writing GoogleService-Info.plist from ${PLIST_B64_VAR}"
    B64_CONTENT="$(printf "%s" "${!PLIST_B64_VAR}" | tr -d '[:space:]')"
    # Common copy artifact from zsh prompt when users copy terminal output.
    B64_CONTENT="${B64_CONTENT%%%}"
    if ! printf "%s" "$B64_CONTENT" | base64 --decode > "$IOS_PLIST_PATH" 2>/dev/null; then
      printf "%s" "$B64_CONTENT" | base64 -D > "$IOS_PLIST_PATH"
    fi
  elif [[ -n "$PLIST_RAW_VAR" ]]; then
    echo "Writing GoogleService-Info.plist from ${PLIST_RAW_VAR}"
    printf "%s" "${!PLIST_RAW_VAR}" > "$IOS_PLIST_PATH"
  else
    echo "ERROR: Missing Firebase iOS plist for CI."
    echo "Set one of these Xcode Cloud environment variables (Secret):"
    echo "  - FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST_BASE64"
    echo "  - FIREBASE_IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64"
    echo "  - GOOGLE_SERVICE_INFO_PLIST_BASE64"
    echo "  - GOOGLESERVICE_INFO_PLIST_BASE64"
    echo "  - FIREBASE_IOS_GOOGLESERVICE_INFO_PLIST"
    echo "  - FIREBASE_IOS_GOOGLE_SERVICE_INFO_PLIST"
    echo "  - GOOGLE_SERVICE_INFO_PLIST"
    echo "  - GOOGLESERVICE_INFO_PLIST"
    echo "Detected related env names:"
    present_secret_names
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

if ! plutil -lint "$IOS_PLIST_PATH"; then
  echo "ERROR: $IOS_PLIST_PATH is not a valid property list."
  exit 1
fi

# Normalize to canonical XML plist to avoid parser quirks in xcodebuild.
if ! plutil -convert xml1 "$IOS_PLIST_PATH" -o "$IOS_PLIST_PATH"; then
  echo "ERROR: Failed to normalize $IOS_PLIST_PATH via plutil."
  exit 1
fi

echo "Validating key iOS plist files..."
for p in "$REPO_ROOT/ios/Runner/Info.plist" "$IOS_PLIST_PATH"; do
  if ! plutil -lint "$p"; then
    echo "ERROR: Invalid plist detected: $p"
    exit 1
  fi
done

echo "=== CocoaPods install ==="
cd "$(dirname "$0")/.."
export COCOAPODS_DISABLE_STATS=true
pod install --no-repo-update
