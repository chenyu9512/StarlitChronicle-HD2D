#!/usr/bin/env python3
"""Create a convenient review contact sheet, not a game-runtime texture."""
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
root=Path(__file__).resolve().parents[1]
dir_=root/"assets/art"
W,H=1200,1250
im=Image.new("RGB",(W,H),"#172c3e")
d=ImageDraw.Draw(im)
d.text((22,17),"STARLIT CHRONICLE | BATCHES 0-3 | ART PRODUCTION REVIEW",fill="#f2d6a7")
def draw(path,x,y,w,h):
 src=Image.open(dir_/path).convert("RGBA")
 src.thumbnail((w,h),Image.Resampling.NEAREST)
 tile=Image.new("RGBA",(w,h),(45,67,79,255))
 tile.alpha_composite(src,((w-src.width)//2,(h-src.height)//2))
 im.paste(tile.convert("RGB"),(x,y))
for i,key in enumerate(("leon","lanyin","chengzhou","shuoxian")):
 x=22+i*295
 draw(f"characters/{key}/portrait.png",x,55,280,300)
 d.text((x,362),key,fill="#f0d2a0")
d.text((22,400),"WHITE SAND COAST | ENVIRONMENT BACKDROPS",fill="#f1d3ac")
for i,key in enumerate(("morning_dew_village","white_sand_port","tide_lighthouse","chengzhou_house")):
 draw(f"backdrops/coast/{key}.png",22+(i%2)*595,430+(i//2)*220,577,195)
d.text((22,890),"WHITE SAND COAST | 9 MONSTERS",fill="#f1d3ac")
keys=("salt_slime","fog_crab","sand_lizard","tide_ghost","white_seabird","shell_hermit","salt_wolf","star_ray","tide_guardian")
for i,key in enumerate(keys):
 x=22+i*130
 draw(f"monsters/coast/{key}/bestiary.png",x,915,120,120)
 d.text((x,1040),key[:16],fill="#e7e2d4")
out=dir_/"_spec"/"preview_batch_0_3.png"
im.save(out,optimize=True)
print("Wrote",out)
