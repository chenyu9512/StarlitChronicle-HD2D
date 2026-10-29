#!/usr/bin/env python3
"""Offline regression tests for the global art factory V3."""
import json
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from global_art_factory_v3 import SCOPES, produce, plans, verify

class ArtFactoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "project"
        self.out = Path(self.tmp.name) / "generated"
        for dirname in ("data/content", "data/assets", "data/levels/v4/interiors"):
            (self.root / dirname).mkdir(parents=True, exist_ok=True)
        regions = [
            {"id": "region_"+name, "style": {"palette": ["#83B9C4", "#D7C59D", "#386A82"]}}
            for name in ("coast","oaths","forge","isles","mirror","oldland","sanctum","city")
        ]
        index = [item["id"] for item in regions]
        av = {
            "regions": regions,
            "characters": [{"id": "char_"+str(i)} for i in range(12)],
            "npcs": [{"id": "npc_"+str(i), "region_id": index[i%8]} for i in range(35)],
            "monsters": [{"id": "mon_"+str(i), "region_id": index[i%8]} for i in range(63)],
            "bosses": [{"id": "boss_"+str(i), "act": i%12+1} for i in range(66)],
        }
        maps = [{"id": "map_"+str(i), "region_id": index[i%8],
                 "type": "town" if i%4==0 else "field"} for i in range(42)]
        (self.root/"data/assets/av_registry.json").write_text(json.dumps(av),encoding="utf-8")
        (self.root/"data/content/maps.json").write_text(json.dumps({"entries":maps}),encoding="utf-8")
        for i in range(99):
            room={"map_id":"map_"+str(i%42),"building_id":"room_"+str(i)}
            (self.root/f"data/levels/v4/interiors/map_{i%42}__room_{i}.json").write_text(
                json.dumps(room), encoding="utf-8")

    def test_full_game_inventory(self):
        report=produce(self.root,self.out,set(SCOPES),dry_run=True)
        self.assertEqual(report["counts"],{
            "terrain":8,"ui":8,"props":64,"maps":42,"interiors":99,
            "characters":12,"npcs":35,"monsters":63,"bosses":66})
        self.assertFalse(self.out.exists())

    def test_batch_renders_with_manifest_and_hashes(self):
        report=produce(self.root,self.out,set(SCOPES),limit=25)
        self.assertFalse(report["errors"], report["errors"])
        self.assertEqual(len(report["assets"]),25)
        self.assertTrue((self.out/"candidate_index.json").is_file())
        for asset in report["assets"]:
            png=self.out/asset["path"]
            self.assertTrue(png.is_file())
            self.assertEqual(verify(png,asset["group"])["sha256"],asset["sha256"])
        cached=produce(self.root,self.out,set(SCOPES),limit=25)
        self.assertFalse(cached["errors"])
        self.assertEqual(sum(a["provenance"]=="existing_candidate" for a in cached["assets"]),25)

    def test_each_category_renders(self):
        for scope in SCOPES:
            folder=self.out/scope
            report=produce(self.root,folder,{scope},limit=1)
            self.assertFalse(report["errors"], (scope,report["errors"]))
            self.assertEqual(report["counts"],{scope:1})
            self.assertEqual(len(report["assets"]),1)

    def test_sources_are_exact_size_and_do_not_modify_runtime(self):
        source=Path(self.tmp.name)/"source"
        (source/"terrain").mkdir(parents=True)
        imported=source/"terrain/region_coast.png"
        Image.new("RGBA",(256,256),(55,66,77,255)).save(imported)
        report=produce(self.root,self.out,{"terrain"},limit=1,source_root=source)
        self.assertEqual(report["assets"][0]["provenance"],"imported_exact_size_candidate")
        self.assertFalse(report["game_runtime_modified"])
        Image.new("RGBA",(64,64),(0,0,0,0)).save(imported)
        report=produce(self.root,self.out,{"terrain"},limit=1,source_root=source,force=True)
        self.assertEqual(len(report["errors"]),1)
        self.assertEqual(report["status"],"candidates_partial_errors")

    def test_invalid_canonical_id_is_rejected(self):
        src=self.root/"data/content/maps.json"
        obj=json.loads(src.read_text())
        obj["entries"][0]["id"]="../../outside"
        src.write_text(json.dumps(obj))
        with self.assertRaises(ValueError):
            plans(self.root,{"maps"})

if __name__=="__main__":
    unittest.main()
