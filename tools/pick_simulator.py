#!/usr/bin/env python3
"""Print the UDID of the best available iPhone simulator.

CI runner images rotate device names and iOS runtimes without warning, so
hardcoding `name=iPhone 16` produces builds that break for reasons unrelated
to the code. This picks the newest available iPhone instead.

Usage:
    xcrun simctl list devices available --json | python3 tools/pick_simulator.py
"""
from __future__ import annotations

import json
import re
import sys


def runtime_version(runtime_id: str) -> tuple[int, ...]:
    """iOS runtime identifiers look like com.apple.CoreSimulator.SimRuntime.iOS-18-4."""
    m = re.search(r"iOS-([\d-]+)$", runtime_id)
    if not m:
        return (0,)
    return tuple(int(p) for p in m.group(1).split("-") if p.isdigit())


def device_rank(name: str) -> tuple[int, int]:
    """Rank iPhones by model number, preferring Pro/Pro Max variants slightly."""
    m = re.search(r"iPhone\s+(\d+)", name)
    number = int(m.group(1)) if m else 0
    variant = 1 if "Pro" in name else 0
    return (number, variant)


def main() -> int:
    payload = json.load(sys.stdin)
    devices = payload.get("devices", {})

    best = None
    for runtime_id, entries in devices.items():
        if "iOS" not in runtime_id:
            continue
        for device in entries:
            if not device.get("isAvailable", False):
                continue
            name = device.get("name", "")
            if "iPhone" not in name:
                continue
            key = (runtime_version(runtime_id), device_rank(name))
            if best is None or key > best[0]:
                best = (key, device["udid"], name, runtime_id)

    if best is None:
        sys.stderr.write("no available iPhone simulator found\n")
        return 1

    _, udid, name, runtime_id = best
    sys.stderr.write(f"selected: {name} ({runtime_id})\n")
    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
