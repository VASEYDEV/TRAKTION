#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

required=(AGENTS.md Package.swift README.md LICENSE docs/PRODUCT.md docs/ARCHITECTURE.md docs/RECONSTRUCTION_SPEC.md)
for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "MISSING required file: $file"; exit 1; }
done

if rg -n --glob '!.git/**' --glob '!scripts/gate.sh' --glob '!TRAKTION_Foundation_Kit_v1.zip' '\{\{' .; then
  echo "Unfilled template placeholders found"
  exit 1
fi
if git ls-files | rg '(^|/)\.env(\..*)?$' | rg -v '\.env\.example$'; then
  echo "Committed environment file detected"
  exit 1
fi
if rg -l --glob '!.git/**' --glob '!scripts/gate.sh' -- '-----BEGIN .*PRIVATE KEY''-----' .; then
  echo "Private key material detected"
  exit 1
fi

echo "GATE: PASS (foundation files, placeholders, environment files, secrets)"
