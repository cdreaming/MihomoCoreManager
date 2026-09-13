#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import struct
import sys
import uuid

MH_MAGIC_64 = 0xFEEDFACF
LC_UUID = 0x1B
LC_SEGMENT_64 = 0x19
HEADER64_SIZE = 32


def parse(path: Path) -> tuple[bytearray, str, int, int, bytes | None, int]:
    data = bytearray(path.read_bytes())
    if len(data) < HEADER64_SIZE:
        raise ValueError("file is too small for a Mach-O header")
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic != MH_MAGIC_64:
        raise ValueError(f"expected thin 64-bit little-endian Mach-O, magic=0x{magic:08x}")
    cputype = struct.unpack_from("<i", data, 4)[0]
    arch = {0x0100000C: "arm64", 0x01000007: "x86_64"}.get(cputype, f"cpu={cputype}")
    ncmds, sizeofcmds = struct.unpack_from("<II", data, 16)
    off = HEADER64_SIZE
    uuid_bytes = None
    first_section_offset = len(data)
    for _ in range(ncmds):
        if off + 8 > len(data):
            raise ValueError("truncated Mach-O load command table")
        cmd, cmdsize = struct.unpack_from("<II", data, off)
        if cmdsize < 8 or off + cmdsize > len(data):
            raise ValueError("invalid Mach-O load command size")
        if cmd == LC_UUID:
            if cmdsize < 24:
                raise ValueError("LC_UUID command is truncated")
            uuid_bytes = bytes(data[off + 8: off + 24])
        elif cmd == LC_SEGMENT_64 and cmdsize >= 72:
            nsects = struct.unpack_from("<I", data, off + 64)[0]
            sect = off + 72
            for _ in range(nsects):
                if sect + 80 > off + cmdsize:
                    raise ValueError("truncated section_64 table")
                section_offset = struct.unpack_from("<I", data, sect + 48)[0]
                section_size = struct.unpack_from("<Q", data, sect + 40)[0]
                if section_offset and section_size:
                    first_section_offset = min(first_section_offset, section_offset)
                sect += 80
        off += cmdsize
    expected_end = HEADER64_SIZE + sizeofcmds
    if off != expected_end:
        raise ValueError(f"load-command size mismatch: parsed={off-HEADER64_SIZE}, header={sizeofcmds}")
    return data, arch, ncmds, sizeofcmds, uuid_bytes, first_section_offset


def repair(path: Path) -> bytes:
    data, arch, ncmds, sizeofcmds, existing, first_section_offset = parse(path)
    if existing is not None:
        return existing
    insert_at = HEADER64_SIZE + sizeofcmds
    cmdsize = 24
    if first_section_offset < insert_at + cmdsize:
        raise ValueError(
            f"no Mach-O header padding for LC_UUID: commands end at {insert_at}, first section at {first_section_offset}"
        )
    padding = data[insert_at: insert_at + cmdsize]
    if any(padding):
        raise ValueError("Mach-O header padding is not zero; refusing in-place UUID repair")

    # Deterministic UUID derived from the pre-repair executable. Mark it as a
    # name/hash-style UUID, matching the intent of Go's reproducible linker UUID.
    raw = bytearray(hashlib.sha256(data).digest()[:16])
    raw[6] = (raw[6] & 0x0F) | 0x30
    raw[8] = (raw[8] & 0x3F) | 0x80
    struct.pack_into("<II", data, insert_at, LC_UUID, cmdsize)
    data[insert_at + 8: insert_at + 24] = raw
    struct.pack_into("<II", data, 16, ncmds + 1, sizeofcmds + cmdsize)
    path.write_bytes(data)
    path.chmod(path.stat().st_mode | 0o111)
    repaired = parse(path)[4]
    if repaired != bytes(raw):
        raise ValueError("LC_UUID repair verification failed")
    return bytes(raw)


def format_uuid(raw: bytes) -> str:
    return str(uuid.UUID(bytes=raw)).upper()


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify (or recovery-repair) Mach-O LC_UUID.")
    ap.add_argument("binary", type=Path)
    ap.add_argument("--repair", action="store_true", help="insert a deterministic LC_UUID into available header padding")
    args = ap.parse_args()
    try:
        _, arch, _, _, raw, _ = parse(args.binary)
        if raw is None and args.repair:
            raw = repair(args.binary)
            print(f"Mach-O LC_UUID repaired: {format_uuid(raw)} ({arch})")
            return 0
        if raw is None:
            print(f"FAIL: Mach-O LC_UUID missing ({arch}): {args.binary}", file=sys.stderr)
            return 1
        print(f"Mach-O LC_UUID: {format_uuid(raw)} ({arch})")
        return 0
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
