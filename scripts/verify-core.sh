#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift 6 toolchain is required for core verification."
  exit 1
fi

swift --version
swift package dump-package >/dev/null
swift build --configuration debug
# Exercise every test and full-size image case with production optimization.
# Keep the debug build above as a separate development-configuration check.
swift test --configuration release --enable-testable-imports --parallel

echo "CORE VERIFICATION: PASS"
