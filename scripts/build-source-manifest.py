#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / "SOURCE-SHA256SUMS.txt"
ignored_parts = {".git", "build", "dist", "DerivedData", "xcuserdata", "__pycache__"}


def entries():
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path == out:
            continue
        rel = path.relative_to(root)
        if any(part in ignored_parts for part in rel.parts):
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        yield f"{digest}  {rel.as_posix()}"

parser = argparse.ArgumentParser()
parser.add_argument("--write", action="store_true")
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
expected = "\n".join(entries()) + "\n"
if args.write:
    out.write_text(expected, encoding="utf-8")
    print(f"source manifest written: {out.name}")
    raise SystemExit(0)
if args.check:
    actual = out.read_text(encoding="utf-8") if out.exists() else ""
    if actual != expected:
        print("source manifest is stale; run: python3 scripts/build-source-manifest.py --write")
        raise SystemExit(1)
    print("source manifest: PASS")
    raise SystemExit(0)
parser.error("choose --write or --check")
