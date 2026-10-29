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


def verify(directory: Path, sha: str) -> dict:
    errors = []
    frames = []
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
            "source_sha": sha, "expected_frames": len(expected()),
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
