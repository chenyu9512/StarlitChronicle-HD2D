#!/usr/bin/env python3
"""Audit genuinely imported first-act V18 sprites, semantics, and zero dead art.

Only run in Main2, before Runtime pruning: the slim branch deliberately omits
production source_packs. Git blob identity is independently checked via SHA256.
"""
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path
from act01_source_provenance import verify_art

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = Path("assets/art/runtime/act01_hd2d_v18")
ORIGINAL_PROPS = Path(
    "assets/art/source_packs/Golden-Horizon-2D-01-Sprites-Icons-Effects"
    "/2D/Prepared/Sprites"
)
ORIGINAL_MATERIALS = Path(
    "assets/art/source_packs/Golden-Horizon-2D-02-Environments"
    "/2D/Prepared/Surfaces"
)
ROLE_BY_MAP = {
    "map_coast_01": {"market-stall", "flower-fence", "great-oak", "flower-bench"},
    "map_coast_02": {"crate-stack", "barrel-cache", "market-stall", "flower-bench"},
    "map_coast_03": {"tide-pool-rocks", "barge-wreck", "rock-bank"},
    "map_coast_04": {"crystal-cache", "ruined-arch", "cliff-ledge", "rock-bank"},
    "map_coast_05": {"bench-lantern", "camp-banner"},
}
BAD_ROLES = {"cherry-tree", "cliff-shrine", "rowboat"}
errors = []


def check(ok, message):
    if not ok:
        errors.append(message)


def asset(relative_path, origin):
    """Verify real file bytes and source identity (no placeholder PNGs)."""
    runtime = ROOT / relative_path
    original = ROOT / origin
    try:
        proof = verify_art(relative_path, origin)
    except (ValueError, OSError) as exc:
        check(False, "Source blob mismatch: " + str(exc))
        return
    first = runtime.read_bytes()
    check(first.startswith(b"\x89PNG\r\n\x1a\n"), "Invalid PNG: " + str(relative_path))
    if len(first) >= 24:
        width, height = struct.unpack(">II", first[16:24])
        check(width >= 32 and height >= 32,
              "Unusable miniature asset: " + str(relative_path))
    return hashlib.sha256(first).hexdigest()


def run():
    manifest = json.loads(
        (ROOT / "data/assets/c_act01_hd2d_v18.json").read_text(encoding="utf-8")
    )
    check(manifest.get("schema") == "starlit.c.act01_hd2d_v18",
          "Changed V18 contract schema")
    used = set()
    counts = Counter()
    for row in manifest["placements"]:
        map_id, kind = row["map_id"], row["kind"]
        check(map_id in ROLE_BY_MAP and kind in ROLE_BY_MAP.get(map_id, set()),
              f"Role mismatch: {kind} in {map_id}")
        check(kind not in BAD_ROLES, f"Retired inappropriate art: {kind}")
        check(bool(row.get("visual_only")), "Gameplay-changing prop: " + str(row["id"]))
        check(row["source"] == f"res://{RUNTIME}/props/{kind}.png",
              "Misnamed role/source for " + str(row["id"]))
        xy = row["cell"]
        check(isinstance(xy, list) and len(xy) == 2 and
              all(isinstance(n, int) and 0 <= n < 128 for n in xy),
              "Off-map placement: " + str(row["id"]))
        check(32 <= row.get("max_width", 0) <= 192 and
              32 <= row.get("max_height", 0) <= 210,
              "Unsafe physical PNG footprint: " + str(row["id"]))
        counts[map_id] += 1
        used.add(RUNTIME / "props" / f"{kind}.png")
    check(set(counts) == set(ROLE_BY_MAP) and min(counts.values()) >= 2,
          "Five coast maps need visible, curated art")
    check(any(x["map_id"] == "map_coast_01" and x["kind"] == "great-oak"
              for x in manifest["placements"]), "Canonical village oak missing")
    for key, ref in manifest["materials"].items():
        check(ref == f"res://{RUNTIME}/materials/{key}.png",
              "Material role mismatch: " + key)
        used.add(RUNTIME / "materials" / f"{key}.png")
    check(len(manifest["materials"]) == 11, "11 first-act materials changed")
    existing = {p.relative_to(ROOT) for p in (ROOT / RUNTIME).rglob("*.png")}
    check(used == existing,
          "Dead/missing runtime images: " +
          str(sorted(map(str, used ^ existing))))
    for path in sorted(used):
        kind = path.stem
        source = ORIGINAL_PROPS if path.parent.name == "props" else ORIGINAL_MATERIALS
        asset(path, source / (kind + ".png"))
    if errors:
        for error in errors:
            print("FAIL V18 ART: " + error)
        raise SystemExit(1)
    print(
        f"PASS V18 art provenance: {len(manifest['placements'])} in-game sites; "
        f"{len(ROLE_BY_MAP)} maps; {len(used)} byte-exact source PNGs; "
        "zero unused runtime images or semantic swaps"
    )


if __name__ == "__main__":
    run()
