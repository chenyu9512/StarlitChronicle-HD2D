#!/usr/bin/env python3
"""Reject reintroducing pseudo-random material atlas remapping."""
from pathlib import Path
src=(Path(__file__).resolve().parent.parent/"scripts/third_party_terrain_adapter.gd").read_text(encoding="utf-8")
body=src.split("static func assemble(",1)[1].split("## Five region-local marks",1)[0]
assert "_tile_candidates" not in body, "Random source tile candidate selection reintroduced"
assert "posmod" not in body, "Hashed source tile remapping reintroduced"
assert "Vector2i(column*edge,row*edge)" in body, "Ordered atlas cell preservation missing"
print("PASS: legacy atlas source cell order preserved; no pseudo-random world tile assembly")
