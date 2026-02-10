#!/bin/bash
set -e

cd "$(dirname "$0")/../../"
flutter pub get
cd ios
pod install
