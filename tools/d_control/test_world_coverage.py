"""Fixture tests for D 40-map/66-door/40-NPC static inventory (Python stdlib)."""
import json
import tempfile
from pathlib import Path
import unittest
from audit_world_interactions import audit


class WorldCoverageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.write("data/levels/world_atlas_v2.json", self.atlas())
        self.write("data/levels/world_levels_v3.json",
                   {"levels": {f"m{i:02}": {"size": [72,48]} for i in range(40)}})
        self.write("data/content/maps.json", {"entries": [
            {"id": f"m{i:02}", "type": "town" if i<11 else "field"} for i in range(40)]})
        self.write("data/levels/town_director_v4.json",
                   {"towns": {f"m{i:02}": {} for i in range(11)}})
        self.write("data/content/npcs.json", {"entries": self.npc_rows()})
        (self.root/"data/levels/v4/interiors").mkdir(parents=True, exist_ok=True)

    def write(self, name, value):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")

    def atlas(self):
        zones = []
        for i in range(40):
            neighbors = [f"m{(i+1)%40:02}", f"m{(i-1)%40:02}"]
            buildings = [{"id":f"b{k}","kind":"house","door":[10+k,12]} for k in range(6)] if i<11 else []
            zones.append({"id":f"m{i:02}","neighbors":neighbors,"buildings":buildings,
                          "settlement":i<11})
        return {"zones":zones,"regions":[{"id":"r1"}]}

    def npc_rows(self):
        day = [(0,5),(5,8),(8,13),(13,19),(19,24)]
        return [{"id":f"npc{i:02}","region_id":"r1",
                 "daily_routine":[{"id":str(k),"start":a,"end":b} for k,(a,b) in enumerate(day)]}
                for i in range(40)]

    def test_complete_fixture(self):
        d = audit(self.root)
        self.assertEqual(d["status"],"STATIC_PASS_RUNTIME_UNVERIFIED",d["errors"])
        self.assertEqual(d["counts"]["buildings"],66)
        self.assertEqual(d["counts"]["graph_components"],1)

    def test_missing_return_gate(self):
        v = self.atlas()
        v["zones"][1]["neighbors"].remove("m00")
        self.write("data/levels/world_atlas_v2.json",v)
        self.assertIn("reverse gate absent"," ".join(audit(self.root)["errors"]))

    def test_invalid_door(self):
        v = self.atlas()
        v["zones"][0]["buildings"][0]["door"] = [-4,20]
        self.write("data/levels/world_atlas_v2.json",v)
        self.assertIn("invalid door"," ".join(audit(self.root)["errors"]))

    def test_schedule_overlap(self):
        v=self.npc_rows()
        v[0]["daily_routine"][0]["end"] = 6
        self.write("data/content/npcs.json", {"entries":v})
        self.assertIn("overlapping"," ".join(audit(self.root)["errors"]))

    def test_disconnected_graph_is_warning_not_fake_success(self):
        v=self.atlas()
        for i in range(40):
            a=0 if i<35 else 35
            n=35 if i<35 else 5
            j=i-a
            v["zones"][i]["neighbors"]=[f"m{a+(j+1)%n:02}",f"m{a+(j-1)%n:02}"]
        self.write("data/levels/world_atlas_v2.json",v)
        report=audit(self.root)
        self.assertEqual(report["status"],"STATIC_PASS_RUNTIME_UNVERIFIED")
        self.assertEqual(report["counts"]["graph_components"],2)
        self.assertIn("disconnected"," ".join(report["warnings"]))


if __name__ == "__main__":
    unittest.main()
