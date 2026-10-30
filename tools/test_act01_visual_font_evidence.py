#!/usr/bin/env python3
"""Negative contract checks for bundled screenshot font provenance.

Creates isolated fixture images/proof; this checks verification security,
not image quality. Real frames are produced by Godot art acceptance workflow.
"""
import hashlib
import json
import struct
import tempfile
import zlib
from pathlib import Path

from verify_act01_visual_evidence_v3 import (
    FONT_GLYPHS, FONT_PROOF, expected, validate_font_proof, verify,
)


def fake_png(path: Path) -> None:
    # Large well-formed image fixture to test that image-only verification
    # cannot conceal missing/incorrect font provenance.
    raw = b"\x00" + b"\x7f\x7f\x7f" * 640
    payload = zlib.compress(raw * 360)
    def chunk(tag, data):
        import struct as st
        return st.pack(">I", len(data)) + tag + data + st.pack(
            ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
        )
    body = (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", 640,360,8,2,0,0,0)) +
            chunk(b"IDAT", payload) + chunk(b"IEND",b""))
    path.write_bytes(body + b"\x00" * 5000)


def run() -> None:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        frames = root / "visual"
        frames.mkdir()
        source = root / "font.otf"
        # Local fixture, never the actual project font; tests SHA validation.
        source.write_bytes(b"FONT" * 2_500_100)
        checksum = hashlib.sha256(source.read_bytes()).hexdigest()
        for name in expected():
            fake_png(frames / (name + ".png"))
        proof_path = frames / FONT_PROOF
        clean = {
            "schema": "starlit.act01.capture_font.v1",
            "source_path": "res://assets/fonts/NotoSansCJKsc-Regular.otf",
            "autoload": "FontSetup",
            "source_kind": "Godot imported FontFile",
            "loaded_font_class": "FontFile",
            "loaded_font_bytes": source.stat().st_size,
            "loaded_font_sha256": checksum,
            "source_font_sha256": checksum,
            "checked_glyphs": list(FONT_GLYPHS),
            "checked_controls": ["Root", "Dialogue", "Atlas"],
            "same_bundled_font": True,
            "system_font_used": False,
            "godot_visual_font_verified": True,
            "ios_ipa_payload_verified": False,
            "ios_device_verified": False,
        }
        assert "missing:" in str(verify(frames, "test-sha", source)["errors"])
        proof_path.write_text(json.dumps(clean),encoding="utf-8")
        ok = verify(frames, "test-sha", source)
        assert ok["font_proof_verified"] and not ok["errors"], ok["errors"]
        for name, value in (
            ("system_font_used", True),
            ("loaded_font_sha256", "0" * 64),
            ("ios_device_verified", True),
            ("source_kind", "SystemFont"),
        ):
            broken = dict(clean)
            broken[name] = value
            proof_path.write_text(json.dumps(broken), encoding="utf-8")
            result, errors = validate_font_proof(frames, source)
            assert errors, (name, result)
        proof_path.write_text("not-json",encoding="utf-8")
        assert validate_font_proof(frames,source)[1]
    print("PASS: art evidence rejects SystemFont, wrong SHA, fake iPhone approval, missing glyph proof")


if __name__ == "__main__":
    run()
