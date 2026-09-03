#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Runs on any host: PNGCodec is Apple ImageIO on Darwin and the pure-Swift
# fallback elsewhere (docs/adr/ADR-011), behind one contract.

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
diagnostics="$smoke_dir/nested/diagnostics"

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

# Typed failures must leave a deterministic machine-readable failure manifest
# (docs/tasks/0002): duplicate capture exercises the reconstruct stage, a
# corrupt input exercises the decode stage.
duplicate_manifest="$smoke_dir/duplicate.reconstruction.json"
if "$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --output "$smoke_dir/duplicate-composite.png" \
  --manifest "$duplicate_manifest" \
  --diagnostics-dir "$smoke_dir/duplicate-diagnostics" \
  "$fixture_dir/capture-001.png" \
  "$fixture_dir/capture-001.png"
then
  echo "Expected duplicate-capture reconstruction failure."
  exit 1
fi
test ! -e "$smoke_dir/duplicate-composite.png"
test ! -e "$smoke_dir/duplicate-diagnostics"
python3 - "$duplicate_manifest" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["schemaVersion"] == 3, manifest
assert manifest["status"] == "failed", manifest
assert manifest["orderPolicy"] == "supplied", manifest
assert manifest["stage"] == "reconstruct", manifest
assert manifest["failureCode"] == "duplicateCapture", manifest
assert "duplicateCapture" in manifest["reconstructionFailure"], manifest
assert len(manifest["captures"]) == 2, manifest
PYEOF

duplicate_repeat="$smoke_dir/duplicate-repeat.reconstruction.json"
"$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --output "$smoke_dir/duplicate-repeat-composite.png" \
  --manifest "$duplicate_repeat" \
  --diagnostics-dir "$smoke_dir/duplicate-repeat-diagnostics" \
  "$fixture_dir/capture-001.png" \
  "$fixture_dir/capture-001.png" || true
cmp "$duplicate_manifest" "$duplicate_repeat"

corrupt_input="$smoke_dir/corrupt.png"
printf 'not a png' > "$corrupt_input"
decode_manifest="$smoke_dir/decode.reconstruction.json"
if "$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --output "$smoke_dir/decode-composite.png" \
  --manifest "$decode_manifest" \
  --diagnostics-dir "$smoke_dir/decode-diagnostics" \
  "$fixture_dir/capture-001.png" \
  "$corrupt_input"
then
  echo "Expected decode failure."
  exit 1
fi
python3 - "$decode_manifest" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["status"] == "failed", manifest
assert manifest["stage"] == "decode", manifest
assert manifest["failureCode"] == "unsupportedFormat", manifest
assert manifest.get("reconstructionFailure") is None, manifest
assert len(manifest["captures"]) == 1, manifest
assert manifest["inputFileNames"] == ["capture-001.png", "corrupt.png"], manifest
PYEOF

# Exact sequence ordering (docs/tasks/0007 + 0008, ADR-014): shuffled inputs
# under --order exact must produce a composite byte-identical to the
# supplied-order one, deterministically; a coverage gap must refuse with the
# typed sequenceOrderNotFound manifest and no composite.
recovered="$smoke_dir/recovered.png"
recovered_manifest="$smoke_dir/recovered.reconstruction.json"
"$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --order exact \
  --output "$recovered" \
  --manifest "$recovered_manifest" \
  --diagnostics-dir "$smoke_dir/recovered-diagnostics" \
  "$fixture_dir/capture-002.png" \
  "$fixture_dir/capture-003.png" \
  "$fixture_dir/capture-001.png"
"$bin_dir/traktion-lab" compare "$fixture_dir/source.png" "$recovered"
cmp "$composite" "$recovered"
test -s "$smoke_dir/recovered-diagnostics/joint-001.json"
test -s "$smoke_dir/recovered-diagnostics/joint-002-difference.png"
python3 - "$recovered_manifest" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["schemaVersion"] == 3, manifest
assert manifest["status"] == "reconstructed", manifest
assert manifest["orderPolicy"] == "exact", manifest
# IDs are positional (argument order); the documentary order is files 001..003.
assert manifest["recoveredOrder"] == ["capture-003", "capture-001", "capture-002"], manifest
assert [c["fileName"] for c in manifest["captures"]] == [
    "capture-001.png", "capture-002.png", "capture-003.png"
], manifest
assert [p["captureID"] for p in manifest["plan"]["placements"]] == manifest["recoveredOrder"], manifest
PYEOF

recovered_repeat="$smoke_dir/recovered-repeat.png"
"$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --order exact \
  --output "$recovered_repeat" \
  --manifest "$smoke_dir/recovered-repeat.reconstruction.json" \
  --diagnostics-dir "$smoke_dir/recovered-repeat-diagnostics" \
  "$fixture_dir/capture-002.png" \
  "$fixture_dir/capture-003.png" \
  "$fixture_dir/capture-001.png"
cmp "$recovered" "$recovered_repeat"
python3 - "$recovered_manifest" "$smoke_dir/recovered-repeat.reconstruction.json" <<'PYEOF'
import json, sys
first, second = (json.load(open(path)) for path in sys.argv[1:3])
# Only the output file name may differ between the two recovered runs.
assert first["outputFileName"] == "recovered.png", first["outputFileName"]
assert second["outputFileName"] == "recovered-repeat.png", second["outputFileName"]
del first["outputFileName"], second["outputFileName"]
assert first == second, "recovered manifests differ beyond outputFileName"
PYEOF

gap_manifest="$smoke_dir/gap.reconstruction.json"
if "$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --order exact \
  --output "$smoke_dir/gap-composite.png" \
  --manifest "$gap_manifest" \
  --diagnostics-dir "$smoke_dir/gap-diagnostics" \
  "$fixture_dir/capture-003.png" \
  "$fixture_dir/capture-001.png"
then
  echo "Expected sequence-order-not-found failure."
  exit 1
fi
test ! -e "$smoke_dir/gap-composite.png"
test ! -e "$smoke_dir/gap-diagnostics"
python3 - "$gap_manifest" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["schemaVersion"] == 3, manifest
assert manifest["status"] == "failed", manifest
assert manifest["orderPolicy"] == "exact", manifest
assert manifest["stage"] == "reconstruct", manifest
assert manifest["failureCode"] == "sequenceOrderNotFound", manifest
assert "sequenceOrderNotFound" in manifest["reconstructionFailure"], manifest
assert [c["fileName"] for c in manifest["captures"]] == [
    "capture-003.png", "capture-001.png"
], manifest
PYEOF

# The plain run's manifest gains nothing but the version bump and the policy.
python3 - "$manifest" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["schemaVersion"] == 3, manifest
assert manifest["orderPolicy"] == "supplied", manifest
assert "recoveredOrder" not in manifest, manifest
PYEOF

# An unknown order policy is a usage error that writes nothing.
if "$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --order guess \
  --output "$smoke_dir/bad-order-composite.png" \
  "$fixture_dir/capture-001.png" \
  "$fixture_dir/capture-002.png"
then
  echo "Expected usage failure for an unknown order policy."
  exit 1
fi
test ! -e "$smoke_dir/bad-order-composite.png"
test ! -e "$smoke_dir/bad-order-composite.reconstruction.json"

# Near-exact ordering (docs/tasks/0009, ADR-015): the degraded control set
# carries no byte-exact edge, so --order exact refuses it with a typed
# manifest while --order near-exact recovers the order and reproduces the
# supplied-order composite byte for byte.
degraded_dir="$smoke_dir/degraded"
"$bin_dir/fixture-forge" generate --scenario degraded --output-dir "$degraded_dir"
"$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --output "$smoke_dir/degraded-supplied.png" \
  --manifest "$smoke_dir/degraded-supplied.reconstruction.json" \
  --diagnostics-dir "$smoke_dir/degraded-supplied-diagnostics" \
  "$degraded_dir/capture-001.png" \
  "$degraded_dir/capture-002.png" \
  "$degraded_dir/capture-003.png"

degraded_exact_manifest="$smoke_dir/degraded-exact.reconstruction.json"
if "$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --order exact \
  --output "$smoke_dir/degraded-exact.png" \
  --manifest "$degraded_exact_manifest" \
  --diagnostics-dir "$smoke_dir/degraded-exact-diagnostics" \
  "$degraded_dir/capture-003.png" \
  "$degraded_dir/capture-001.png" \
  "$degraded_dir/capture-002.png"
then
  echo "Expected exact ordering to refuse near-exact captures."
  exit 1
fi
test ! -e "$smoke_dir/degraded-exact.png"
python3 - "$degraded_exact_manifest" <<'PYEOF'
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["status"] == "failed", manifest
assert manifest["orderPolicy"] == "exact", manifest
assert manifest["failureCode"] == "sequenceOrderNotFound", manifest
PYEOF

degraded_near_exact_manifest="$smoke_dir/degraded-near-exact.reconstruction.json"
"$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --order near-exact \
  --output "$smoke_dir/degraded-near-exact.png" \
  --manifest "$degraded_near_exact_manifest" \
  --diagnostics-dir "$smoke_dir/degraded-near-exact-diagnostics" \
  "$degraded_dir/capture-003.png" \
  "$degraded_dir/capture-001.png" \
  "$degraded_dir/capture-002.png"
cmp "$smoke_dir/degraded-supplied.png" "$smoke_dir/degraded-near-exact.png"
python3 - "$degraded_near_exact_manifest" "$smoke_dir/degraded-supplied.reconstruction.json" <<'PYEOF'
import json, sys
near_exact, supplied = (json.load(open(path)) for path in sys.argv[1:3])
assert near_exact["status"] == "reconstructed", near_exact
assert near_exact["orderPolicy"] == "near-exact", near_exact
# IDs are positional (argument order 003, 001, 002); documentary order is files 001..003.
assert near_exact["recoveredOrder"] == ["capture-002", "capture-003", "capture-001"], near_exact
assert [c["fileName"] for c in near_exact["captures"]] == [
    "capture-001.png", "capture-002.png", "capture-003.png"
], near_exact
assert [j["confidence"] for j in near_exact["plan"]["joints"]] == ["strong", "strong"], near_exact
assert [j["overlapRows"] for j in near_exact["plan"]["joints"]] == [
    j["overlapRows"] for j in supplied["plan"]["joints"]
], (near_exact, supplied)
PYEOF

failure_output="$smoke_dir/failure-composite.png"
failure_parent_blocker="$smoke_dir/manifest-parent-blocker"
failure_manifest="$failure_parent_blocker/manifest.json"
failure_diagnostics="$smoke_dir/failure-diagnostics"
touch "$failure_parent_blocker"
if "$bin_dir/traktion-lab" reconstruct \
  --axis vertical \
  --output "$failure_output" \
  --manifest "$failure_manifest" \
  --diagnostics-dir "$failure_diagnostics" \
  "$fixture_dir/capture-001.png" \
  "$fixture_dir/capture-002.png" \
  "$fixture_dir/capture-003.png"
then
  echo "Expected artifact publication failure."
  exit 1
fi
test ! -e "$failure_output"
test ! -e "$failure_manifest"
test ! -e "$failure_diagnostics"

echo "PNG SMOKE: PASS ($(uname -s) codec path)"
echo "Artifacts: $smoke_dir"
