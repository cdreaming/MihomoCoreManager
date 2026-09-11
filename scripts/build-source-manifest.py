#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / "SOURCE-SHA256SUMS.txt"
ignored_parts = {".git", "build", "dist", "dist-portable", "DerivedData", "xcuserdata", "__pycache__"}


def entry_map() -> dict[str, str]:
    result: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path == out:
            continue
        rel = path.relative_to(root)
        if any(part in ignored_parts for part in rel.parts):
            continue
        result[rel.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def render(entries: dict[str, str]) -> str:
    return "".join(f"{digest}  {rel}\n" for rel, digest in sorted(entries.items()))


def parse_manifest(text: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        digest, sep, rel = line.partition("  ")
        if not sep:
            continue
        parsed[rel] = digest
    return parsed


def report_diff(actual: dict[str, str], expected: dict[str, str]) -> None:
    missing = sorted(expected.keys() - actual.keys())
    extra = sorted(actual.keys() - expected.keys())
    changed = sorted(rel for rel in expected.keys() & actual.keys() if expected[rel] != actual[rel])
    if missing:
        print("files missing from manifest:")
        for rel in missing:
            print(f"  + {rel}")
    if extra:
        print("files no longer present:")
        for rel in extra:
            print(f"  - {rel}")
    if changed:
        print("files with changed SHA-256:")
        for rel in changed:
            print(f"  * {rel}")


parser = argparse.ArgumentParser()
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--write", action="store_true")
group.add_argument("--check", action="store_true")
args = parser.parse_args()

expected_map = entry_map()
expected_text = render(expected_map)
if args.write:
    out.write_text(expected_text, encoding="utf-8")
    print(f"source manifest written: {out.name} ({len(expected_map)} files)")
    raise SystemExit(0)

actual_text = out.read_text(encoding="utf-8") if out.exists() else ""
if actual_text != expected_text:
    print("source manifest is stale; run: python3 scripts/build-source-manifest.py --write")
    report_diff(parse_manifest(actual_text), expected_map)
    raise SystemExit(1)
print(f"source manifest: PASS ({len(expected_map)} files)")
