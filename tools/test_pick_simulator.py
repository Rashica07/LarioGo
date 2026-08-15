#!/usr/bin/env python3
"""Self-test for tools/pick_simulator.py.

Runs on any platform, so the simulator-selection logic is verified even on
Windows where `xcrun` does not exist.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PICKER = os.path.join(HERE, "pick_simulator.py")

failures: list[str] = []


def run(payload: dict) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, PICKER],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )


def expect_udid(label: str, payload: dict, want: str) -> None:
    result = run(payload)
    got = result.stdout.strip()
    if result.returncode != 0:
        failures.append(f"{label}: exited {result.returncode} ({result.stderr.strip()})")
    elif got != want:
        failures.append(f"{label}: expected {want!r}, got {got!r}")
    else:
        print(f"ok  {label} -> {got}")


def expect_failure(label: str, payload: dict) -> None:
    result = run(payload)
    if result.returncode == 0:
        failures.append(f"{label}: expected non-zero exit, got 0 ({result.stdout.strip()})")
    else:
        print(f"ok  {label} -> failed as expected")


expect_udid(
    "prefers newest iOS runtime and Pro variant",
    {"devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-17-5": [
            {"name": "iPhone 15 Pro", "udid": "OLD", "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-18-4": [
            {"name": "iPhone 16", "udid": "NEW", "isAvailable": True},
            {"name": "iPhone 16 Pro", "udid": "NEW-PRO", "isAvailable": True},
        ],
    }},
    "NEW-PRO",
)

expect_udid(
    "skips unavailable devices",
    {"devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-18-4": [
            {"name": "iPhone 16 Pro", "udid": "DEAD", "isAvailable": False},
            {"name": "iPhone 16", "udid": "LIVE", "isAvailable": True},
        ],
    }},
    "LIVE",
)

expect_udid(
    "ignores non-iOS runtimes and non-iPhone devices",
    {"devices": {
        "com.apple.CoreSimulator.SimRuntime.watchOS-11-0": [
            {"name": "Apple Watch Series 10", "udid": "WATCH", "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-18-0": [
            {"name": "iPad Pro 13-inch", "udid": "IPAD", "isAvailable": True},
            {"name": "iPhone 16", "udid": "PHONE", "isAvailable": True},
        ],
    }},
    "PHONE",
)

expect_udid(
    "orders runtimes numerically, not lexically (iOS 9 must not beat iOS 18)",
    {"devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-9-3": [
            {"name": "iPhone 16 Pro", "udid": "ANCIENT", "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-18-0": [
            {"name": "iPhone 16", "udid": "MODERN", "isAvailable": True},
        ],
    }},
    "MODERN",
)

expect_failure("no devices at all", {"devices": {}})
expect_failure(
    "only unavailable devices",
    {"devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-18-0": [
            {"name": "iPhone 16", "udid": "X", "isAvailable": False},
        ],
    }},
)

print()
if failures:
    for f in failures:
        print(f"FAIL {f}")
    print("RESULT: FAIL")
    sys.exit(1)
print("RESULT: PASS")
