#!/usr/bin/env python3
"""Release host/target architecture policy shared by preflight and simulation."""
from __future__ import annotations

import argparse

RELEASE_TARGET_ARCH = "arm64"
SUPPORTED_MACOS_HOST_ARCHS = frozenset({"x86_64", "arm64"})


def validate_release_host(system: str, machine: str) -> str:
    """Validate a host for the arm64 macOS release pipeline.

    macos-15-intel is intentionally supported: Xcode and Go cross-build the
    arm64 target and the release builders verify every final executable with
    lipo.  The host architecture is therefore not the release architecture.
    """
    if system != "Darwin":
        raise ValueError("--strict-macos requires macOS")
    if machine not in SUPPORTED_MACOS_HOST_ARCHS:
        raise ValueError(f"--strict-macos unsupported macOS host architecture: {machine}")
    return RELEASE_TARGET_ARCH


def self_test() -> None:
    assert validate_release_host("Darwin", "x86_64") == "arm64"
    assert validate_release_host("Darwin", "arm64") == "arm64"
    for system, machine in [("Linux", "x86_64"), ("Darwin", "i386")]:
        try:
            validate_release_host(system, machine)
        except ValueError:
            pass
        else:
            raise AssertionError(f"unexpectedly accepted {system}/{machine}")
    print("release host policy: PASS (Darwin x86_64/arm64 hosts -> arm64 target)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        parser.error("choose --self-test")
