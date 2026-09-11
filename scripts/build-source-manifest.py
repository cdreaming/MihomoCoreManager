#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / "SOURCE-SHA256SUMS.txt"
ignored_parts = {".git", "build", "dist", "dist-portable", "DerivedData", "xcuserdata", "__pycache__"}


def digest_entries() -> dict[str, str]:
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
    return "".join(f"{digest}  {path}\n" for path, digest in sorted(entries.items()))


def parse_manifest(text: str) -> tuple[dict[str, str], list[str]]:
    parsed: dict[str, str] = {}
    malformed: list[str] = []
    for line_no, line in enumerate(text.splitlines(), 1):
        if not line:
            continue
        if "  " not in line:
            malformed.append(f"line {line_no}: {line!r}")
            continue
        digest, path = line.split("  ", 1)
        digest = digest.lower()
        if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest) or not path:
            malformed.append(f"line {line_no}: {line!r}")
            continue
        parsed[path] = digest
    return parsed, malformed


parser = argparse.ArgumentParser()
parser.add_argument("--write", action="store_true")
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
current = digest_entries()
expected = render(current)

if args.write:
    out.write_text(expected, encoding="utf-8")
    print(f"source manifest written: {out.name} ({len(current)} files)")
    raise SystemExit(0)

if args.check:
    actual_text = out.read_text(encoding="utf-8") if out.exists() else ""
    if actual_text != expected:
        actual, malformed = parse_manifest(actual_text)
        added = sorted(set(current) - set(actual))
        removed = sorted(set(actual) - set(current))
        changed = sorted(p for p in set(current) & set(actual) if current[p] != actual[p])
        print("source manifest is stale; run: python3 scripts/build-source-manifest.py --write")
        if malformed:
            print("malformed manifest entries:")
            for item in malformed[:20]: print(f"  ! {item}")
        if added:
            print("files missing from manifest:")
            for path in added[:50]: print(f"  + {path}")
        if removed:
            print("files no longer present:")
            for path in removed[:50]: print(f"  - {path}")
        if changed:
            print("files whose SHA-256 changed:")
            for path in changed[:50]: print(f"  * {path}")
        raise SystemExit(1)
    print(f"source manifest: PASS ({len(current)} files)")
    raise SystemExit(0)
parser.error("choose --write or --check")
