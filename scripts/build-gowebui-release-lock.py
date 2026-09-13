#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "GoWebUI-RELEASE-LOCK.json"

INPUTS = [
    "VERSION",
    "BUILD_NUMBER",
    "portable-runtime/go.mod",
    "portable-runtime/main.go",
    "portable-runtime/ui/index.html",
    "portable-runtime/ui/app-icon-128.png",
    "branding/MihomoCoreManager-2.png",
    "branding/AppIcon-master-1024.png",
    "scripts/generate-app-icon.py",
    "scripts/build-gowebui-release-lock.py",
    "scripts/build-gowebui-app.sh",
    "scripts/verify-macho-uuid.py",
    "scripts/build-portable-installer.sh",
    "scripts/build-gowebui-release.sh",
] + [
    f"MihomoCoreManager/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-{size}.png"
    for size in (16, 32, 64, 128, 256, 512, 1024)
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def expected() -> dict:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    build = (ROOT / "BUILD_NUMBER").read_text(encoding="utf-8").strip()
    files = []
    for rel in INPUTS:
        p = ROOT / rel
        if not p.is_file():
            raise SystemExit(f"GoWebUI release lock input missing: {rel}")
        files.append({"path": rel, "sha256": sha256(p), "size": p.stat().st_size})
    tree_h = hashlib.sha256()
    for item in files:
        tree_h.update(item["path"].encode("utf-8"))
        tree_h.update(b"\0")
        tree_h.update(item["sha256"].encode("ascii"))
        tree_h.update(b"\n")
    return {
        "schema": 1,
        "variant": "GoWebUI",
        "version": version,
        "build": build,
        "required_go": "go1.26.8",
        "contract": "ChatGPT portable preview and GitHub GoWebUI.pkg share scripts/build-gowebui-app.sh and these exact release inputs",
        "input_tree_sha256": tree_h.hexdigest(),
        "files": files,
    }


def render(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


parser = argparse.ArgumentParser()
g = parser.add_mutually_exclusive_group(required=True)
g.add_argument("--write", action="store_true")
g.add_argument("--check", action="store_true")
args = parser.parse_args()

text = render(expected())
if args.write:
    LOCK.write_text(text, encoding="utf-8")
    print(f"GoWebUI release lock written: {LOCK.name}")
    raise SystemExit(0)

if not LOCK.is_file():
    print(f"GoWebUI release lock missing: {LOCK.name}", file=sys.stderr)
    raise SystemExit(1)
actual = LOCK.read_text(encoding="utf-8")
if actual != text:
    print("GoWebUI release lock mismatch; regenerate only after intentionally changing the preview/release implementation inputs.", file=sys.stderr)
    raise SystemExit(1)
print("GoWebUI release lock: PASS")
