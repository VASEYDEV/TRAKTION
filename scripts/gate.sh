#!/usr/bin/env bash
# Verification gate (CLAUDE.md §3) — foundation stage.
# Repo-hygiene checks plus a clean Swift build and full test run
# (see docs/decisions/0001-repo-bootstrap.md and docs/adr/ADR-011).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

required=(README.md LICENSE CHANGELOG.md SECURITY.md CODE_OF_CONDUCT.md CLAUDE.md AGENTS.md .editorconfig .gitignore)
for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "MISSING required file: $f"
    fail=1
  fi
done

# Unfilled template placeholders (bootstrap protocol) — docs/legal/, build output,
# and this script excepted
if grep -rnI --exclude-dir=.git --exclude-dir=.build --exclude-dir=.swiftpm --exclude-dir=legal --exclude=gate.sh '{{' .; then
  echo "Unfilled template placeholders found (see lines above)"
  fail=1
fi

# CLAUDE.md stays under 200 lines (§2)
lines=$(wc -l < CLAUDE.md)
if (( lines >= 200 )); then
  echo "CLAUDE.md is $lines lines (limit: under 200)"
  fail=1
fi

# No committed env files (§5); .env.example is the documented exception
if git ls-files | grep -E '(^|/)\.env(\..*)?$' | grep -v '\.env\.example$'; then
  echo "Committed env file detected (see lines above)"
  fail=1
fi

# No private-key material anywhere in the tree (§5).
# Pattern is split across quotes so this script never matches itself.
if grep -rln --exclude-dir=.git -- '-----BEGIN .*PRIVATE KEY''-----' .; then
  echo "Private key material detected (see files above)"
  fail=1
fi

if (( fail )); then
  echo "GATE: FAIL (repo hygiene)"
  exit 1
fi

# Build and test. A missing toolchain is a typed failure, not a silent skip.
if ! command -v swift >/dev/null 2>&1; then
  echo "Swift toolchain not found on PATH; the gate requires swift build + swift test (see README Quick start)"
  echo "GATE: FAIL"
  exit 1
fi

echo "GATE: swift build"
swift build

echo "GATE: swift test"
swift test

echo "GATE: PASS (hygiene · swift build · swift test)"
