#!/usr/bin/env python3
"""Export-only CJK byte copy: Godot does not import unknown *.fontbytes.

IMPORTANT: Never assume FileAccess(res://...otf) works in an exported game.
Call this BEFORE Godot --editor --import, then verify the final IPA payload.
"""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path

CJK_SHA256 = "2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b"
FONT_SOURCE = "assets/fonts/NotoSansCJKsc-Regular.otf"
FONT_PAYLOAD = "assets/fonts/NotoSansCJKsc-Regular.fontbytes"


def prepare(root: Path) -> Path:
    source = root / FONT_SOURCE
    payload = root / FONT_PAYLOAD
    raw = source.read_bytes()
    if len(raw) < 10_000_000 or raw[:4] != b"OTTO":
        raise ValueError("P0: original OpenType is absent or truncated")
    digest = hashlib.sha256(raw).hexdigest()
    if digest != CJK_SHA256:
        raise ValueError(f"P0: wrong Noto CJK font checksum: {digest}")
    payload.parent.mkdir(parents=True, exist_ok=True)
    if not payload.is_file() or payload.read_bytes() != raw:
        payload.write_bytes(raw)
    if hashlib.sha256(payload.read_bytes()).hexdigest() != CJK_SHA256:
        raise ValueError("P0: copied raw payload has different checksum")
    print(f"CJK_EXPORT_PAYLOAD_PREPARED {FONT_PAYLOAD} bytes={len(raw)} sha256={digest}")
    return payload


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    prepare(args.project.resolve())
