#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
version = (root / "VERSION").read_text(encoding="utf-8").strip()
build_number = version.replace(".", "")


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def run(cmd: list[str], *, cwd: Path = root, env: dict[str, str] | None = None, capture: bool = False) -> str:
    printable = " ".join(cmd)
    print(f"+ {printable}")
    completed = subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        capture_output=capture,
    )
    if completed.returncode != 0:
        if capture:
            sys.stderr.write(completed.stdout)
            sys.stderr.write(completed.stderr)
        fail(f"command failed ({completed.returncode}): {printable}")
    return (completed.stdout + completed.stderr) if capture else ""


parser = argparse.ArgumentParser(
    description="Release preflight that encodes v1.2.4 macOS/Xcode incident guardrails."
)
parser.add_argument(
    "--strict-macos",
    action="store_true",
    help="require an Apple Silicon macOS runner with Xcode and validate Xcode build settings",
)
args = parser.parse_args()

print(f"release preflight: v{version} (build {build_number})")
print(f"host: {platform.system()} {platform.machine()} / Python {platform.python_version()}")

# 1. Repository/source gates.
#
# SOURCE-SHA256SUMS.txt is generated metadata.  A strict Release preflight must
# be self-contained instead of depending on a previous workflow step: rebuild
# the manifest from the exact checked-out tag/commit, then verify it.  Normal
# non-strict CI/preflight keeps the committed-manifest hard gate.
manifest_path = root / "SOURCE-SHA256SUMS.txt"
if args.strict_macos:
    manifest_before = manifest_path.read_bytes() if manifest_path.exists() else b""
    run([sys.executable, "scripts/build-source-manifest.py", "--write"])
    manifest_after = manifest_path.read_bytes()
    if manifest_before != manifest_after:
        print("release preflight: refreshed stale source manifest from exact checkout")
else:
    run([sys.executable, "scripts/build-source-manifest.py", "--check"])

run([sys.executable, "scripts/validate-source.py"])
run([sys.executable, "scripts/build-source-manifest.py", "--check"])

# Fail fast on a non-macOS host after the manifest/source gates.  This ordering
# lets the exact --strict-macos command exercise the same manifest logic in
# portable release simulations without pretending Linux is macOS.
if args.strict_macos:
    if platform.system() != "Darwin":
        fail("--strict-macos requires macOS")
    if platform.machine() != "arm64":
        fail("--strict-macos requires an arm64 Apple Silicon runner")

for script in ["scripts/build-release.sh", "scripts/build-portable-installer.sh", "scripts/simulate-release.sh"]:
    run(["bash", "-n", script])

# 2. Project membership: every Swift source on disk must be represented in the Xcode project.
pbx_path = root / "MihomoCoreManager.xcodeproj/project.pbxproj"
pbx = pbx_path.read_text(encoding="utf-8")
swift_sources = sorted((root / "MihomoCoreManager").rglob("*.swift"))
if not swift_sources:
    fail("no Swift sources found")
for source in swift_sources:
    rel = source.relative_to(root).as_posix()
    if rel not in pbx:
        fail(f"Swift source is not referenced by Xcode project: {rel}")
    if f"{source.name} in Sources" not in pbx:
        fail(f"Swift source is not in PBXSourcesBuildPhase: {rel}")

# 3. Parse every Swift source in Swift 5 language mode. This is intentionally in addition
#    to xcodebuild so malformed files fail before the slower release build.
swiftc: str | None = None
if platform.system() == "Darwin" and shutil.which("xcrun"):
    probe = subprocess.run(["xcrun", "--find", "swiftc"], text=True, capture_output=True)
    if probe.returncode == 0:
        swiftc = probe.stdout.strip()
if not swiftc:
    swiftc = shutil.which("swiftc")
if not swiftc:
    fail("swiftc is required for release preflight")

for source in swift_sources:
    run([swiftc, "-frontend", "-parse", "-swift-version", "5", str(source)])

# Models.swift can be semantically type-checked without AppKit/SwiftUI.
#
# Syntax-only parsing does not need the macOS SDK, but semantic `-typecheck`
# does. On Xcode 16.4, invoking the toolchain binary directly without an SDK can
# infer an Apple target while still being unable to load its standard library.
if platform.system() == "Darwin":
    if not shutil.which("xcrun"):
        fail("xcrun is required for macOS Swift semantic typecheck")
    macos_sdk = run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture=True).strip()
    if not macos_sdk or not Path(macos_sdk).is_dir():
        fail(f"invalid macOS SDK path returned by xcrun: {macos_sdk!r}")
    deployment_target = "14.0"
    swift_target = f"arm64-apple-macos{deployment_target}"
    run([
        "xcrun", "--sdk", "macosx", "swiftc",
        "-typecheck",
        "-swift-version", "5",
        "-sdk", macos_sdk,
        "-target", swift_target,
        "MihomoCoreManager/Models.swift",
    ])
else:
    run([swiftc, "-typecheck", "-swift-version", "5", "MihomoCoreManager/Models.swift"])

# 4. v1.2.4 Xcode 16.4 regression probes. Linux Swift accepted one of the bad
#    Optional<Bool> expression-pattern forms that Xcode 16.4 rejected, so these
#    are explicit source guards rather than relying on host-compiler behavior.
content = (root / "MihomoCoreManager/Views/ContentView.swift").read_text(encoding="utf-8")
models = (root / "MihomoCoreManager/Models.swift").read_text(encoding="utf-8")
build_script = (root / "scripts/build-release.sh").read_text(encoding="utf-8")

required_content_markers = [
    "private struct ProxySortPicker: View",
    "groupDetailHeader(group)",
    "groupDetailToolbar",
    "groupMemberList(group)",
    "case .some(true): aliveRank = 0",
    "case .none: aliveRank = 1",
    "case .some(false): aliveRank = 2",
    "let history: [MihomoProxyDelaySample]",
    ".onChange(of: busy) { _, newValue in",
]
for marker in required_content_markers:
    if marker not in content:
        fail(f"v1.2.4 Xcode compile guard missing: {marker}")

for forbidden in [
    "case true: aliveRank = 0",
    "case false: aliveRank = 2",
    "let history = Array(proxy?.history.suffix(6) ?? [])",
    "private func sortControl(selection: Binding<ProxySortOption>)",
    ".onChange(of: busy) { newValue in",
]:
    if forbidden in content:
        fail(f"v1.2.4 Xcode compile regression returned: {forbidden}")

if "enum ProxySortOption: String, CaseIterable, Identifiable, Hashable" not in models:
    fail("ProxySortOption must remain explicitly Hashable")

for marker in [
    "SWIFT_ENABLE_BATCH_MODE=NO",
    "xcodebuild-release.log",
    "Xcode compiler diagnostics",
    "xcrun swiftc --version",
]:
    if marker not in build_script:
        fail(f"release compiler diagnostic guard missing: {marker}")

# 5. Portable runtime is a first-class Release asset: unit-test it under the exact
#    CGO-disabled configuration used by GitHub Actions.
go = shutil.which("go")
if not go:
    fail("Go is required for portable release parity")
go_env = os.environ.copy()
go_env["CGO_ENABLED"] = "0"
run([go, "test", "./..."], cwd=root / "portable-runtime", env=go_env)

# 6. Strict runner checks used by GitHub macos-15 CI/Release.
if args.strict_macos:
    for tool in ["xcodebuild", "xcrun", "lipo", "codesign", "ditto", "pkgbuild", "productbuild", "shasum"]:
        if not shutil.which(tool):
            fail(f"required macOS release tool is missing: {tool}")

    run(["sw_vers"])
    run(["xcodebuild", "-version"])
    run(["xcrun", "swiftc", "--version"])
    sdk_path = run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture=True).strip()
    if "/MacOSX" not in sdk_path or not sdk_path.endswith(".sdk"):
        fail(f"xcrun selected an unexpected macOS SDK path: {sdk_path!r}")
    print(f"macOS SDK: {sdk_path}")

    settings = run(
        [
            "xcodebuild",
            "-project", "MihomoCoreManager.xcodeproj",
            "-scheme", "MihomoCoreManager",
            "-configuration", "Release",
            "-destination", "platform=macOS",
            "-showBuildSettings",
            "ARCHS=arm64",
            "ONLY_ACTIVE_ARCH=YES",
            f"MARKETING_VERSION={version}",
            f"CURRENT_PROJECT_VERSION={build_number}",
            "CODE_SIGNING_ALLOWED=NO",
            "SWIFT_ENABLE_BATCH_MODE=NO",
        ],
        capture=True,
    )
    expected_settings = {
        "ARCHS": "arm64",
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "MARKETING_VERSION": version,
        "CURRENT_PROJECT_VERSION": build_number,
        "SWIFT_VERSION": "5.0",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ENABLE_BATCH_MODE": "NO",
    }
    for key, expected in expected_settings.items():
        match = re.search(rf"^\s*{re.escape(key)}\s*=\s*(.+?)\s*$", settings, re.MULTILINE)
        if not match:
            fail(f"Xcode build setting not found: {key}")
        if match.group(1).strip() != expected:
            fail(f"Xcode build setting {key}={match.group(1).strip()!r}, expected {expected!r}")

print(
    f"release preflight: PASS (v{version}, {len(swift_sources)} Swift files, "
    f"portable Go tests, v1.2.4 Xcode regression guards"
    + (", strict macOS/Xcode settings" if args.strict_macos else "")
    + ")"
)
