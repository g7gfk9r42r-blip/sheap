#!/bin/bash
set -euo pipefail

REPO_ROOT="${CI_WORKSPACE:-$(pwd)}"
cd "$REPO_ROOT"

# Delegate to ios script
./ios/ci_scripts/ci_pre_xcodebuild.sh
