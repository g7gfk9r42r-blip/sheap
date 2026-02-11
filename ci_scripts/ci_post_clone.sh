#!/bin/bash
set -euo pipefail

# Ensure repo root
REPO_ROOT="${CI_WORKSPACE:-$(pwd)}"
cd "$REPO_ROOT"

# Delegate to ios script
./ios/ci_scripts/ci_post_clone.sh
