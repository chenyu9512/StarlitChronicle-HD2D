#!/usr/bin/env python3
"""Validate source masters; retained PNG-only assets are valid production masters."""
import json
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

root = Path(__file__).resolve().parents[1]
assets = json.loads((root / "assets/art/art_manifest.json").read_text(encoding="utf-8"))["assets"]
assert len({x["path"] for x in assets}) == len(assets)
for asset in assets:
    path = root / asset["path"]
    assert path.is_file(), path
    if path.suffix.lower() == ".svg":
        tag = ET.parse(path).getroot()
        assert [int(tag.attrib["width"]), int(tag.attrib["height"])] == asset["size"], path
    elif path.suffix.lower() == ".png":
        from PIL import Image
        with Image.open(path) as img:
            assert list(img.size) == asset["size"], (path, img.size)
    else:
        raise AssertionError(f"Unsupported art master: {path}")
    if "--check-png" in sys.argv:
        from PIL import Image
        with Image.open(path.with_suffix(".png")) as im:
            assert list(im.size) == asset["size"], path
print("PASS:", len(assets), "art masters")
