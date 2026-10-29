#!/usr/bin/env python3
"""Offline V4.2 sprite contract tests; does not claim visual approval."""
import unittest
from PIL import Image, ImageDraw
from art_style_v8 import terrain_cell, character_sheet, enemy_sheet, draw_prop, landscape, normal_map

REGION={"id":"region_coast","style":{"palette":["#83B9C4","#D7C59D","#386A82"]}}

class V8ContractTests(unittest.TestCase):
    def test_tile_seams(self):
        sheet=Image.new("RGB",(256,256))
        d=ImageDraw.Draw(sheet)
        for row,kind in enumerate(("grass","road","stone","wood","cobbles","sand","water","wall")):
            for col in range(8):
                terrain_cell(d,col*32,row*32,(130,164,172),kind,1100+row*8+col)
        for row in range(8):
            for col in range(8):
                x=col*32; y=row*32; expected=(130,164,172)
                for offset in range(32):
                    self.assertEqual(sheet.getpixel((x,y+offset)),expected)
                    self.assertEqual(sheet.getpixel((x+31,y+offset)),expected)
                    self.assertEqual(sheet.getpixel((x+offset,y)),expected)
                    self.assertEqual(sheet.getpixel((x+offset,y+31)),expected)

    def test_four_direction_character(self):
        im=character_sheet("char_wayfarer",REGION)
        self.assertEqual(im.size,(96,192))
        for row in range(4):
            cells=[im.crop((col*32,row*48,(col+1)*32,(row+1)*48)) for col in range(3)]
            self.assertEqual(len(set(c.tobytes() for c in cells)),3)
            self.assertTrue(all(c.getchannel("A").getbbox() for c in cells))
        self.assertEqual(im.getpixel((0,0))[3],0)

    def test_boss_frames(self):
        im=enemy_sheet("boss_ch002",REGION,True)
        self.assertEqual(im.size,(512,128))
        cells=[im.crop((i*128,0,(i+1)*128,128)) for i in range(4)]
        self.assertEqual(len(set(c.tobytes() for c in cells)),4)
        self.assertTrue(all(c.getchannel("A").getbbox() for c in cells))

    def test_nine_category_contracts(self):
        self.assertEqual(draw_prop(REGION,"cottage").size,(96,128))
        self.assertEqual(draw_prop(REGION,"tree").size,(96,128))
        self.assertEqual(landscape({"id":"map_coast_01","type":"town"},REGION).size,(1152,648))
        im=character_sheet("char_tidecaller",REGION)
        self.assertEqual(normal_map(im).size,im.size)
        self.assertEqual(normal_map(im).getpixel((0,0))[3],0)

    def test_reproducible_generation(self):
        a=enemy_sheet("boss_ch002",REGION,True).tobytes()
        b=enemy_sheet("boss_ch002",REGION,True).tobytes()
        self.assertEqual(a,b)
        self.assertNotEqual(a,enemy_sheet("boss_ch003",REGION,True).tobytes())

if __name__=="__main__":
    unittest.main()
