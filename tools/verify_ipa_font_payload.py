#!/usr/bin/env python3
"""Read the FINAL iPhone IPA / actual Godot PCK and require intact CJK bytes.

Do not trust a source file, macOS editor import test or loose *.otf list.
Godot exports imported fonts to .godot/imported and may drop source .otf.
This checks the raw unimported *.fontbytes file inside the ACTUAL package.
Supports standard nonencrypted PCK versions 2, 3 and 4.
"""
from __future__ import annotations
import argparse
from dataclasses import dataclass
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile
from prepare_export_font import CJK_SHA256, FONT_PAYLOAD


@dataclass(frozen=True)
class Member:
    offset: int
    size: int
    flags: int


def parse_pck(file_bytes: bytes) -> tuple[dict, dict[str, Member]]:
    stream = io.BytesIO(file_bytes)

    def u32() -> int:
        block = stream.read(4)
        if len(block) != 4:
            raise ValueError("truncated PCK uint32")
        return struct.unpack("<I", block)[0]

    def u64() -> int:
        block = stream.read(8)
        if len(block) != 8:
            raise ValueError("truncated PCK uint64")
        return struct.unpack("<Q", block)[0]

    if stream.read(4) != b"GDPC":
        raise ValueError("P0: not a Godot PCK")
    version, major, minor, patch, flags = (u32() for _ in range(5))
    if version not in (2, 3, 4) or major != 4:
        raise ValueError(f"P0: unsupported Godot pack {version} engine {major}.{minor}.{patch}")
    if flags & 1:
        raise ValueError("P0: encrypted PCK directory is not inspectable")
    base = u64()
    if version in (3, 4):
        dir_offset = u64()
    else:
        dir_offset = stream.tell() + 16 * 4
    if dir_offset >= len(file_bytes):
        raise ValueError("P0: PCK directory is out of bounds")
    stream.seek(dir_offset)
    count = u32()
    if count < 1 or count > 200_000:
        raise ValueError(f"P0: unreasonable PCK file count: {count}")
    members: dict[str, Member] = {}
    for _ in range(count):
        path_size = u32()
        if path_size < 1 or path_size > 32768:
            raise ValueError("P0: corrupt PCK path length")
        raw_path = stream.read(path_size)
        if len(raw_path) != path_size:
            raise ValueError("P0: truncated PCK path")
        name = raw_path.rstrip(b"\x00").decode("utf-8")
        name = name.removeprefix("res://")
        offset, size = u64(), u64()
        stream.read(16)  # Godot directory MD5
        file_flags = u32()
        if offset + base + size > len(file_bytes):
            raise ValueError("P0: corrupt PCK member offset/size: " + name)
        members[name] = Member(offset + base, size, file_flags)
    return dict(version=version, godot=f"{major}.{minor}.{patch}", files=count), members


def audit_pck(payload: bytes, label: str) -> dict:
    info, members = parse_pck(payload)
    if FONT_PAYLOAD not in members:
        raise ValueError(
            f"P0: {label}: iOS PCK omits {FONT_PAYLOAD}; FileAccess will "
            "return empty bytes on iPhone and every Chinese UI glyph becomes a square"
        )
    member = members[FONT_PAYLOAD]
    if member.flags & 1:
        raise ValueError("P0: CJK font entry is encrypted")
    font_bytes = payload[member.offset : member.offset + member.size]
    digest = hashlib.sha256(font_bytes).hexdigest()
    if (member.size < 10_000_000 or font_bytes[:4] != b"OTTO"
            or digest != CJK_SHA256):
        raise ValueError(
            f"P0: {label}: actual PCK CJK payload corrupted: size={member.size} sha256={digest}"
        )
    info.update(label=label, cjk_bytes=member.size, cjk_sha256=digest)
    return info


def audit_ipa(path: Path) -> dict:
    with zipfile.ZipFile(path) as archive:
        pcks = [name for name in archive.namelist()
                if name.startswith("Payload/") and name.endswith(".pck")]
        if not pcks:
            raise ValueError(f"P0: {path}: iPhone app contains no Godot .pck")
        details = [audit_pck(archive.read(name), name) for name in pcks]
    return dict(file=str(path), pcks=details)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", type=Path)
    parser.add_argument("--pck", type=Path)
    args = parser.parse_args()
    if bool(args.ipa) == bool(args.pck):
        parser.error("specify exactly one of --ipa and --pck")
    try:
        report = audit_ipa(args.ipa) if args.ipa else audit_pck(args.pck.read_bytes(), str(args.pck))
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        print("P0 IPA CJK FONT AUDIT FAILED:", exc)
        return 1
    print("IPA CJK FONT AUDIT: ALL PASS")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
