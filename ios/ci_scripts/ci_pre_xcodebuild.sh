#!/bin/zsh
set -euo pipefail

echo "==> Ensure Generated.xcconfig exists"
flutter pub get
flutter build ios --release --no-codesign
