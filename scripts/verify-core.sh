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
swift test --parallel

echo "CORE VERIFICATION: PASS"
