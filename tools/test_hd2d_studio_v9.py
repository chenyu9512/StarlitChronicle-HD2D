#!/usr/bin/env python3
"""V9 isolated tests. Fixture is synthetic, never presented as current Main2."""
import json
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from hd2d_studio_v8 import CAST_ROLES
from hd2d_studio_v9 import (data_index,make_pack,verify_pack,promote,rollback,
                             material_atlas,prop_image,npc_sheet,ui_frame,model_candidate)

PALETTES=['#83B9C4','#D7C59D','#386A82']

class V9Tests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)/'game';self.output=self.root/'build/v9/factory'
        (self.root/'data/assets').mkdir(parents=True)
        (self.root/'data/content').mkdir(parents=True)
        (self.root/'data/levels/v4/interiors').mkdir(parents=True)
        region={'id':'region_coast','name':'白砂海岸','style':{'palette':PALETTES,'motif':'潮雾和盐岩'}}
        self.region=region
        av={'regions':[region], 'characters':[{'id':'char_wayfarer','name':'黎昂'}],
            'npcs':[{'id':'npc_coast_01','name':'港口船长','region_id':'region_coast'}],
            'monsters':[{'id':'mon_coast_02','name':'雾壳蟹','region_id':'region_coast'}],
            'bosses':[{'id':'boss_ch002','name':'雾潮寄生体'}]}
        (self.root/'data/assets/av_registry.json').write_text(json.dumps(av),encoding='utf-8')
        maps={'entries':[{'id':'map_coast_01','name':'晨露村','region_id':'region_coast','layout_identity':'coast.01'}]}
        (self.root/'data/content/maps.json').write_text(json.dumps(maps),encoding='utf-8')
        (self.root/'data/levels/v4/interiors/map_coast_01__house.json').write_text(json.dumps({'map_id':'map_coast_01','building_id':'house'}),encoding='utf-8')
        reg={'schema':'starlit.c.art_runtime_registry.v1','generated_assets':{},'regions':{'region_coast':{}}}
        (self.root/'data/assets/c_art_runtime_registry_v1.json').write_text(json.dumps(reg),encoding='utf-8')
    def test_inventory_semantic_counts(self):
        queue,_=data_index(self.root)
        self.assertEqual({k:len(v) for k,v in queue.items()},
            {'terrain':1,'maps':1,'interiors':1,'props':8,'characters':1,'npcs':1,'monsters':1,'bosses':1,'ui':1})
    def test_seams_ground_and_interior(self):
        for inside in (True,False):
            im=material_atlas(self.region,'map_coast_01__house',inside)
            self.assertEqual(im.size,(256,256))
            for row in range(8):
                self.assertEqual(im.getpixel((0,row*32+16)),im.getpixel((31,row*32+16)))
                self.assertEqual(im.getpixel((32,row*32+16)),im.getpixel((63,row*32+16)))
    def test_semantic_images(self):
        a=prop_image(self.region,'tree','region_coast_tree')
        b=prop_image(self.region,'cottage','region_coast_cottage')
        self.assertNotEqual(a.tobytes(),b.tobytes())
        self.assertEqual(ui_frame(self.region).size,(512,128))
        self.assertEqual(npc_sheet({'id':'npc_coast_01','name':'船长'},self.region).size,(96,192))
    def test_atomic_one_click_and_rollback(self):
        import hashlib
        old=self.root/'assets/art/runtime/global_factory_v3'
        old.mkdir(parents=True)
        (old/'legacy').write_text('baseline',encoding='utf-8')
        make_pack(self.root,self.output)
        x=verify_pack(self.output,self.root)
        self.assertEqual(x['slots'],16)
        result=promote(self.root,self.output)
        self.assertEqual(result['core_slots'],16)
        self.assertTrue((old/'active.json').is_file())
        self.assertEqual(len(json.loads((self.root/'data/assets/c_art_runtime_registry_v1.json').read_text())['generated_assets']),18)
        rollback(self.root,result['backup_dir'],result['registry_backup'])
        self.assertEqual((old/'legacy').read_text(),'baseline')
        with self.assertRaises(FileNotFoundError):rollback(self.root,result['backup_dir'])
    def test_integrity_tamper_rejected(self):
        make_pack(self.root,self.output)
        (self.output/'characters/char_wayfarer.png').write_bytes(b'not-image')
        with self.assertRaises(ValueError):verify_pack(self.output,self.root)
    def test_unregistered_leftover_image_is_rejected(self):
        make_pack(self.root,self.output)
        (self.output/'props/obsolete.png').write_bytes(b'leftover')
        with self.assertRaisesRegex(ValueError,'Unexpected leftover PNG'):
            verify_pack(self.output,self.root)

    def test_refined_requires_real_approval(self):
        folder=self.root/'candidate';(folder/'characters').mkdir(parents=True)
        p=folder/'characters/char_wayfarer.png'
        Image.new('RGBA',(96,192),(10,20,30,255)).save(p)
        (folder/'characters/char_wayfarer.quality.json').write_text(json.dumps({'image_sha256':'bad'}))
        with self.assertRaises(ValueError):model_candidate(folder,'characters','char_wayfarer',(96,192))

if __name__=='__main__':unittest.main()
