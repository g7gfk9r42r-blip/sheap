#!/bin/bash
set -euo pipefail

cd "${CI_WORKSPACE:-$(pwd)}/ios"
pod install
