#!/usr/bin/env python3
"""Require every selected native XCTest to have exactly one passing record."""

import argparse
from collections import Counter
from pathlib import Path
import re
import sys

PHONE_TEST = "testLongPixelInspectionPanZoomJointSourcesAndReturn"


def verify(source: str, log: str, phase: str) -> int:
    names = re.findall(r"^\s*func\s+(test\w+)\s*\(", source, re.MULTILINE)
    if not names or len(names) != len(set(names)) or PHONE_TEST not in names:
        raise ValueError("Native source inventory is empty, duplicated, or missing the phone test.")
    expected = {PHONE_TEST} if phase == "release" else set(names) - {PHONE_TEST}
    if not expected:
        raise ValueError("The selected native phase must contain tests.")
    records = re.findall(
        r"Test Case '-\[TRAKTIONUITests\.TRAKTIONLaunchTests (test\w+)\]' (passed|failed)\b", log
    )
    counts = Counter(name for name, result in records if result == "passed")
    failures = {name for name, result in records if result == "failed"}
    missing = expected - counts.keys()
    unexpected = counts.keys() - expected
    repeated = {name for name, count in counts.items() if count != 1}
    if missing or unexpected or repeated or failures:
        raise ValueError(
            f"Native {phase} inventory mismatch: missing={sorted(missing)}, "
            f"unexpected={sorted(unexpected)}, repeated={sorted(repeated)}, failed={sorted(failures)}"
        )
    return len(expected)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--phase", choices=("debug", "release"), required=True)
    args = parser.parse_args()
    try:
        count = verify(args.source.read_text(), args.log.read_text(), args.phase)
    except (OSError, ValueError) as error:
        sys.exit(str(error))
    print(f"NATIVE TEST INVENTORY: PASS ({args.phase}, {count} intended tests)")


if __name__ == "__main__":
    main()
