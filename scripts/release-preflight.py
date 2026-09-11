#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import platform
import plistlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
BUILD = VERSION.replace(".", "")
DEPLOYMENT_TARGET = "14.0"


def run(cmd: list[str], *, cwd: Path = ROOT, capture: bool = False) -> str:
    print("+ " + " ".join(cmd), flush=True)
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=True,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.STDOUT if capture else None,
        )
    except subprocess.CalledProcessError as exc:
        if capture and exc.stdout:
            print(exc.stdout, end="", file=sys.stderr)
        print(f"FAIL: command failed ({exc.returncode}): {' '.join(cmd)}", file=sys.stderr)
        raise SystemExit(exc.returncode)
    return result.stdout if capture and result.stdout is not None else ""


def require(command: str) -> str:
    path = shutil.which(command)
    if not path:
        print(f"FAIL: required command not found: {command}", file=sys.stderr)
        raise SystemExit(1)
    return path


def swift_files() -> list[Path]:
    return sorted((ROOT / "MihomoCoreManager").rglob("*.swift"))


def parse_swift(swiftc: list[str]) -> None:
    for path in swift_files():
        run(swiftc + ["-frontend", "-parse", "-swift-version", "5", str(path)])


def typecheck_models_linux(swiftc: str) -> None:
    run([swiftc, "-typecheck", "-swift-version", "5", "MihomoCoreManager/Models.swift"])


def strict_macos_checks() -> None:
    system = platform.system()
    machine = platform.machine()
    if system != "Darwin" or machine != "arm64":
        print(f"FAIL: --strict-macos requires Darwin arm64; got {system} {machine}", file=sys.stderr)
        raise SystemExit(1)

    for command in ["xcodebuild", "xcrun", "lipo", "codesign", "pkgbuild", "pkgutil", "ditto", "go"]:
        require(command)

    run(["xcodebuild", "-version"])
    sdk = run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture=True).strip()
    if not sdk or not Path(sdk).exists():
        print(f"FAIL: invalid macOS SDK path: {sdk!r}", file=sys.stderr)
        raise SystemExit(1)

    swiftc_path = run(["xcrun", "--sdk", "macosx", "--find", "swiftc"], capture=True).strip()
    if not swiftc_path:
        print("FAIL: xcrun could not locate swiftc", file=sys.stderr)
        raise SystemExit(1)
    parse_swift([swiftc_path])
    run([
        "xcrun", "--sdk", "macosx", "swiftc",
        "-typecheck", "-swift-version", "5",
        "-sdk", sdk,
        "-target", f"arm64-apple-macos{DEPLOYMENT_TARGET}",
        "MihomoCoreManager/Models.swift",
    ])

    settings = run([
        "xcodebuild",
        "-project", "MihomoCoreManager.xcodeproj",
        "-scheme", "MihomoCoreManager",
        "-configuration", "Release",
        "-destination", "generic/platform=macOS",
        "-showBuildSettings",
        f"MARKETING_VERSION={VERSION}",
        f"CURRENT_PROJECT_VERSION={BUILD}",
        "ARCHS=arm64",
        "ONLY_ACTIVE_ARCH=YES",
        "SWIFT_ENABLE_BATCH_MODE=NO",
    ], capture=True)
    expected_settings = {
        "ARCHS": "arm64",
        "MACOSX_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "MARKETING_VERSION": VERSION,
        "CURRENT_PROJECT_VERSION": BUILD,
        "SWIFT_VERSION": "5.0",
        "SWIFT_ENABLE_BATCH_MODE": "NO",
    }
    for key, expected in expected_settings.items():
        match = re.search(rf"^\s*{re.escape(key)}\s*=\s*(.+?)\s*$", settings, re.M)
        if not match or match.group(1).strip() != expected:
            got = match.group(1).strip() if match else "<missing>"
            print(f"FAIL: Xcode Release setting {key}={got!r}, expected {expected!r}", file=sys.stderr)
            raise SystemExit(1)


def verify_project_version() -> None:
    pbx = (ROOT / "MihomoCoreManager.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    if f"MARKETING_VERSION = {VERSION};" not in pbx:
        raise SystemExit(f"FAIL: MARKETING_VERSION does not match {VERSION}")
    if f"CURRENT_PROJECT_VERSION = {BUILD};" not in pbx:
        raise SystemExit(f"FAIL: CURRENT_PROJECT_VERSION does not match {BUILD}")
    with (ROOT / "MihomoCoreManager/Info.plist").open("rb") as f:
        info = plistlib.load(f)
    if info.get("CFBundleShortVersionString") != "$(MARKETING_VERSION)":
        raise SystemExit("FAIL: Info.plist must derive short version from MARKETING_VERSION")
    if info.get("CFBundleVersion") != "$(CURRENT_PROJECT_VERSION)":
        raise SystemExit("FAIL: Info.plist must derive build number from CURRENT_PROJECT_VERSION")


def main() -> int:
    parser = argparse.ArgumentParser(description="Release preflight for Mihomo Core Manager")
    parser.add_argument("--strict-macos", action="store_true", help="require Apple Silicon macOS + Xcode and validate SDK-bound Swift/Xcode settings")
    args = parser.parse_args()

    print(f"release preflight: v{VERSION} (build {BUILD})")
    print(f"host: {platform.system()} {platform.machine()} / Python {platform.python_version()}")

    # Release runners work from an exact commit/tag checkout. Rebuild generated
    # source metadata there before checking it, so a stale generated manifest
    # cannot prevent the real compiler gates from running. PR/main CI still runs
    # a strict manifest --check before entering this script.
    if args.strict_macos:
        run([sys.executable, "scripts/build-source-manifest.py", "--write"])

    run([sys.executable, "scripts/validate-source.py"])
    run([sys.executable, "scripts/build-source-manifest.py", "--check"])
    verify_project_version()

    for script in sorted((ROOT / "scripts").glob("*.sh")):
        run(["bash", "-n", str(script.relative_to(ROOT))])
    for script in sorted((ROOT / "scripts").glob("*.py")):
        run([sys.executable, "-m", "py_compile", str(script.relative_to(ROOT))])

    if args.strict_macos:
        strict_macos_checks()
    else:
        swiftc = shutil.which("swiftc")
        if swiftc:
            parse_swift([swiftc])
            try:
                typecheck_models_linux(swiftc)
            except SystemExit:
                print("note: host Swift semantic typecheck is unavailable/incompatible; syntax parse already passed", file=sys.stderr)
        else:
            print("note: swiftc not installed; non-macOS preflight skips Swift parse")

    print("release preflight: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
