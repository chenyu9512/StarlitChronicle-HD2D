#!/usr/bin/env python3
"""Main2 engine-facing image custody check, deliberately NOT commercial art QA.

The legacy 55 original coast-v2 masters/export PNGs were retired by the chosen
third-party-only branch migration. Validate the physical replacements actually
referenced by all 89 logical art IDs, without claiming pixel-perfect parity,
correct NPC identity, animation frames or HD-2D visual sign-off.

Strict commercial gate remains tools/qa_hd2d_refinement.py and intentionally
cannot pass merely because a third-party PNG is loadable.
"""
import json
from pathlib import Path
from PIL import Image
from art_source_contract import resolve

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/"assets/art/art_manifest.json").read_text(encoding="utf8"))
records=manifest["assets"]
assert len(records)==89,("logical-master-count",len(records))
refined=[row for row in records if row.get("refinement_version")=="coast-v2"]
assert len(refined)==55,("historic-refined-count",len(refined))
batches={}
physical_paths=set()
redirected=0
for entry in records:
    name=entry["path"]
    assert name.startswith("assets/art/") and ".." not in Path(name).parts,name
    master=resolve(name)
    image_name=str(Path(name).with_suffix(".png"))
    physical=resolve(image_name)
    for item in (master,physical):
        assert item.is_file() and item.stat().st_size>0,(name,str(item))
    with Image.open(physical) as art:
        art.verify()
    with Image.open(physical) as art:
        w,h=art.size
        assert w>=16 and h>=16,(image_name,w,h)
    physical_paths.add(physical.relative_to(ROOT).as_posix())
    redirected+=int(physical != ROOT/image_name)
    if entry in refined:
        batches[entry["batch"]]=batches.get(entry["batch"],0)+1
assert batches=={2:28,3:27},("historic-batch-reference",batches)
print("PASS Main2 IMAGE SOURCE INTEGRITY: %d legacy art IDs checked, %d prior coast-v2 IDs," %
      (len(records),len(refined)))
print("  %d real image sources resolved; %d retired PNG slots mapped to third-party images" %
      (len(physical_paths),redirected))
print("  NOT COMMERCIAL ACCEPTANCE: legacy atlases/4-frame motion/scene colors/visual meaning require independent real-engine screenshot and animation QA")
