"""Regression checks for false-green native test discovery."""

import importlib.util
from pathlib import Path
import unittest

script = Path(__file__).resolve().parents[2] / "scripts/check-ui-test-results.py"
spec = importlib.util.spec_from_file_location("ui_results", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

SOURCE = "\n".join("  func " + name + "() {}" for name in [
    "testImport", "testEditing", module.PHONE_TEST,
])


def record(name, outcome="passed"):
    return f"Test Case '-[TRAKTIONUITests.TRAKTIONLaunchTests {name}]' {outcome} (1.000 seconds).\n"


class NativeTestInventoryTests(unittest.TestCase):
    def test_both_phases_require_their_complete_inventory(self):
        self.assertEqual(module.verify(SOURCE, record("testImport") + record("testEditing"), "debug"), 2)
        self.assertEqual(module.verify(SOURCE, record(module.PHONE_TEST), "release"), 1)

    def test_empty_and_partial_logs_fail(self):
        for log in ["** TEST EXECUTE SUCCEEDED **", record("testImport")]:
            with self.subTest(log=log), self.assertRaises(ValueError):
                module.verify(SOURCE, log, "debug")

    def test_new_source_test_cannot_be_silently_omitted(self):
        with self.assertRaises(ValueError):
            module.verify(SOURCE + "\nfunc testNewFeature() {}", record("testImport") + record("testEditing"), "debug")

    def test_failure_retry_and_wrong_phase_fail(self):
        good = record("testImport") + record("testEditing")
        for extra in [record("testImport", "failed"), record("testEditing"), record(module.PHONE_TEST)]:
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                module.verify(SOURCE, good + extra, "debug")

    def test_timeout_cannot_be_hidden_by_complete_passing_inventory(self):
        for phase, names in [("debug", ["testImport", "testEditing"]), ("release", [module.PHONE_TEST])]:
            timeout = (
                f"Test Case '-[TRAKTIONUITests.TRAKTIONLaunchTests {names[0]}]' "
                "exceeded execution time allowance of 2 minutes. The test may have hung; "
                "check Xcode's test report for additional diagnostics.\n"
            )
            good = "".join(record(name) for name in names)
            for log in [timeout + good, good + timeout]:
                with self.subTest(phase=phase, log=log), self.assertRaisesRegex(
                    ValueError, "exceeded execution time allowance"
                ):
                    module.verify(SOURCE, log, phase)

    def test_runner_restart_cannot_be_hidden_by_complete_passing_inventory(self):
        restart = (
            "Restarting after unexpected exit, crash, or test timeout; "
            "summary will include totals from previous launches.\n"
        )
        for phase, names in [("debug", ["testImport", "testEditing"]), ("release", [module.PHONE_TEST])]:
            good = "".join(record(name) for name in names)
            for log in [restart + good, good + restart]:
                with self.subTest(phase=phase, log=log), self.assertRaisesRegex(
                    ValueError, "Restarting after unexpected exit"
                ):
                    module.verify(SOURCE, log, phase)

    def test_invalid_source_inventory_and_stale_phone_selector_fail(self):
        for source in ["", SOURCE + "\nfunc testImport() {}", SOURCE.replace(module.PHONE_TEST, "testRenamedPhone")]:
            with self.subTest(source=source), self.assertRaises(ValueError):
                module.verify(source, record(module.PHONE_TEST), "release")

    def test_unrelated_output_cannot_satisfy_native_gate(self):
        with self.assertRaises(ValueError):
            module.verify(SOURCE, record(module.PHONE_TEST).replace("TRAKTIONLaunchTests", "OtherTests"), "release")


if __name__ == "__main__":
    unittest.main()
