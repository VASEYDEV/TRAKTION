#!/usr/bin/env bash
# Verification gate (CLAUDE.md §3) — docs-only stage.
# Replace with real lint / typecheck / test / build when application code lands
# (see docs/decisions/0001-repo-bootstrap.md).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

required=(README.md LICENSE CHANGELOG.md SECURITY.md CODE_OF_CONDUCT.md CLAUDE.md .editorconfig .gitignore)
for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "MISSING required file: $f"
    fail=1
  fi
done

# Unfilled template placeholders (bootstrap protocol) — docs/legal/ and this script excepted
if grep -rn --exclude-dir=.git --exclude-dir=legal --exclude=gate.sh '{{' .; then
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
  echo "GATE: FAIL"
  exit 1
fi
echo "GATE: PASS (docs-only stage: required files · placeholders · CLAUDE.md size · secrets)"
