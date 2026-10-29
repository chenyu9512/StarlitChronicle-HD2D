#!/usr/bin/env python3
"""Offline regression tests for the global art factory V3."""
import json
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from global_art_factory_v3 import SCOPES, produce, tasks as plans, verify, atlas, walker
from global_art_ai_provider_v3 import (build_jobs, fit, quality_metrics, fingerprint,
                                      SOURCE_SIZES, PIPELINE_REV)

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

    def test_all_eight_biomes_use_semantic_material_colors(self):
        from global_art_factory_v3 import TERRAIN_ROLE_COLORS
        regions=("coast","oaths","forge","isles","mirror","oldland","sanctum","city")
        self.assertEqual(set(TERRAIN_ROLE_COLORS),{"region_"+name for name in regions})
        coast={"id":"region_coast","style":{"palette":["#83B9C4","#D7C59D","#386A82"]}}
        sample=atlas(coast)
        grass=sample.getpixel((1,32+1))
        sand=sample.getpixel((1,5*32+1))
        water=sample.getpixel((1,6*32+1))
        # Sea cyan cannot replace grass; warm coastal sand must remain
        # distinct from water even when the style's primary mood color is blue.
        self.assertGreater(grass[1],grass[2], grass)
        self.assertGreater(sand[0],sand[2], sand)
        self.assertGreater(water[2],water[0], water)

    def test_v5_ground_materials_have_no_bright_column_boundaries(self):
        region={"id":"region_coast","style":{"palette":["#83B9C4","#D7C59D","#386A82"]}}
        image=atlas(region)
        self.assertEqual(image.size,(256,256))
        # Flat edges on all 8 variants of one material row prevent
        # visible vertical 32px checkerboard seams when the TileSet repeats.
        for row in range(8):
            reference=image.getpixel((0,row*32+1))
            for col in range(8):
                self.assertEqual(image.getpixel((col*32,row*32+1)),reference)
                self.assertEqual(image.getpixel((col*32+31,row*32+1)),reference)
        variants=[image.crop((col*32,0,(col+1)*32,32)).tobytes()
                  for col in range(8)]
        self.assertGreaterEqual(len(set(variants)),7)

    def test_v5_walker_has_three_poses_and_four_directions(self):
        region={"id":"region_coast","style":{"palette":["#83B9C4","#D7C59D","#386A82"]}}
        image=walker("char_wayfarer",region)
        self.assertEqual(image.size,(96,192))
        for row in range(4):
            frames=[image.crop((col*32,row*48,(col+1)*32,(row+1)*48)).tobytes()
                    for col in range(3)]
            self.assertGreaterEqual(len(set(frames)),2)
            for col in range(3):
                frame=image.crop((col*32,row*48,(col+1)*32,(row+1)*48))
                alpha=frame.getchannel("A")
                self.assertIsNotNone(alpha.getbbox())
                self.assertEqual(frame.getpixel((0,0))[3],0)
        fronts=[image.crop((32,row*48,64,(row+1)*48)).tobytes() for row in range(4)]
        self.assertEqual(len(set(fronts)),4)

    def test_full_game_inventory(self):
        report=produce(self.root,self.out,set(SCOPES),dry_run=True)
        self.assertEqual(report["counts"],{
            "terrain":8,"ui":8,"props":64,"maps":42,"interiors":99,
            "characters":12,"npcs":35,"monsters":63,"bosses":66})
        self.assertFalse(self.out.exists())

    def test_153_interior_growth_updates_all_factory_jobs(self):
        # Keep fixture independent of the current project's room count.
        # The factory must discover new V4 interiors without hardcoded totals.
        for i in range(99, 153):
            room = {"map_id": "map_" + str(i % 42),
                    "building_id": "room_" + str(i)}
            path = self.root / f"data/levels/v4/interiors/map_{i%42}__room_{i}.json"
            path.write_text(json.dumps(room), encoding="utf-8")
        report = produce(self.root, self.out, set(SCOPES), dry_run=True)
        self.assertEqual(report["counts"]["interiors"], 153)
        self.assertEqual(sum(report["counts"].values()), 451)
        jobs = build_jobs(self.root, set(SCOPES))
        self.assertEqual(len(jobs), 451)
        self.assertEqual(len({(job["group"], job["id"]) for job in jobs}), 451)

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

    def test_high_detail_prompt_jobs_cover_registry(self):
        jobs=build_jobs(self.root,set(SCOPES))
        self.assertEqual(len(jobs),397)
        self.assertEqual(len({(j["group"],j["id"]) for j in jobs}),397)
        self.assertTrue(all("high-quality art" in j["prompt"].lower() for j in jobs))
        self.assertTrue(all(j["qa"]=="candidate_identity_and_animation_review_required" for j in jobs))

    def test_model_image_adapter_keeps_aspect_ratio(self):
        import io
        source=Image.new("RGBA",(512,512),(255,0,0,255))
        buf=io.BytesIO()
        source.save(buf,format="PNG")
        output=fit(buf.getvalue(),(96,192),True)
        self.assertEqual(output.size,(96,192))
        self.assertEqual(output.getpixel((0,0))[3],0)
        self.assertEqual(output.getpixel((40,80))[3],255)

    def test_model_render_specs_follow_asset_layout(self):
        jobs=build_jobs(self.root,set(SCOPES))
        self.assertTrue(PIPELINE_REV.startswith("quality-v4"))
        self.assertEqual(len(jobs),397)
        for job in jobs:
            self.assertEqual(job["source_size"],SOURCE_SIZES[job["group"]])
            self.assertIn("high-quality art",job["prompt"])
        self.assertEqual(next(j for j in jobs if j["group"]=="characters")["source_size"],
                         "1024x2048")
        self.assertEqual(next(j for j in jobs if j["group"]=="bosses")["frame_grid"],[1,4])

    def test_render_cache_fingerprint_tracks_prompt_model_quality(self):
        job=build_jobs(self.root,{"bosses"},limit=1)[0]
        old=fingerprint(job,"gpt-image-2.5-sunburst","xhigh")
        self.assertNotEqual(old,fingerprint(job,"gpt-image-2.5-sunburst","max"))
        self.assertNotEqual(old,fingerprint(job,"gpt-image-2.5-flare","xhigh"))
        self.assertNotEqual(old,fingerprint(job,"gpt-image-2.5-sunburst","xhigh",
                                             reference_sha="abc123"))
        modified={**job,"prompt":job["prompt"]+" unique markings"}
        self.assertNotEqual(old,fingerprint(modified,"gpt-image-2.5-sunburst","xhigh"))

    def test_quality_gate_rejects_opaque_sprites_and_flat_images(self):
        opaque=Image.new("RGBA",(96,192),(45,120,190,255))
        with self.assertRaisesRegex(ValueError,"MISSING_TRUE_TRANSPARENT"):
            quality_metrics(opaque,"characters")
        blank=Image.new("RGBA",(1152,648),(15,16,17,255))
        with self.assertRaisesRegex(ValueError,"LOW_DETAIL"):
            quality_metrics(blank,"maps")

    def test_quality_gate_rejects_empty_animation_cell(self):
        from PIL import ImageDraw
        sprite=Image.new("RGBA",(96,192),(0,0,0,0))
        d=ImageDraw.Draw(sprite)
        for row in range(4):
            for col in range(3):
                if (row,col)==(3,2):
                    continue
                x,y=col*32,row*48
                d.rectangle((x+6,y+9,x+25,y+40),
                            fill=(25+row*40,60+col*65,180-row*20,255))
        with self.assertRaisesRegex(ValueError,"EMPTY_SHEET_CELL_3_2"):
            quality_metrics(sprite,"characters")

    def test_model_sheet_cropping_preserves_cells_and_alpha(self):
        import io
        from PIL import ImageDraw
        master=Image.new("RGBA",(1536,512),(0,0,0,0))
        d=ImageDraw.Draw(master)
        palette=[(240,50,50,255),(50,220,50,255),(50,50,240,255),(230,200,50,255)]
        for i,color in enumerate(palette):
            d.rectangle((i*384+20,90,(i+1)*384-21,421),fill=color)
        raw=io.BytesIO()
        master.save(raw,format="PNG")
        fitted=fit(raw.getvalue(),(512,128),True,"bosses")
        self.assertEqual(fitted.size,(512,128))
        self.assertEqual(fitted.getpixel((0,0))[3],0)
        for i,color in enumerate(palette):
            found=fitted.getpixel((i*128+64,64))
            self.assertEqual(found,color)

    def test_v4_normals_and_legacy_svg_candidates(self):
        import xml.etree.ElementTree as ET
        report=produce(self.root,self.out,{"terrain","ui"},limit=2)
        self.assertFalse(report["errors"],report["errors"])
        self.assertEqual(report["version"],"4.0.0")
        self.assertEqual(report["normal_map_count"],1)
        self.assertEqual(len(report["auxiliary_svg_paths"]),12)
        for svg in report["auxiliary_svg_paths"]:
            ET.parse(self.out/svg)
        terrain=next(x for x in report["assets"] if x["group"]=="terrain")
        with Image.open(self.out/terrain["path"]) as color, Image.open(self.out/terrain["normal_map_path"]) as normal:
            self.assertEqual(color.size,normal.size)
            self.assertEqual(color.getchannel("A").tobytes(),normal.getchannel("A").tobytes())
        second=produce(self.root,self.out,{"terrain","ui"},limit=2)
        self.assertFalse(second["errors"])
        self.assertEqual(second["normal_map_count"],0)
        self.assertEqual(len(second["auxiliary_svg_paths"]),12)

    def test_v4_rerenders_v3_cached_candidates(self):
        old=self.out/"terrain/region_coast.png"
        old.parent.mkdir(parents=True,exist_ok=True)
        Image.new("RGBA",(256,256),(10,20,30,255)).save(old)
        (self.out/"candidate_manifest.json").write_text('{"version":"3.1.0"}')
        report=produce(self.root,self.out,{"terrain"},limit=1)
        self.assertFalse(report["errors"],report["errors"])
        self.assertEqual(report["assets"][0]["provenance"],"generated_procedural_candidate")
        self.assertNotEqual(Image.open(old).getpixel((7,7)),(10,20,30,255))

    def test_invalid_canonical_id_is_rejected(self):
        src=self.root/"data/content/maps.json"
        obj=json.loads(src.read_text())
        obj["entries"][0]["id"]="../../outside"
        src.write_text(json.dumps(obj))
        with self.assertRaises(ValueError):
            plans(self.root,{"maps"})

if __name__=="__main__":
    unittest.main()
