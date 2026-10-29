#!/usr/bin/env python3
"""Validate the art-free Starlit Chronicle game-core working tree."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_CORE = (
    "project.godot", "export_presets.cfg", "scenes/first_act.tscn",
    "scripts/first_act.gd", "scripts/first_act_world.gd",
    "data/assets/art_theme_v2.json", "data/assets/c_act01_hd2d_v18.json",
    "assets/art/art_manifest.json", "assets/art/runtime/manifest.json",
)
IMAGE_EXT = {
    ".png", ".svg", ".jpg", ".jpeg", ".webp", ".gif",
    ".bmp", ".tga", ".tif", ".tiff", ".dds", ".ktx2",
    ".ico", ".exr", ".psd", ".ase", ".aseprite",
}
ALLOWED_ART_METADATA = {".json", ".csv", ".md", ".txt", ".gdignore"}
FORBIDDEN_ART_FOLDERS = ("assets/art/source_packs", "assets/art/external")

def main() -> int:
    missing = [rel for rel in REQUIRED_CORE if not (ROOT / rel).is_file()]
    art_images = [p.relative_to(ROOT).as_posix() for p in
                  (ROOT / "assets").rglob("*") if p.is_file() and
                  p.suffix.lower() in IMAGE_EXT]
    non_metadata_art = [p.relative_to(ROOT).as_posix() for p in
                        (ROOT / "assets/art").rglob("*") if p.is_file() and
                        p.suffix.lower() not in ALLOWED_ART_METADATA]
    unexpected_packs = [rel for rel in FORBIDDEN_ART_FOLDERS if (ROOT / rel).exists()]
    print("Required game core:", len(REQUIRED_CORE) - len(missing), "/", len(REQUIRED_CORE))
    print("Art image files:", len(art_images))
    print("Non-metadata art files:", len(non_metadata_art))
    print("Raw art directories:", len(unexpected_packs))
    failures = missing + art_images + non_metadata_art + unexpected_packs
    for issue in failures[:50]:
        print("FAIL:", issue)
    if failures:
        return 1
    print("PASS: gameplay core files present; zero bundled art image resources.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
