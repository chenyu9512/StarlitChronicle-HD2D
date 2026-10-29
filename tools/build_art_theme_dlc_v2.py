#!/usr/bin/env python3
"""Build exact-coverage DLC manifest from image files named <semantic-id>.png.

No guessing, no icon-to-building substitutions; report all missing semantic IDs.
Run after converting each output image to the canonical slot dimensions.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACCEPTED = (".png",".jpg",".jpeg",".webp")

def build(directory: Path, pack_id: str, name: str) -> dict:
    if not directory.is_dir():
        raise SystemExit("Input folder does not exist")
    if not pack_id or len(pack_id)>42 or any(c.lower() not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in pack_id):
        raise SystemExit("Unsafe pack id")
    raw=json.loads((ROOT/"data/assets/art_theme_v2.json").read_text(encoding="utf-8"))
    official=next(t for t in raw["themes"] if t["id"]=="starlit_hd2d_act01")
    mappings=[]
    missing=[]
    for slot in sorted(official["slots"]):
        matches=[slot+ext for ext in ACCEPTED if (directory/(slot+ext)).is_file()]
        if len(matches)!=1:
            missing.append(slot)
        else:
            mappings.append({"slot":slot,"file":matches[0]})
    if missing:
        preview="\n".join(missing[:30])
        raise SystemExit(f"Full V2 theme rejected: {len(missing)} missing/ambiguous slots.\n{preview}")
    output={"schema":"starlit.art_theme.dlc.v2","id":pack_id,"name":name,
            "mappings":mappings,"note":"After install, Godot validates dimensions, then visual QA separately."}
    (directory/"art_theme.json").write_text(json.dumps(output,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return output

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("directory",type=Path)
    p.add_argument("--id",required=True)
    p.add_argument("--name",required=True)
    args=p.parse_args()
    data=build(args.directory.resolve(),args.id,args.name)
    print(f"PASS: {len(data['mappings'])} explicit semantic mappings -> {args.directory}/art_theme.json")
