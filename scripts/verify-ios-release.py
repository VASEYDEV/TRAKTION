#!/usr/bin/env python3
"""Build and validate ordinary iOS Release; signing is an explicit local mode."""

import argparse
import json
from pathlib import Path
import platform
import plistlib
import re
import shlex
import subprocess
import sys
import tempfile


FORBIDDEN_FLAGS = {"DEBUG", "TRAKTION_UI_TESTING"}
FIXTURE_MARKERS = (b"TRAKTION_UI_FIXTURE", b"importUITestFixtureIfRequested", b"UIFixtures")
REPORT_SETTINGS = ("CONFIGURATION", "PLATFORM_NAME", "SWIFT_OPTIMIZATION_LEVEL",
                   "SWIFT_ACTIVE_COMPILATION_CONDITIONS", "OTHER_SWIFT_FLAGS",
                   "CODE_SIGNING_ALLOWED", "CODE_SIGN_STYLE", "PRODUCT_BUNDLE_IDENTIFIER",
                   "MARKETING_VERSION", "CURRENT_PROJECT_VERSION", "IPHONEOS_DEPLOYMENT_TARGET")


def check_settings(records, signed=False):
    apps = [r["buildSettings"] for r in records if r.get("target") == "TRAKTIONiOS"]
    if len(apps) != 1:
        raise ValueError("Expected exactly one TRAKTIONiOS build-settings record")
    settings = apps[0]
    for key, expected in [("CONFIGURATION", "Release"), ("PLATFORM_NAME", "iphoneos")]:
        if settings.get(key) != expected:
            raise ValueError(f"{key} must be {expected}")
    if settings.get("SWIFT_OPTIMIZATION_LEVEL") not in {"-O", "-Osize"}:
        raise ValueError("Ordinary Release must use production optimization")
    flags = shlex.split(settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", ""))
    other = shlex.split(settings.get("OTHER_SWIFT_FLAGS", ""))
    # Both -D FLAG and -DFLAG are accepted by swiftc.
    defines = {v[2:] for v in other if v.startswith("-D")}
    defines.update(other[i + 1] for i, v in enumerate(other[:-1]) if v == "-D")
    if FORBIDDEN_FLAGS.intersection(set(flags) | defines):
        raise ValueError("Ordinary Release must exclude DEBUG and TRAKTION_UI_TESTING")
    identifier = settings.get("PRODUCT_BUNDLE_IDENTIFIER", "")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", identifier):
        raise ValueError("A concrete bundle identifier is required")
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION"):
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", settings.get(key, "")):
            raise ValueError(f"A numeric {key} is required")
    minimum = settings.get("IPHONEOS_DEPLOYMENT_TARGET", "")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", minimum) or int(minimum.split(".")[0]) < 17:
        raise ValueError("The device deployment target must be iOS 17 or later")
    if settings.get("CODE_SIGNING_ALLOWED") != ("YES" if signed else "NO"):
        raise ValueError("Effective signing settings do not match the requested mode")
    if signed:
        if not re.fullmatch(r"[A-Z0-9]{10}", settings.get("DEVELOPMENT_TEAM", "")):
            raise ValueError("Configure the actual DEVELOPMENT_TEAM in Signing.local.xcconfig first")
        if settings.get("CODE_SIGN_STYLE") != "Automatic":
            raise ValueError("This helper requires the project's automatic signing configuration")
    return settings


def check_product(app, settings, architectures):
    app = Path(app)
    with (app / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    for key, setting in [("CFBundleIdentifier", "PRODUCT_BUNDLE_IDENTIFIER"),
                         ("CFBundleShortVersionString", "MARKETING_VERSION"),
                         ("CFBundleVersion", "CURRENT_PROJECT_VERSION"),
                         ("MinimumOSVersion", "IPHONEOS_DEPLOYMENT_TARGET")]:
        if info.get(key) != settings[setting]:
            raise ValueError(f"Built {key} does not match effective settings")
    if info.get("CFBundlePackageType") != "APPL" or info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
        raise ValueError("Built product must be an iPhoneOS application")
    if set(info.get("UIDeviceFamily", [])) != {1, 2}:
        raise ValueError("Built product must retain iPhone and iPad support")
    executable = info.get("CFBundleExecutable")
    if executable != "TRAKTION" or not (app / executable).is_file():
        raise ValueError("Expected TRAKTION application executable")
    if set(architectures.split()) != {"arm64"}:
        raise ValueError("Expected an arm64 device binary")
    for path in app.rglob("*"):
        if path.suffix in {".xctest", ".xctestrun"} or path.name == "UIFixtures":
            raise ValueError("Test bundles or fixture resources are present in the app")
    data = (app / executable).read_bytes()
    if any(marker in data for marker in FIXTURE_MARKERS):
        raise ValueError("Synthetic fixture bootstrap is present in the Release executable")
    return {"bundleIdentifier": info["CFBundleIdentifier"],
            "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"],
            "minimumOS": info["MinimumOSVersion"], "architectures": architectures.split(),
            "fixtureBootstrapAbsent": True}


def build_arguments(run_dir, device=None):
    if device is not None and not re.fullmatch(r"[A-Za-z0-9-]{8,64}", device):
        raise ValueError("Use the actual connected device identifier from Xcode")
    args = ["-project", "App/TRAKTION.xcodeproj", "-scheme", "TRAKTION",
            "-configuration", "Release", "-destination",
            f"platform=iOS,id={device}" if device else "generic/platform=iOS",
            "-destination-timeout", "60", "-derivedDataPath", str(run_dir / "DerivedData")]
    if device is None:
        args.append("CODE_SIGNING_ALLOWED=NO")
    return args


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--signed-device", metavar="DEVICE_ID",
                        help="Explicit local signed build for a connected device; no install/provisioning updates")
    parser.add_argument("--artifacts", type=Path, default=Path(".traktion-local/ios-release"))
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("Requires macOS and Xcode; Linux checks do not establish a device build")
    root = Path(__file__).resolve().parents[1]
    artifact_root = args.artifacts.resolve()
    artifact_root.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="run.", dir=artifact_root))
    print(f"Device Release diagnostics: {run}", flush=True)
    try:
        build_args = build_arguments(run, args.signed_device)
        with (run / "xcode-version.txt").open("w") as version:
            subprocess.run(["xcodebuild", "-version"], stdout=version, stderr=subprocess.STDOUT,
                           check=True, timeout=30)
        with (run / "settings-errors.log").open("w") as errors:
            result = subprocess.run(["xcodebuild", "-showBuildSettings", "-json", *build_args],
                                    cwd=root, stdout=subprocess.PIPE, stderr=errors, check=True, timeout=120)
        records = json.loads(result.stdout)
        # Preserve only build-contract fields, never the full settings/environment
        # response or local provisioning/account values.
        safe_settings = [{"target": r.get("target"), "buildSettings": {
            key: r.get("buildSettings", {}).get(key) for key in REPORT_SETTINGS}}
            for r in records if r.get("target") == "TRAKTIONiOS"]
        (run / "effective-settings.json").write_text(json.dumps(safe_settings, indent=2) + "\n")
        settings = check_settings(records, signed=bool(args.signed_device))
        with (run / "build.log").open("w") as log:
            subprocess.run(["xcodebuild", "build", *build_args], cwd=root,
                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=900)
        app = run / "DerivedData/Build/Products/Release-iphoneos/TRAKTION.app"
        architectures = subprocess.check_output(["xcrun", "lipo", "-archs", str(app / "TRAKTION")],
                                                 text=True, timeout=30).strip()
        report = check_product(app, settings, architectures)
        report.update(configuration=settings["CONFIGURATION"], platform=settings["PLATFORM_NAME"],
                      optimization=settings["SWIFT_OPTIMIZATION_LEVEL"], forbiddenTestFlagsAbsent=True)
        report["mode"] = "signed-device-build" if args.signed_device else "unsigned-device-build"
        report["installedOrLaunched"] = False
        if args.signed_device:
            subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True, timeout=30)
            signature = subprocess.run(["codesign", "-dv", "--verbose=4", str(app)],
                                       capture_output=True, text=True, check=True, timeout=30)
            if f"TeamIdentifier={settings['DEVELOPMENT_TEAM']}" not in signature.stderr.splitlines():
                raise ValueError("Built signature does not match the configured team")
            if not (app / "embedded.mobileprovision").is_file():
                raise ValueError("Signed device app has no embedded provisioning profile")
        (run / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"IOS DEVICE RELEASE VERIFICATION: PASS ({report['mode']}; installation not verified)")
        print(f"Built app: {app}")
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        (run / "failure.txt").write_text(str(error) + "\n")
        print(f"IOS DEVICE RELEASE VERIFICATION: FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
