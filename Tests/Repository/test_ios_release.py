"""Reject falsely qualified device Release products and unsafe build modes."""

import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/verify-ios-release.py"
spec = importlib.util.spec_from_file_location("ios_release", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def settings():
    return {"CONFIGURATION": "Release", "PLATFORM_NAME": "iphoneos",
            "SWIFT_OPTIMIZATION_LEVEL": "-O", "CODE_SIGNING_ALLOWED": "NO",
            "PRODUCT_BUNDLE_IDENTIFIER": "dev.vasey.traktion", "MARKETING_VERSION": "0.1.0",
            "CURRENT_PROJECT_VERSION": "1", "IPHONEOS_DEPLOYMENT_TARGET": "17.0"}


def record(values):
    return [{"target": "TRAKTIONiOS", "buildSettings": values}]


class DeviceReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = Path(self.directory.name) / "TRAKTION.app"
        self.app.mkdir()
        self.info = {"CFBundleIdentifier": "dev.vasey.traktion", "CFBundleVersion": "1",
                     "CFBundleShortVersionString": "0.1.0", "MinimumOSVersion": "17.0",
                     "CFBundlePackageType": "APPL", "CFBundleSupportedPlatforms": ["iPhoneOS"],
                     "UIDeviceFamily": [1, 2], "CFBundleExecutable": "TRAKTION"}
        self.write_info()
        (self.app / "TRAKTION").write_bytes(b"ordinary production binary")

    def write_info(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def test_ordinary_release_metadata_and_fixture_exclusion(self):
        value = module.check_settings(record(settings()))
        result = module.check_product(self.app, value, "arm64")
        self.assertEqual(result["bundleIdentifier"], "dev.vasey.traktion")
        self.assertTrue(result["fixtureBootstrapAbsent"])

    def test_wrong_platform_configuration_flags_and_missing_target_fail(self):
        for key, bad in [("CONFIGURATION", "Debug"), ("PLATFORM_NAME", "iphonesimulator"),
                         ("SWIFT_OPTIMIZATION_LEVEL", "-Onone"), ("CODE_SIGNING_ALLOWED", "YES"),
                         ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "RELEASE DEBUG"),
                         ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "TRAKTION_UI_TESTING"),
                         ("OTHER_SWIFT_FLAGS", "-DTRAKTION_UI_TESTING"),
                         ("OTHER_SWIFT_FLAGS", "-D DEBUG"), ("MARKETING_VERSION", ""),
                         ("PRODUCT_BUNDLE_IDENTIFIER", "$(MISSING)"),
                         ("IPHONEOS_DEPLOYMENT_TARGET", "16.0")]:
            with self.subTest(key=key, bad=bad), self.assertRaises(ValueError):
                module.check_settings(record(settings() | {key: bad}))
        for entries in [[], record(settings()) * 2,
                        [{"target": "TRAKTIONUITests", "buildSettings": settings()}]]:
            with self.assertRaises(ValueError):
                module.check_settings(entries)

    def test_product_mismatch_and_simulator_binary_fail(self):
        for key, bad in [("CFBundleIdentifier", "other.app"), ("CFBundleVersion", "2"),
                         ("CFBundleShortVersionString", "0.2.0"), ("MinimumOSVersion", "16.0"),
                         ("CFBundleSupportedPlatforms", ["iPhoneSimulator"]),
                         ("CFBundleExecutable", "../TRAKTION"), ("UIDeviceFamily", [1])]:
            original = self.info[key]
            self.info[key] = bad
            self.write_info()
            with self.subTest(key=key), self.assertRaises(ValueError):
                module.check_product(self.app, settings(), "arm64")
            self.info[key] = original
        self.write_info()
        for arch in ["x86_64", "", "arm64 x86_64"]:
            with self.assertRaises(ValueError):
                module.check_product(self.app, settings(), arch)

    def test_compiled_bootstrap_or_bundled_test_data_fail(self):
        for marker in module.FIXTURE_MARKERS:
            (self.app / "TRAKTION").write_bytes(b"prefix\0" + marker + b"\0suffix")
            with self.assertRaisesRegex(ValueError, "bootstrap"):
                module.check_product(self.app, settings(), "arm64")
        (self.app / "TRAKTION").write_bytes(b"production")
        for name in ["UITests.xctest", "UIFixtures"]:
            path = self.app / name
            path.mkdir()
            with self.assertRaisesRegex(ValueError, "Test bundles"):
                module.check_product(self.app, settings(), "arm64")
            path.rmdir()

    def test_signed_mode_requires_real_settings_and_preserves_signing(self):
        with self.assertRaises(ValueError):
            module.check_settings(record(settings()), signed=True)
        signed = settings() | {"CODE_SIGNING_ALLOWED": "YES", "CODE_SIGN_STYLE": "Automatic",
                               "DEVELOPMENT_TEAM": "A123456789"}
        module.check_settings(record(signed), signed=True)
        for team in ["", "YOUR_TEAM", "bad team"]:
            with self.assertRaises(ValueError):
                module.check_settings(record(signed | {"DEVELOPMENT_TEAM": team}), signed=True)
        run = Path(self.directory.name)
        unsigned = module.build_arguments(run)
        self.assertIn("CODE_SIGNING_ALLOWED=NO", unsigned)
        signed_args = module.build_arguments(run, "00008110-000000000000001E")
        self.assertIn("platform=iOS,id=00008110-000000000000001E", signed_args)
        for args in [unsigned, signed_args]:
            self.assertNotIn("-allowProvisioningUpdates", args)
            self.assertNotIn("-allowProvisioningDeviceRegistration", args)
            self.assertFalse(any("TRAKTION_UI_TESTING" in v for v in args))
        self.assertFalse(any(v.startswith("CODE_SIGN") for v in signed_args))
        with self.assertRaises(ValueError):
            module.build_arguments(run, "id,platform=iOS Simulator")


if __name__ == "__main__":
    unittest.main()
