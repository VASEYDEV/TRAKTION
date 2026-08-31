#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The complete TRAKTION gate requires macOS for Apple ImageIO verification."
  echo "Run scripts/check-repository.sh and scripts/verify-core.sh on other hosts."
  exit 1
fi

bash scripts/check-repository.sh
bash scripts/verify-core.sh
bash scripts/smoke.sh

echo "GATE: PASS (repository · Swift build/tests · Apple PNG smoke)"
