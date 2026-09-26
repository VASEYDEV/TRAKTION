#!/usr/bin/env python3
"""Best-effort, bounded service logs from the dedicated synthetic-test simulator."""

import argparse
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import time


def collect(command, directory, timeout=20, byte_limit=8 * 1024 * 1024):
    directory = Path(directory)
    report = {"status": "unavailable", "timeoutSeconds": timeout, "fileByteLimit": byte_limit}

    process = None
    try:
        with (directory / "simulator-services.log").open("wb") as output, \
             (directory / "simulator-services-errors.log").open("wb") as errors:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       start_new_session=True)
            deadline = time.monotonic() + timeout
            sizes = {process.stdout: 0, process.stderr: 0}
            # The collector owns the cap. Simulator-side log writers are launched
            # through CoreSimulator and need not inherit host resource limits.
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ, output)
                selector.register(process.stderr, selectors.EVENT_READ, errors)
                while selector.get_map():
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        report["status"] = "timed-out"
                        break
                    limited = False
                    for key, _ in selector.select(remaining):
                        data = os.read(key.fileobj.fileno(), 65536)
                        if not data:
                            selector.unregister(key.fileobj)
                            continue
                        allowance = byte_limit - sizes[key.fileobj]
                        key.data.write(data[:allowance])
                        sizes[key.fileobj] += min(len(data), allowance)
                        if len(data) > allowance:
                            report["status"] = "size-limited"
                            limited = True
                            break
                    if limited:
                        break
            if report["status"] == "unavailable":
                try:
                    code = process.wait(timeout=max(0, deadline - time.monotonic()))
                    report.update(status="collected" if code == 0 else "command-failed", exitCode=code)
                except subprocess.TimeoutExpired:
                    report["status"] = "timed-out"
    except (OSError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
    finally:
        if process is not None:
            # Close both pipes and end the dedicated host command group. Closing
            # the reader also prevents remote writers from extending our files.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            process.stdout.close()
            process.stderr.close()
    try:
        (directory / "simulator-services-status.json").write_text(json.dumps(report, indent=2) + "\n")
    except OSError:
        pass
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Fa-f0-9-]{36}", args.simulator):
        parser.error("Expected the dedicated simulator UUID")
    predicate = ('process == "TRAKTION" OR process == "SpringBoard" OR '
                 'process CONTAINS[c] "document" OR process CONTAINS[c] "fileprovider" OR '
                 'subsystem CONTAINS[c] "document" OR subsystem CONTAINS[c] "fileprovider"')
    report = collect(["xcrun", "simctl", "spawn", args.simulator, "log", "show",
                      "--last", "25m", "--style", "compact", "--info", "--debug",
                      "--predicate", predicate], args.output)
    print(f"Simulator service diagnostics: {report['status']}")
    # Diagnostic collection never replaces the original build/test failure.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
