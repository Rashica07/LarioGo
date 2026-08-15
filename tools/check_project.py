#!/usr/bin/env python3
"""Structural integrity check for the LarioGo Xcode project.

This is not a substitute for `xcodebuild` — it cannot type-check Swift. It
catches the class of corruption that makes a project fail to open or a CI
build fail before compilation even starts, and it runs on any platform with
Python, which matters because most development on this project happens on
Windows where no Swift toolchain exists.

Checks:
  1. .pbxproj delimiters balance
  2. no duplicate object definitions
  3. no dangling object references
  4. no orphaned objects
  5. every native target resolves its build phases and configuration list
  6. the project's target list matches the defined native targets
  7. every shared scheme is well-formed XML
  8. every scheme BlueprintIdentifier resolves to a real target
  9. every referenced asset name in Swift source exists in the asset catalog

Usage:  python tools/check_project.py [--strict]
Exit code 0 = pass, 1 = fail.  `--strict` promotes warnings to failures.
"""
from __future__ import annotations

import io
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBXPROJ = os.path.join(ROOT, "LarioGo.xcodeproj", "project.pbxproj")
SCHEME_DIR = os.path.join(ROOT, "LarioGo.xcodeproj", "xcshareddata", "xcschemes")
ASSETS = os.path.join(ROOT, "LarioGo", "Assets.xcassets")
SOURCE_DIRS = [os.path.join(ROOT, "LarioGo")]

STRICT = "--strict" in sys.argv

errors: list[str] = []
warnings: list[str] = []
OBJ = r"[0-9A-F]{24}"


def read(path: str) -> str:
    return io.open(path, encoding="utf-8").read()


# --------------------------------------------------------------------------
# .pbxproj
# --------------------------------------------------------------------------
def check_pbxproj() -> tuple[dict[str, str], set[str]]:
    if not os.path.exists(PBXPROJ):
        errors.append(f"missing {PBXPROJ}")
        return {}, set()
    src = read(PBXPROJ)

    # 1. delimiter balance, ignoring comments and quoted strings
    bare = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    bare = re.sub(r'"(?:[^"\\]|\\.)*"', '""', bare)
    for a, b in (("{", "}"), ("(", ")")):
        if bare.count(a) != bare.count(b):
            errors.append(f"pbxproj: unbalanced {a}{b} ({bare.count(a)} vs {bare.count(b)})")

    # 2. definitions
    defined = Counter()
    for m in re.finditer(rf"^\t\t({OBJ})\s*(?:/\*.*?\*/)?\s*=\s*\{{", src, flags=re.M):
        defined[m.group(1)] += 1
    for oid, n in defined.items():
        if n > 1:
            errors.append(f"pbxproj: object {oid} defined {n} times")

    # 3. dangling references
    counts = Counter(re.findall(rf"\b({OBJ})\b", src))
    for oid in sorted(set(counts) - set(defined)):
        sample = next((l.strip() for l in src.splitlines() if oid in l), "")
        errors.append(f"pbxproj: dangling reference {oid} <- {sample[:90]}")

    # 4. orphans
    root_m = re.search(rf"rootObject\s*=\s*({OBJ})", src)
    root_id = root_m.group(1) if root_m else None
    for oid in defined:
        if counts[oid] <= 1 and oid != root_id:
            warnings.append(f"pbxproj: orphaned object {oid} (defined, never referenced)")

    # 5 + 6. targets
    targets = re.findall(
        rf"^\t\t({OBJ}) /\* ([^*\n]+?) \*/ = \{{\n\t\t\tisa = PBXNativeTarget;(.*?)^\t\t\}};",
        src, flags=re.M | re.S)
    if not targets:
        errors.append("pbxproj: no PBXNativeTarget defined")
    target_map = {tid: name for tid, name, _ in targets}
    for tid, name, body in targets:
        if not re.search(rf"buildConfigurationList = {OBJ}", body):
            errors.append(f"pbxproj: target {name} has no buildConfigurationList")
        for ref in re.findall(rf"\b({OBJ})\b", body):
            if ref not in defined:
                errors.append(f"pbxproj: target {name} references undefined {ref}")

    listed_m = re.search(r"targets = \((.*?)\);", src, flags=re.S)
    if listed_m:
        listed = set(re.findall(rf"\b({OBJ})\b", listed_m.group(1)))
        for t in set(target_map) - listed:
            errors.append(f"pbxproj: target {target_map[t]} not in project targets list")
        for t in listed - set(target_map):
            errors.append(f"pbxproj: targets list entry {t} is not a native target")

    return target_map, set(defined)


# --------------------------------------------------------------------------
# schemes
# --------------------------------------------------------------------------
def check_schemes(target_map: dict[str, str]) -> None:
    if not os.path.isdir(SCHEME_DIR):
        errors.append(
            "no shared scheme directory — `xcodebuild -scheme LarioGo` will fail in CI. "
            "Expected LarioGo.xcodeproj/xcshareddata/xcschemes/")
        return
    schemes = [f for f in os.listdir(SCHEME_DIR) if f.endswith(".xcscheme")]
    if not schemes:
        errors.append("no .xcscheme in xcshareddata/xcschemes — CI cannot select a scheme")
        return
    for fn in schemes:
        path = os.path.join(SCHEME_DIR, fn)
        try:
            tree = ET.parse(path)
        except ET.ParseError as exc:
            errors.append(f"scheme {fn}: malformed XML — {exc}")
            continue
        refs = tree.getroot().iter("BuildableReference")
        seen = 0
        for ref in refs:
            seen += 1
            bid = ref.get("BlueprintIdentifier", "")
            bname = ref.get("BlueprintName", "?")
            if bid not in target_map:
                errors.append(
                    f"scheme {fn}: BlueprintIdentifier {bid} ({bname}) matches no target")
            elif target_map[bid] != bname:
                warnings.append(
                    f"scheme {fn}: BlueprintName '{bname}' != target name '{target_map[bid]}'")
        if seen == 0:
            errors.append(f"scheme {fn}: no BuildableReference entries")


# --------------------------------------------------------------------------
# assets
# --------------------------------------------------------------------------
def check_assets() -> None:
    if not os.path.isdir(ASSETS):
        errors.append(f"missing asset catalog {ASSETS}")
        return

    available: set[str] = set()
    for entry in os.listdir(ASSETS):
        base, ext = os.path.splitext(entry)
        if ext in (".imageset", ".colorset", ".appiconset", ".symbolset"):
            available.add(base)
        elif os.path.isdir(os.path.join(ASSETS, entry)) and ext == "":
            warnings.append(
                f"asset '{entry}' has no .imageset/.colorset extension — "
                "Xcode will not expose it as an asset name")

    # imagesets whose Contents.json links no file are dead
    for entry in os.listdir(ASSETS):
        if entry.endswith(".imageset"):
            cj = os.path.join(ASSETS, entry, "Contents.json")
            if os.path.exists(cj) and '"filename"' not in read(cj):
                warnings.append(f"asset {entry} declares no filename — it will never render")

    referenced: set[str] = set()
    for d in SOURCE_DIRS:
        for dirpath, _, files in os.walk(d):
            for fn in files:
                if not fn.endswith(".swift"):
                    continue
                text = read(os.path.join(dirpath, fn))
                for m in re.finditer(r'imageName:\s*"([^"]+)"', text):
                    referenced.add(m.group(1))

    for name in sorted(referenced - available):
        warnings.append(
            f"image '{name}' referenced in source but absent from the asset catalog "
            "(SiteImage falls back to a placeholder)")


# --------------------------------------------------------------------------
def main() -> int:
    target_map, _ = check_pbxproj()
    check_schemes(target_map)
    check_assets()

    print(f"targets : {', '.join(sorted(target_map.values())) or '(none)'}")
    print(f"warnings: {len(warnings)}")
    print(f"errors  : {len(errors)}")
    print()
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print()

    failed = bool(errors) or (STRICT and bool(warnings))
    print("RESULT:", "FAIL" if failed else "PASS")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
