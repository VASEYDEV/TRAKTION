"""Exercise bounded native diagnostics and the actual EXIT cleanup contract."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ios_diagnostics", ROOT / "scripts/collect-ios-diagnostics.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SimulatorDiagnosticTests(unittest.TestCase):
    def test_success_failure_timeout_and_size_are_recorded(self):
        scenarios = [("print('service evidence')", "collected"),
                     ("raise SystemExit(7)", "command-failed"),
                     ("import time; time.sleep(20)", "timed-out"),
                     ("import os; os.write(1, b'x' * 65536)", "size-limited"),
                     ("import os; os.write(2, b'x' * 65536)", "size-limited"),
                     ("import os,time; os.close(1); os.close(2); time.sleep(20)", "timed-out")]
        for code, expected in scenarios:
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory:
                started = time.monotonic()
                report = module.collect([sys.executable, "-c", code], directory,
                                        timeout=0.3, byte_limit=4096)
                self.assertEqual(report["status"], expected)
                self.assertLess(time.monotonic() - started, 3)
                self.assertLessEqual((Path(directory) / "simulator-services.log").stat().st_size, 4096)
                self.assertLessEqual((Path(directory) / "simulator-services-errors.log").stat().st_size, 4096)
                self.assertEqual(json.loads((Path(directory) / "simulator-services-status.json").read_text()), report)

    def test_missing_command_does_not_hide_original_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            report = module.collect(["/nonexistent/traktion-diagnostics"], directory)
            self.assertEqual(report["status"], "unavailable")
            self.assertIn("error", report)

    def test_real_cleanup_keeps_original_status_and_deletes_after_diagnostics(self):
        # Execute the shipped cleanup body, with fake xcrun/collector commands;
        # no Xcode, simulator or test result is claimed by this orchestration test.
        source = (ROOT / "scripts/verify-ios.sh").read_text()
        cleanup = source[source.index("cleanup() {"):source.index("trap cleanup EXIT")]
        for initial, diagnostic in [(0, 0), (37, 0), (37, 9), (37, 124)]:
            with self.subTest(initial=initial, diagnostic=diagnostic), tempfile.TemporaryDirectory() as directory:
                directory = Path(directory)
                trace = directory / "trace"
                for tool, contents in {
                    "python3": f'#!/bin/bash\nprintf "diagnostics\\n" >> "$TRACE"\nexit {diagnostic}\n',
                    "xcrun": '#!/bin/bash\nprintf "%s\\n" "$*" >> "$TRACE"\n',
                }.items():
                    path = directory / tool
                    path.write_text(contents)
                    path.chmod(0o755)
                script = ('set -euo pipefail\nrun_dir="$RUN_DIR"\nsimulator_id=dedicated\n' + cleanup +
                          f'trap cleanup EXIT\nexit {initial}\n')
                result = subprocess.run(["bash", "-c", script], cwd=ROOT, capture_output=True,
                                        env=os.environ | {"PATH": f"{directory}:{os.environ['PATH']}",
                                                          "TRACE": str(trace), "RUN_DIR": str(directory)}, timeout=5)
                self.assertEqual(result.returncode, initial, result.stderr.decode())
                lines = trace.read_text().splitlines()
                expected = (["diagnostics"] if initial else []) + ["simctl shutdown dedicated", "simctl delete dedicated"]
                self.assertEqual(lines, expected)


if __name__ == "__main__":
    unittest.main()
