#!/usr/bin/env bash
set -euo pipefail

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }

echo "🧹 Cleaning generated data files and logs..."

# Remove data directory
if [ -d "data" ]; then
  rm -rf data
  green "✅ Removed data/ directory"
else
  echo "ℹ️  data/ directory not found"
fi

# Remove logs directory
if [ -d "logs" ]; then
  rm -rf logs
  green "✅ Removed logs/ directory"
else
  echo "ℹ️  logs/ directory not found"
fi

# Remove any other generated files
if [ -f "offers.json" ]; then
  rm -f offers.json
  green "✅ Removed offers.json"
fi

if [ -f "recipes.json" ]; then
  rm -f recipes.json
  green "✅ Removed recipes.json"
fi

# Clean Flutter build artifacts
if [ -d "build" ]; then
  rm -rf build
  green "✅ Removed Flutter build/ directory"
fi

# Clean Flutter dependencies
if [ -f "pubspec.lock" ]; then
  rm -f pubspec.lock
  green "✅ Removed pubspec.lock"
fi

# Clean server dependencies
if [ -d "server/node_modules" ]; then
  rm -rf server/node_modules
  green "✅ Removed server/node_modules"
fi

if [ -f "server/package-lock.json" ]; then
  rm -f server/package-lock.json
  green "✅ Removed server/package-lock.json"
fi

green "🎉 Clean complete! Fresh development environment ready."
