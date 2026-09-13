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
LC_CODE_SIGNATURE = 0x1D
CSMAGIC_EMBEDDED_SIGNATURE = 0xFADE0CC0
CSMAGIC_CODEDIRECTORY = 0xFADE0C02
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



def refresh_adhoc_signature(data: bytearray) -> None:
    """Refresh the existing linker ad-hoc signature after header repair.

    Go's Darwin linker already emits an LC_CODE_SIGNATURE for arm64. In the
    legacy recovery build, inserting LC_UUID changes page 0, so leaving the
    original CodeDirectory hashes untouched makes the Mach-O fail code-sign
    validation before the app can launch. Re-hash the ordinary code slots in
    place; the signature blob size/layout and linker flags remain unchanged.
    """
    ncmds = struct.unpack_from("<I", data, 16)[0]
    off = HEADER64_SIZE
    sig_off = sig_size = None
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, off)
        if cmd == LC_CODE_SIGNATURE:
            if cmdsize < 16:
                raise ValueError("LC_CODE_SIGNATURE command is truncated")
            sig_off, sig_size = struct.unpack_from("<II", data, off + 8)
            break
        off += cmdsize
    if sig_off is None or sig_size is None:
        raise ValueError("arm64 recovery binary has no LC_CODE_SIGNATURE to refresh")
    if sig_off + sig_size > len(data):
        raise ValueError("code signature points beyond end of file")

    magic, total_len, count = struct.unpack_from(">III", data, sig_off)
    if magic != CSMAGIC_EMBEDDED_SIGNATURE or total_len > sig_size:
        raise ValueError("unsupported embedded code signature")

    cdir_rel = None
    for i in range(count):
        slot_type, slot_off = struct.unpack_from(">II", data, sig_off + 12 + i * 8)
        if slot_type == 0:
            cdir_rel = slot_off
            break
    if cdir_rel is None:
        raise ValueError("embedded signature has no CodeDirectory")

    cdir = sig_off + cdir_rel
    (magic, cdir_len, version, _flags, hash_off, _ident_off,
     _special_slots, n_code_slots, code_limit) = struct.unpack_from(">9I", data, cdir)
    if magic != CSMAGIC_CODEDIRECTORY:
        raise ValueError("unsupported CodeDirectory magic")
    if cdir + cdir_len > sig_off + total_len:
        raise ValueError("CodeDirectory extends beyond signature blob")
    hash_size, hash_type, _platform, page_bits = struct.unpack_from(">4B", data, cdir + 36)
    if code_limit == 0 and version >= 0x20300:
        code_limit = struct.unpack_from(">Q", data, cdir + 56)[0]
    if not code_limit or code_limit > sig_off:
        raise ValueError("unsupported CodeDirectory code limit")
    if page_bits > 20:
        raise ValueError("unsupported CodeDirectory page size")
    page_size = 1 << page_bits

    if hash_type == 1:
        digest = lambda payload: hashlib.sha1(payload).digest()
    elif hash_type in (2, 3):
        digest = lambda payload: hashlib.sha256(payload).digest()
    else:
        raise ValueError(f"unsupported CodeDirectory hash type: {hash_type}")

    expected_slots = (code_limit + page_size - 1) // page_size
    if n_code_slots != expected_slots:
        raise ValueError(f"unexpected CodeDirectory slot count: {n_code_slots} != {expected_slots}")
    hash_end = cdir + hash_off + n_code_slots * hash_size
    if hash_end > cdir + cdir_len:
        raise ValueError("CodeDirectory hash slots extend beyond blob")

    for i in range(n_code_slots):
        start = i * page_size
        end = min(start + page_size, code_limit)
        value = digest(bytes(data[start:end]))[:hash_size]
        slot = cdir + hash_off + i * hash_size
        data[slot:slot + hash_size] = value


def verify_adhoc_signature(data: bytearray) -> None:
    """Verify that every ordinary CodeDirectory hash matches the Mach-O."""
    before = bytes(data)
    refreshed = bytearray(data)
    refresh_adhoc_signature(refreshed)
    if bytes(refreshed) != before:
        raise ValueError("ad-hoc code signature hashes are stale")

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
    # Inserting LC_UUID changes code page 0. Refresh the existing Go linker
    # ad-hoc CodeDirectory before writing the recovery artifact.
    refresh_adhoc_signature(data)
    verify_adhoc_signature(data)
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
        current = bytearray(args.binary.read_bytes())
        verify_adhoc_signature(current)
        print(f"Mach-O LC_UUID: {format_uuid(raw)} ({arch}); ad-hoc signature: valid")
        return 0
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
