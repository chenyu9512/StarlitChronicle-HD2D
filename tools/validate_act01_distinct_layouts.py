#!/usr/bin/env python3
"""Act-I visual-geography contract: five playable maps / six distinct places.

This gate checks AUTHORITATIVE V3/V4 live data, not marketing screenshots or a
hand-maintained mockup. Godot's physical paths are tested by the companion smoke.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDS = [f"map_coast_0{n}" for n in range(1, 6)]
def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

levels = {key: read(f"data/levels/v3/{key}.json") for key in IDS}
scenery = read("data/levels/v4/coastal_scenery.json")
towns = read("data/levels/town_director_v4.json")["towns"]
atlas = {item["id"]: item for item in read("data/levels/world_atlas_v2.json")["zones"]}
contract = read("data/levels/act01_scene_locations_v1.json")["chapters"]
problems = []
def need(test, reason):
    if not test:
        problems.append(reason)

need(len(atlas) == 42, "forty-two map identities and all old saves retained")
need([c["required_map_id"] for c in contract] == [
    "map_coast_01", "map_coast_02", "map_coast_04", "map_coast_02",
    "map_coast_03", "map_coast_05"], "do not reorder six canon story destinations")
need(len(set(levels[k].get("layout_identity", "") for k in IDS)) == 5,
     "five different production layout identities")
unique_roads = set()
for key in IDS:
    spec = levels[key]
    w, h = spec["size"]
    need(spec["map_id"] == key and spec["schema_version"] == 3,
         key + ": valid live map ID and V3 schema")
    need(len(spec.get("roads", [])) >= 5, key + ": missing authored distinct route network")
    sig = tuple(tuple(tuple(p) for p in r["points"]) for r in spec["roads"])
    need(sig not in unique_roads, key + ": copied road geometry")
    unique_roads.add(sig)
    for road in spec["roads"]:
        need(len(road["points"]) > 1, key + ": route has no traversal")
        for x, y in road["points"]:
            need(2 <= x < w - 2 and 2 <= y < h - 2, key + ": authored road outside grid")
    for region in spec["clearings"]:
        x, y = region["center"]
        need(2 <= x < w-2 and 2 <= y < h-2, key + ": off-map story floor")
    names = [entry["id"] for entry in scenery[key]["scenery"]]
    need(len(names) >= 12 and len(names) == len(set(names)),
         key + ": distinct real art placements required")
    need(len(spec["landmarks"]) >= 3, key + ": no recognizable bespoke landmarks")
    need(spec["revision"] >= 7, key + ": old generic V3 composition still active")

need(towns["map_coast_01"]["urban_form"] == "林荫环村",
     "Morning Dew must render a circular village plaza")
need(atlas["map_coast_01"]["layout"] == "central_square" and
     atlas["map_coast_01"].get("village_shape") == "dew_village_ring",
     "Dew Village must use its authored ring instead of generic crossroads")
need(towns["map_coast_01"]["focal_point"] == [35,21],
     "Dew Village world center must remain at the actual well")
need(towns["map_coast_02"]["urban_form"] == "堤岸栈桥港",
     "White Sand must render an elongated quay rather than the village circle")
need([x["id"] for x in levels["map_coast_01"]["roads"]].count(
    "dew-circular-well-plaza") == 1, "village well must own its circular lane")
need(sum("pier" in r["id"] for r in levels["map_coast_02"]["roads"]) >= 2,
     "harbor has two independently authored playable dock spurs")
need(any("switchbacks" in x["id"] for x in levels["map_coast_03"]["roads"]),
     "saltwind must genuinely switchback rather than use urban grid")
need(any("ring" in x["id"] for x in levels["map_coast_04"]["roads"]),
     "cave lacks its two interconnected route loops")
need(any("spiral" in x["id"] for x in levels["map_coast_05"]["roads"]),
     "lighthouse has no ascending spiral approach")
need({tuple(x["center"]) for x in levels["map_coast_03"]["clearings"]}.issuperset(
    {(62, 43), (66, 45)}), "whale shoal rescue has no unchanged accessible anchor")
need({tuple(x["center"]) for x in levels["map_coast_05"]["clearings"]}.issuperset(
    {(80, 29), (74, 35)}), "lighthouse repair and mirror platforms moved")
need(atlas["map_coast_03"]["neighbors"] == ["map_coast_02", "map_coast_04"],
     "whale shoal may not create a map or shortcut around cave")
need("map_coast_06" not in atlas, "sixth story place is a subzone not a fake world map")

print(f"Act-I different layouts: five world sectors, six chapter places, "
      f"{sum(len(x['roads']) for x in levels.values())} authored roads, "
      f"{sum(len(scenery[k]['scenery']) for k in IDS)} live art placements, "
      f"errors={len(problems)}")
for issue in problems:
    print("FAIL:", issue)
if problems:
    raise SystemExit(1)
print("PASS: six intentional compositions, original story route locks and live art IDs.")
