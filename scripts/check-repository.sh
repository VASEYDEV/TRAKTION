#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
required=(
  README.md
  LICENSE
  CHANGELOG.md
  SECURITY.md
  CODE_OF_CONDUCT.md
  CLAUDE.md
  AGENTS.md
  Package.swift
  .editorconfig
  .gitignore
)

for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "MISSING required file: $file"
    fail=1
  fi
done

if git grep -n -F '{{' -- . \
  ':(exclude).github/workflows/**' \
  ':(exclude)docs/legal/**' \
  ':(exclude)scripts/check-repository.sh'; then
  echo "Unfilled template placeholders found (see lines above)"
  fail=1
fi

claude_lines=$(wc -l < CLAUDE.md)
if (( claude_lines >= 200 )); then
  echo "CLAUDE.md is $claude_lines lines (limit: under 200)"
  fail=1
fi

if git ls-files | grep -E '(^|/)\.env(\..*)?$' | grep -v '\.env\.example$'; then
  echo "Committed env file detected (see lines above)"
  fail=1
fi

private_key_pattern='-----BEGIN .*PRIVATE KEY''-----'
if git grep -n -E -e "$private_key_pattern" -- .; then
  echo "Private key material detected (see lines above)"
  fail=1
fi

while IFS= read -r json_file; do
  if ! python3 -m json.tool "$json_file" >/dev/null; then
    echo "Invalid JSON: $json_file"
    fail=1
  fi
done < <(git ls-files '*.json')

if (( fail )); then
  echo "REPOSITORY CHECK: FAIL"
  exit 1
fi
echo "REPOSITORY CHECK: PASS"
