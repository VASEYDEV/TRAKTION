#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
probe_dir="$(mktemp -d /tmp/traktion-inspection-probe.XXXXXX)"
build_dir="$PWD/.build/x86_64-unknown-linux-gnu/release"
swiftc -parse-as-library -O -I "$build_dir/Modules" \
  docs/notes/native-png-probe/GenerateNativeImportFixtures.swift \
  "$build_dir"/TraktionDomain.build/*.swift.o \
  "$build_dir"/TraktionVision.build/*.swift.o \
  "$build_dir"/FixtureForgeKit.build/*.swift.o -o "$probe_dir/generate"
swiftc -parse-as-library -O -I "$build_dir/Modules" \
  docs/notes/inspection-probe/ProbeInspection.swift \
  "$build_dir"/TraktionDomain.build/*.swift.o \
  "$build_dir"/TraktionVision.build/*.swift.o \
  "$build_dir"/TraktionCore.build/*.swift.o \
  "$build_dir"/TraktionUI.build/*.swift.o \
  "$build_dir"/FixtureForgeKit.build/*.swift.o \
  "$build_dir/TraktionLabEvaluation.build/PeakMemorySampler.swift.o" -o "$probe_dir/probe"
"$probe_dir/generate" 10 "$probe_dir/long"
sha256sum "$probe_dir"/long/*.png > "$probe_dir/originals.sha256"
"$probe_dir/probe" "$probe_dir/long" "$probe_dir/report.json"
sha256sum --check "$probe_dir/originals.sha256"
printf 'Inspection probe evidence: %s\n' "$probe_dir"
