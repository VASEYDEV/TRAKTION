#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Apple ImageIO smoke verification requires macOS."
  exit 1
fi

if [[ -n "${TRAKTION_SMOKE_DIR:-}" ]]; then
  smoke_dir="$TRAKTION_SMOKE_DIR"
  if [[ -e "$smoke_dir" ]]; then
    echo "Smoke output already exists: $smoke_dir"
    exit 1
  fi
  mkdir -p "$smoke_dir"
  keep_smoke_dir=1
else
  smoke_dir=$(mktemp -d "${TMPDIR:-/tmp}/traktion-smoke.XXXXXX")
  keep_smoke_dir=0
fi

cleanup() {
  if (( keep_smoke_dir == 0 )) && [[ -d "$smoke_dir" ]]; then
    rm -rf -- "$smoke_dir"
  fi
}
trap cleanup EXIT

swift build --configuration release --product fixture-forge
swift build --configuration release --product traktion-lab
bin_dir=$(swift build --configuration release --show-bin-path)

fixture_dir="$smoke_dir/fixture"
composite="$smoke_dir/composite.png"
manifest="$smoke_dir/composite.reconstruction.json"
diagnostics="$smoke_dir/diagnostics"

"$bin_dir/fixture-forge" baseline --output-dir "$fixture_dir"
"$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --output "$composite" \
  --manifest "$manifest" \
  --diagnostics-dir "$diagnostics" \
  "$fixture_dir/capture-001.png" \
  "$fixture_dir/capture-002.png" \
  "$fixture_dir/capture-003.png"
"$bin_dir/traktion-lab" compare "$fixture_dir/source.png" "$composite"

test -s "$manifest"
test -s "$diagnostics/joint-001.json"
test -s "$diagnostics/joint-001-difference.png"
test -s "$diagnostics/joint-002.json"
test -s "$diagnostics/joint-002-difference.png"
python3 -m json.tool "$manifest" >/dev/null

echo "APPLE PNG SMOKE: PASS"
echo "Artifacts: $smoke_dir"
