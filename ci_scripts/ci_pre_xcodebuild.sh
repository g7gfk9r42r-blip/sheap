#!/bin/bash
set -euo pipefail

echo "== Pre-xcodebuild: ensure pods present =="
cd ios
pod install
