#!/bin/bash
set -euo pipefail

echo "== PATH =="
echo "$PATH"

echo "== Flutter pub get =="
flutter --version
flutter pub get

echo "== CocoaPods install =="
cd ios
pod --version
pod install
