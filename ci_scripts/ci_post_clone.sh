#!/bin/zsh
set -euo pipefail

echo "==> Flutter pub get"
flutter --version
flutter pub get

echo "==> Pods install"
cd ios
pod repo update
pod install
cd ..
