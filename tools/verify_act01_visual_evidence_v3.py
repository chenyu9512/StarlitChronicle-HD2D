#!/usr/bin/env python3
"""Verify genuine Godot capture outputs for six Act-I chapters, landmarks and interiors.

This validates evidence identity/integrity, NOT visual quality or gameplay acceptance.
Only manual review of the resulting PNGs can supply visual approval.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import struct
from pathlib import Path

MAPS = range(1, 7)
LANDMARKS = (1, 3, 5, 6)
INTERIORS = {1: "house", 2: "shelter", 4: "tavern"}
FONT_PROOF = "cjk-font-evidence-v1.json"
FONT_FILE = Path("assets/fonts/NotoSansCJKsc-Regular.otf")
FONT_GLYPHS = ("星","灯","纪","行","朔","弦","归","航","潮","歌","收","容","所","中","文","あ","ア","A","9")
MIN_FONT_BYTES = 10_000_000


def expected():
    names = []
    for chapter in MAPS:
        names.extend((f"chapter_{chapter:02d}", f"chapter_{chapter:02d}_world"))
        if chapter in LANDMARKS:
            names.extend((f"chapter_{chapter:02d}_landmark",
                          f"chapter_{chapter:02d}_landmark_world"))
        if chapter in INTERIORS:
            name = f"chapter_{chapter:02d}_{INTERIORS[chapter]}"
            names.extend((name, name + "_world"))
    return names


def validate_font_proof(directory: Path, source: Path) -> tuple[dict, list[str]]:
    """The actual screenshot font must be the exact committed source FontFile.

    This cannot prove the exported iPhone PCK font is present or renders on-device.
    """
    errors: list[str] = []
    proof_file = directory / FONT_PROOF
    if not proof_file.is_file():
        return {}, ["missing: " + str(proof_file)]
    try:
        proof = json.loads(proof_file.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return {}, ["invalid_font_proof: " + str(exc)]
    if not isinstance(proof, dict):
        return {}, ["invalid_font_proof: expected object"]
    required = {
        "schema": "starlit.act01.capture_font.v1",
        "source_path": "res://assets/fonts/NotoSansCJKsc-Regular.otf",
        "autoload": "FontSetup",
        "loaded_font_class": "FontFile",
        "same_bundled_font": True,
        "system_font_used": False,
        "godot_visual_font_verified": True,
        "ios_ipa_payload_verified": False,
        "ios_device_verified": False,
    }
    for key, value in required.items():
        if proof.get(key) != value:
            errors.append(f"font_proof_{key}: expected {value!r}")
    if proof.get("source_kind") not in (
        "verified raw export payload", "Godot imported FontFile", "editor source OpenType"
    ):
        errors.append("font_proof_invalid_runtime_source")
    if proof.get("checked_glyphs") != list(FONT_GLYPHS):
        errors.append("font_proof_glyph_coverage_mismatch")
    if not isinstance(proof.get("checked_controls"), list) or len(proof["checked_controls"]) < 3:
        errors.append("font_proof_missing_actual_ui_controls")
    if not source.is_file():
        errors.append("missing_authoritative_font_source: " + str(source))
        return proof, errors
    if source.stat().st_size < MIN_FONT_BYTES:
        errors.append("invalid_authoritative_font_size")
        return proof, errors
    with source.open("rb") as font_file:
        expected_digest = hashlib.file_digest(font_file, "sha256").hexdigest()
    if (proof.get("source_font_sha256") != expected_digest or
            proof.get("loaded_font_sha256") != expected_digest):
        errors.append("font_proof_sha256_mismatch")
    if proof.get("loaded_font_bytes") != source.stat().st_size:
        errors.append("font_proof_byte_count_mismatch")
    return proof, errors


def verify(directory: Path, sha: str, font_source: Path = FONT_FILE) -> dict:
    errors = []
    frames = []
    font_proof, font_errors = validate_font_proof(directory, font_source)
    errors.extend(font_errors)
    for name in expected():
        path = directory / (name + ".png")
        if not path.is_file():
            errors.append("missing: " + str(path))
            continue
        with path.open("rb") as handle:
            header = handle.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
            errors.append("invalid_png: " + str(path))
            continue
        width, height = struct.unpack(">II", header[16:24])
        if width < 640 or height < 360 or width > 8192 or height > 8192:
            errors.append("invalid_frame_size: " + str(path))
            continue
        if path.stat().st_size < 4096:
            errors.append("too_small_for_evidence: " + str(path))
            continue
        with path.open("rb") as image_file:
            digest = hashlib.file_digest(image_file, "sha256").hexdigest()
        frames.append({"name": name, "file": path.name, "width": width,
                       "height": height, "sha256": digest, "bytes": path.stat().st_size})
    return {"schema": "starlit.act01.godot_capture.v3",
            "source_sha": sha, "font_proof_file": FONT_PROOF,
            "font_proof_verified": not font_errors,
            "ios_device_verified": False,
            "expected_frames": len(expected()),
            "captured_frames": len(frames), "frames": frames,
            "errors": errors, "engine_capture_verified": not errors,
            "human_visual_accepted": False,
            "commercial_release_approved": False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, default=Path("build/main2-art-qa/visual"))
    parser.add_argument("--sha", default=os.getenv("GITHUB_SHA", "local_unverified"))
    args = parser.parse_args()
    result = verify(args.directory, args.sha)
    args.directory.mkdir(parents=True, exist_ok=True)
    (args.directory / "visual-evidence-v3.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Godot art evidence {result['captured_frames']}/{result['expected_frames']} "
          f"SHA={args.sha} visual approval=pending")
    for error in result["errors"]:
        print("FAIL", error)
    if result["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
