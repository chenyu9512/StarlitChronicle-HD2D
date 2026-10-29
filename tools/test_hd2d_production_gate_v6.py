#!/usr/bin/env python3
"""Unit regression for studio v6 production quality gate."""
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).resolve().parent))
from hd2d_production_gate_v6 import frame_quality, terrain_quality, stage_review, inspect

class GateTests(unittest.TestCase):
    def test_reject_same_frame_repeated_12_times(self):
        art=Image.new("RGBA",(96,192),(0,0,0,0))
        sample=Image.new("RGBA",(32,48),(0,0,0,0))
        ImageDraw.Draw(sample).ellipse((8,6,24,43),fill=(180,100,80,255))
        for y in range(4):
            for x in range(3):
                art.paste(sample,(x*32,y*48))
        with self.assertRaisesRegex(ValueError,"DUPLICATE_ANIMATION_FRAMES"):
            frame_quality(art,"characters")

    def test_four_distinct_rgba_directions_not_false_rejected(self):
        # PIL RGBA getbbox() treats an all-zero alpha *difference* as empty.
        # The comparison must inspect RGB and alpha difference separately.
        art=Image.new("RGBA",(96,192),(0,0,0,0))
        for row in range(4):
            for col in range(3):
                color=(80+row*30,80+col*45,120,255)
                ImageDraw.Draw(art).rectangle(
                    (col*32+7,row*48+4,col*32+24,row*48+44),fill=color)
        report=frame_quality(art,"characters")
        self.assertEqual(report["frame_layout"],"4x3")

    def test_reject_broken_tile_edges(self):
        im=Image.new("RGB",(256,256),(50,50,50))
        d=ImageDraw.Draw(im)
        for row in range(8):
            for col in range(8):
                d.line((col*32+31,row*32,col*32+31,row*32+31),fill=(255,0,0))
        with self.assertRaisesRegex(ValueError,"TILE_SEAM_MISMATCH"):
            terrain_quality(im,"terrain")

    def test_reject_unapproved_stage(self):
        with TemporaryDirectory() as d:
            root=Path(d)
            review=root/"review.json"
            review.write_text('{"schema":"starlit.hd2d.v6.review.v1","runtime_modified":false,"assets":[]}')
            with self.assertRaisesRegex(ValueError,"NO_APPROVED_ASSETS"):
                stage_review(review,root/"models",root/"stage")

    def test_transparent_blank_not_accepted(self):
        with TemporaryDirectory() as d:
            path=Path(d)/"empty.png"
            Image.new("RGBA",(96,192),(0,0,0,0)).save(path)
            with self.assertRaises(ValueError):
                inspect(path,"characters")

if __name__ == "__main__":
    unittest.main(verbosity=2)
