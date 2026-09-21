#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "iOS verification requires macOS, Xcode 16 or newer, and an installed iOS simulator runtime." >&2
  exit 1
fi

artifact_root="${TRAKTION_IOS_ARTIFACTS:-$PWD/.traktion-local/ios-smoke}"
mkdir -p "$artifact_root"
artifact_root="$(cd "$artifact_root" && pwd)"
run_dir="$(mktemp -d "$artifact_root/run.XXXXXX")"
simulator_id=""
cleanup() {
  result=$?
  trap - EXIT
  # Keep visible evidence even when a UI assertion stops the script before its
  # normal export. Preserve the original failure status if diagnostics fail.
  for configuration in debug release; do
    result_bundle="$run_dir/TRAKTION.xcresult"
    [[ "$configuration" == release ]] && result_bundle="$run_dir/TRAKTION-Release.xcresult"
    attachment_dir="$run_dir/attachments/$configuration"
    if [[ -d "$result_bundle" && ! -d "$attachment_dir" ]]; then
      mkdir -p "$run_dir/attachments" || { echo "Could not create attachment directory" >&2; continue; }
      xcrun xcresulttool export attachments --path "$result_bundle" \
        --output-path "$attachment_dir" || echo "Could not export $configuration attachments" >&2
    fi
  done
  if [[ -n "$simulator_id" ]]; then
    xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
    xcrun simctl delete "$simulator_id" || echo "Could not delete dedicated simulator $simulator_id" >&2
  fi
  echo "iOS verification diagnostics: $run_dir"
  exit "$result"
}
trap cleanup EXIT

xcodebuild -version | tee "$run_dir/xcode-version.txt"
plutil -lint App/TRAKTION.xcodeproj/project.pbxproj
xcodebuild -list -json -project App/TRAKTION.xcodeproj > "$run_dir/project.json"
xcrun simctl list devices available --json > "$run_dir/available-devices.json"

# Reuse only a compatible device TYPE/runtime pair, never someone's simulator.
# Prefer the newest installed iOS runtime and a smaller iPhone within it.
read -r runtime_id device_type < <(python3 - "$run_dir/available-devices.json" <<'PY'
import json
import re
import sys

with open(sys.argv[1]) as source:
    devices = json.load(source)["devices"]
candidates = []
for runtime, entries in devices.items():
    match = re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
    if not match:
        continue
    version = tuple(int(part or 0) for part in match.groups())
    if version[0] < 17:
        continue
    for device in entries:
        device_type = device.get("deviceTypeIdentifier", "")
        if device.get("isAvailable") and "SimDeviceType.iPhone-" in device_type:
            name = device["name"]
            size_preference = 0 if "SE" in name or "mini" in name else 2 if "Max" in name or "Plus" in name else 1
            candidates.append((tuple(-part for part in version), size_preference, name, runtime, device_type))
if not candidates:
    sys.exit("No available iPhone with an iOS 17+ runtime. Install an iOS simulator in Xcode Settings > Components.")
_, _, name, runtime, device_type = min(candidates)
print(f"Using {name}, {runtime}", file=sys.stderr)
print(runtime, device_type)
PY
)

simulator_id="$(xcrun simctl create "TRAKTION Verification $(basename "$run_dir")" "$device_type" "$runtime_id")"
printf '%s\n' "$simulator_id" > "$run_dir/simulator-id.txt"
xcrun simctl boot "$simulator_id"
xcrun simctl bootstatus "$simulator_id" -b

build_args=(
  -project App/TRAKTION.xcodeproj
  -scheme TRAKTION
  -configuration Debug
  -destination "platform=iOS Simulator,id=$simulator_id"
  -destination-timeout 60
  -derivedDataPath "$run_dir/DerivedData"
  CODE_SIGNING_ALLOWED=NO
)
xcodebuild build-for-testing "${build_args[@]}" | tee "$run_dir/build.log"

app_path="$run_dir/DerivedData/Build/Products/Debug-iphonesimulator/TRAKTION.app"
test -d "$app_path"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_path/Info.plist")"
xcrun simctl install "$simulator_id" "$app_path"

# Generate genuine PNG inputs outside the shipping app. Preserve source truth
# and manifests with diagnostics; only capture files enter its data container.
swift build --configuration release --product fixture-forge
fixture_bin="$(swift build --configuration release --show-bin-path)/fixture-forge"
fixture_root="$run_dir/fixtures"
mkdir -p "$fixture_root"
app_data="$(xcrun simctl get_app_container "$simulator_id" "$bundle_id" data)"
for scenario in baseline duplicate-capture missing-middle; do
  "$fixture_bin" generate --scenario "$scenario" \
    --width 96 --viewport 160 --captures 3 --overlap 48 --seed 51 \
    --output-dir "$fixture_root/$scenario"
  destination="$app_data/Library/Application Support/UIFixtures/$scenario"
  mkdir -p "$destination"
  cp "$fixture_root/$scenario"/capture-*.png "$destination/"
done

"$fixture_bin" generate --scenario baseline \
  --width 1170 --viewport 2532 --captures 3 --overlap 700 --seed 51 \
  --output-dir "$fixture_root/inspection-long"
mkdir -p "$app_data/Library/Application Support/UIFixtures/inspection-long"
cp "$fixture_root/inspection-long"/capture-*.png "$app_data/Library/Application Support/UIFixtures/inspection-long/"

# A deliberately corrupt synthetic document exercises the real project picker
# failure path. It is not injected through the app's fixture bootstrap.
mkdir -p "$app_data/Documents"
python3 - "$app_data/Documents/Corrupt native fixture.traktion" <<'PYFIXTURE'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b"TRAKTION" + (1).to_bytes(4, "big") + (2).to_bytes(4, "big") + b"{}")
PYFIXTURE

xcrun simctl launch --terminate-running-process "$simulator_id" "$bundle_id" | tee "$run_dir/launch.log"

xcodebuild test-without-building "${build_args[@]}" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 \
  -maximum-test-execution-time-allowance 180 \
  -skip-testing:TRAKTIONUITests/TRAKTIONLaunchTests/testLongPixelInspectionPanZoomJointSourcesAndReturn \
  -resultBundlePath "$run_dir/TRAKTION.xcresult" | tee "$run_dir/tests.log"

python3 scripts/check-ui-test-results.py \
  --source Tests/UITests/TRAKTIONLaunchTests.swift --log "$run_dir/tests.log" --phase debug

mkdir -p "$run_dir/attachments"
xcrun xcresulttool export attachments --path "$run_dir/TRAKTION.xcresult" \
  --output-path "$run_dir/attachments/debug"

# Full phone-size core work is verified with production optimization, matching
# the portable performance gate. Keep all small-input Debug UI tests above.
# This flag enables only the existing synthetic-fixture bootstrap in this test
# build; ordinary Release apps do not include it.
release_args=(
  -project App/TRAKTION.xcodeproj
  -scheme TRAKTION
  -configuration Release
  -destination "platform=iOS Simulator,id=$simulator_id"
  -destination-timeout 60
  -derivedDataPath "$run_dir/DerivedData"
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=TRAKTION_UI_TESTING
  CODE_SIGNING_ALLOWED=NO
)
xcodebuild build-for-testing "${release_args[@]}" | tee "$run_dir/release-build.log"
xcrun simctl terminate "$simulator_id" "$bundle_id" || true
xcrun simctl install "$simulator_id" "$run_dir/DerivedData/Build/Products/Release-iphonesimulator/TRAKTION.app"
xcodebuild test-without-building "${release_args[@]}" \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 \
  -maximum-test-execution-time-allowance 180 \
  -only-testing:TRAKTIONUITests/TRAKTIONLaunchTests/testLongPixelInspectionPanZoomJointSourcesAndReturn \
  -resultBundlePath "$run_dir/TRAKTION-Release.xcresult" | tee "$run_dir/release-tests.log"

# Require the intended case, not a zero-test success from a stale selector.
python3 scripts/check-ui-test-results.py \
  --source Tests/UITests/TRAKTIONLaunchTests.swift --log "$run_dir/release-tests.log" --phase release

# Export retained synthetic screenshots alongside xcresult for direct visual review.
xcrun xcresulttool export attachments --path "$run_dir/TRAKTION-Release.xcresult" \
  --output-path "$run_dir/attachments/release"

echo "IOS SIMULATOR VERIFICATION: PASS"
