#!/usr/bin/env python3
"""Read-only V10 ceiling audit: no image regeneration, deletion or promotion."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys

CORE = ("terrain","maps","interiors","props","characters","npcs","monsters","bosses","ui")
def read(path):
    with path.open(encoding="utf-8-sig") as f:
        return json.load(f)
def audit(root: Path) -> dict:
    ceiling = read(root/"data/assets/hd2d_v10_final_ceiling.json")
    av = read(root/"data/assets/av_registry.json")
    maps = read(root/"data/content/maps.json")["entries"]
    rooms = list((root/"data/levels/v4/interiors").glob("*.json"))
    counts = {
        "terrain":len(av["regions"]),"maps":len(maps),"interiors":len(rooms),
        "props":len(av["regions"])*8,"characters":len(av["characters"]),
        "npcs":len(av["npcs"]),"monsters":len(av["monsters"]),
        "bosses":len(av["bosses"]),"ui":len(av["regions"]),
    }
    if set(counts) != set(CORE):
        raise ValueError("Unexpected V10 group keys")
    errors = []
    for group,n in ceiling["core_groups"].items():
        if counts[group]!=n:
            errors.append(f"Canonical {group}: {counts[group]} != V10 baseline {n}")
    expected_total = sum(counts.values())
    if expected_total != 451:
        errors.append(f"Canonical core total changed to {expected_total}; review version ceiling")
    src = root/"assets/art/runtime/global_factory_v3/active.json"
    if src.is_file():
        m = read(src)
        if m.get("asset_count") != expected_total or len(m.get("assets",{})) != expected_total:
            errors.append("Active art manifest does not have complete canonical core coverage")
        if m.get("counts") != counts:
            errors.append("Active art manifest count distribution differs from canonical records")
        source=m.get("source","")
        state=m.get("visual_acceptance","not_tested")
        model_checked = "model" in str(source).lower()
    else:
        errors.append("Active runtime manifest missing")
        source=""
        state="not_tested"
        model_checked=False
    supp=ceiling["supplementary_contracts"]
    def count_manifest(path, field):
        try:
            return int(read(root/path).get(field,-1))
        except (OSError,ValueError,TypeError,KeyError):
            return -1
    supplemental={
        "content_icons":count_manifest(Path("assets/art/runtime/content_icons_v1/manifest.json"),"count"),
        "boss_action_sheets":count_manifest(Path("assets/art/runtime/boss_motion_v1/manifest.json"),"count"),
        "shore_wave_sheets":count_manifest(Path("assets/art/runtime/shore_waves_v1/manifest.json"),"count"),
        "historical_canonical_slots":len(read(root/"data/assets/c_art_runtime_registry_v1.json").get("canonical_slots",{})),
    }
    for k,v in supplemental.items():
        if v != supp[k]:
            errors.append(f"Supplemental {k}: {v} != {supp[k]}")
    approvals_confirmed=False
    # There is no complete, independently verified per-asset identity+visual
    # approval dataset in the active V3 manifest. Never auto-pass this gate.
    release_ready = (not errors and approvals_confirmed)
    return {
        "schema":ceiling["schema"],"core_counts":counts,"total_core":expected_total,
        "supplemental":supplemental,"active_source":source,
        "active_visual_acceptance":state,"model_source_named":model_checked,
        "machine_coverage_status":"成功" if not errors else "未通过",
        "commercial_visual_qa":"未测试",
        "commercial_release_ready":release_ready,
        "errors":errors,
        "note":"Read-only structural audit. Visual and Godot real-scene approval must be independently completed.",
    }
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    args=p.parse_args()
    try:
        result=audit(args.project.resolve())
    except (OSError,ValueError,TypeError,KeyError) as exc:
        print(json.dumps({"status":"未通过","error":str(exc)},ensure_ascii=False,indent=2))
        return 2
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 1 if result["errors"] else 0
if __name__=="__main__":
    sys.exit(main())
