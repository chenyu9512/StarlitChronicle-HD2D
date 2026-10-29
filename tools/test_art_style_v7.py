#!/usr/bin/env python3
"""Offline geometry/determinism regression for art_style_v7 candidates."""
from __future__ import annotations
import hashlib
import unittest
from PIL import Image, ImageDraw
from art_style_v6 import draw_prop as previous_prop, enemy_sheet as previous_enemy
from art_style_v7 import (terrain_cell, character_sheet, draw_prop,
                          enemy_sheet, landscape, normal_map)

COAST={"id":"region_coast","style":{"palette":["#83B9C4","#D7C59D","#386A82"]}}
FORGE={"id":"region_forge","style":{"palette":["#BA603C","#403C46","#F3B86B"]}}


class V7QualityTests(unittest.TestCase):
    def test_material_variants_have_seamless_outer_ring(self):
        kinds=("grass","sand","road","wood","stone","cobbles","water","wall")
        img=Image.new('RGBA',(256,256))
        d=ImageDraw.Draw(img)
        for row,kind in enumerate(kinds):
            for col in range(8):
                terrain_cell(d,col*32,row*32,(122,166,179),kind,1000+row*8+col)
        for row in range(8):
            base=img.getpixel((0,row*32+1))
            for col in range(8):
                x=32*col;y=32*row
                for offset in range(32):
                    self.assertEqual(img.getpixel((x,y+offset)),base)
                    self.assertEqual(img.getpixel((x+31,y+offset)),base)
                    self.assertEqual(img.getpixel((x+offset,y)),base)
                    self.assertEqual(img.getpixel((x+offset,y+31)),base)
        for row in range(8):
            self.assertGreaterEqual(len({img.crop((col*32,row*32,(col+1)*32,(row+1)*32)).tobytes()
                                         for col in range(8)}),7)

    def test_walker_four_directions_three_gaits_and_alpha(self):
        im=character_sheet('char_wayfarer',COAST)
        self.assertEqual(im.size,(96,192))
        self.assertEqual(im.getpixel((0,0))[3],0)
        for direction in range(4):
            frames=[im.crop((f*32,direction*48,(f+1)*32,(direction+1)*48)) for f in range(3)]
            self.assertEqual(len({f.tobytes() for f in frames}),3)
            self.assertTrue(all(f.getchannel('A').getbbox() is not None for f in frames))
        directions={im.crop((32,i*48,64,(i+1)*48)).tobytes() for i in range(4)}
        self.assertEqual(len(directions),4)

    def test_class_identity_and_region_changes_silhouette(self):
        names=('char_wayfarer','char_tidecaller','char_leiso','char_tifa')
        assets=[character_sheet(n,COAST).tobytes() for n in names]
        self.assertEqual(len(set(assets)),len(names))
        self.assertNotEqual(character_sheet('char_wayfarer',COAST).tobytes(),
                            character_sheet('char_wayfarer',FORGE).tobytes())

    def test_boss_four_frames_and_canonical_identity(self):
        parasite=enemy_sheet('boss_ch002',COAST,True)
        sentinel=enemy_sheet('boss_ch003',COAST,True)
        self.assertEqual(parasite.size,(512,128))
        self.assertNotEqual(parasite.tobytes(),sentinel.tobytes())
        for im in (parasite,sentinel):
            cells=[im.crop((i*128,0,(i+1)*128,128)) for i in range(4)]
            self.assertEqual(len({f.tobytes() for f in cells}),4)
            self.assertTrue(all(f.getchannel('A').getbbox() is not None for f in cells))
            self.assertTrue(all(f.getpixel((0,0))[3]==0 for f in cells))

    def test_props_finer_than_previous_at_equal_export_size(self):
        for kind in ('cottage','tree','shop','well'):
            old=previous_prop(COAST,kind)
            new=draw_prop(COAST,kind)
            self.assertEqual(new.size,(96,128))
            self.assertEqual(new.getpixel((0,0))[3],0)
            # A narrow mechanical proxy: distinct opaque RGB colors, not artistic approval.
            def colors(im):
                return len(set((r,g,b) for r,g,b,a in im.get_flattened_data() if a>=200))
            self.assertGreater(colors(new),colors(old),(kind,colors(old),colors(new)))

    def test_normal_map_preserves_alpha(self):
        for im in (draw_prop(COAST,'cottage'),character_sheet('char_wayfarer',COAST),
                   enemy_sheet('boss_ch002',COAST,True)):
            baked=normal_map(im)
            self.assertEqual(baked.size,im.size)
            self.assertEqual(baked.getchannel('A').tobytes(),im.getchannel('A').tobytes())
            self.assertEqual(baked.getpixel((0,0)),(128,128,255,0))

    def test_landscape_determinism_and_size(self):
        scene={'id':'map_coast_01','type':'town'}
        im=landscape(scene,COAST)
        self.assertEqual(im.size,(1152,648))
        self.assertEqual(im.mode,'RGB')
        self.assertEqual(hashlib.sha256(im.tobytes()).digest(),
                         hashlib.sha256(landscape(scene,COAST).tobytes()).digest())
        self.assertNotEqual(im.tobytes(),landscape({'id':'map_coast_02','type':'field'},COAST).tobytes())

    def test_repeatable_seeded_outputs(self):
        for name,render in [('cottage',lambda:draw_prop(COAST,'cottage')),
                            ('walker',lambda:character_sheet('char_wayfarer',COAST)),
                            ('boss',lambda:enemy_sheet('boss_ch002',COAST,True))]:
            self.assertEqual(render().tobytes(),render().tobytes(),name)

if __name__=='__main__':
    unittest.main(verbosity=2)