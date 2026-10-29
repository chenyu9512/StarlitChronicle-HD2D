"""V4.2 detail pass for Starlit Chronicle deterministic 2D art.

Canonical dimensions and IDs are inherited from V4.1. This is a procedural
art candidate renderer, NOT a human-approved identity illustration.
"""
from __future__ import annotations

import math
import random
from PIL import Image, ImageDraw
from art_style_v6 import _seed, _shade, _palette, normal_map, write_auxiliary_svgs
import art_style_v7 as previous


def terrain_cell(draw, x, y, base, kind, seed):
    previous.terrain_cell(draw, x, y, base, kind, seed)
    rng = random.Random(seed ^ 0x81A2B)
    # Interior detail only: the outer two pixels stay constant across variants.
    for i in range(16):
        px = x + rng.randrange(4, 27)
        py = y + rng.randrange(4, 27)
        if kind == "grass":
            draw.line((px, py + 1, px + rng.choice((-1, 0, 1)), py - 2),
                      fill=_shade(base, rng.uniform(-.29, .43)), width=1)
        elif kind == "sand":
            draw.arc((px-2, py-1, px+3, py+2), 15, 175,
                     fill=_shade(base, rng.uniform(-.20, .40)), width=1)
        elif kind == "road":
            draw.line((px-2, py, px+2, py), fill=_shade(base, -.27), width=1)
            draw.point((px, py-1), fill=_shade(base, .21))
        elif kind in ("stone", "wall", "cobbles"):
            draw.line((px, py, px+rng.randrange(2,5), py),
                      fill=_shade(base, rng.uniform(-.27,.31)), width=1)
        elif kind == "wood":
            draw.arc((px-2, py-2, px+3, py+2), 178, 348,
                     fill=_shade(base, -.22), width=1)
        elif kind == "water":
            draw.arc((px-3, py-1, px+4, py+2), 5, 170,
                     fill=_shade(base, rng.uniform(.13,.46)), width=1)
    draw.rectangle((x,y,x+31,y+31), outline=base, width=2)


def _role(asset_id):
    name=asset_id.lower()
    mapping={"wayfarer":"wanderer","tidecaller":"healer","lanyin":"healer",
             "shuoxian":"ranger","leiso":"knight","tifa":"engineer",
             "noe":"scribe","visha":"duelist","xuanli":"duelist","ize":"bard"}
    for term,role in mapping.items():
        if term in name: return role
    roles=("wanderer","healer","ranger","knight","engineer","bard","duelist","scribe")
    return roles[_seed(asset_id,"v8-role")%len(roles)]


def character_sheet(asset_id, region):
    image=previous.character_sheet(asset_id,region).convert("RGBA")
    d=ImageDraw.Draw(image,"RGBA")
    a,b,c=_palette(region)
    gold=(*_shade(b,.68),225)
    dark=(*_shade(c,-.52),225)
    role=_role(asset_id)
    for direction in range(4):
        for frame in range(3):
            x=frame*32; y=direction*48
            # Small embroidery, separated belt buckle and boot hardware.
            d.line((x+11,y+23,x+21,y+23),fill=gold,width=1)
            d.line((x+11,y+32,x+21,y+32),fill=dark,width=1)
            d.point((x+16,y+27),fill=(254,232,180,240))
            for foot in (11,21):
                d.line((x+foot-2,y+42,x+foot+2,y+42),fill=gold,width=1)
            if role=="engineer":
                d.point((x+14,y+10),fill=(147,240,233,245))
                d.point((x+20,y+10),fill=(147,240,233,245))
            elif role=="healer":
                d.ellipse((x+23,y+17,x+26,y+20),fill=(112,241,206,235))
            elif role=="ranger":
                d.line((x+25,y+20,x+27,y+35),fill=gold,width=1)
            elif role=="knight":
                d.line((x+8,y+24,x+10,y+29),fill=gold,width=1)
                d.line((x+23,y+24,x+25,y+29),fill=gold,width=1)
            elif role=="scribe":
                d.line((x+23,y+29,x+26,y+29),fill=gold,width=1)
                d.line((x+23,y+31,x+26,y+31),fill=gold,width=1)
            elif role=="duelist":
                d.line((x+25,y+23,x+27,y+38),fill=(232,241,249,230),width=1)
            elif role=="bard":
                d.line((x+23,y+29,x+23,y+35),fill=gold,width=1)
            elif role=="wanderer":
                d.ellipse((x+23,y+31,x+26,y+34),fill=(255,220,150,205))
    return image


def draw_prop(region,kind):
    image=previous.draw_prop(region,kind).convert("RGBA")
    d=ImageDraw.Draw(image,"RGBA")
    a,b,c=_palette(region)
    if kind=="tree":
        for dx,dy in ((28,60),(38,69),(61,41),(71,57),(48,30)):
            d.line((dx,dy,dx+4,dy-2),fill=(*_shade(a,.54),177),width=1)
        for px in (44,48,52):
            d.line((px,92,px-1,110),fill=(*_shade(b,.24),150),width=1)
    elif kind in ("cottage","shop","shrine"):
        for yy in (26,33,40):
            for xx in range(20,75,9):
                d.line((xx,yy,xx+4,yy),fill=(*_shade(c,.31),150),width=1)
        for yy in (60,71,82,93):
            d.line((15,yy,82,yy),fill=(*_shade(b,-.14),90),width=1)
        d.line((35,106,61,106),fill=(*_shade(b,.54),210),width=1)
        if kind=="shop":
            d.line((16,56,80,56),fill=(*_shade(a,.44),185),width=1)
    elif kind=="well":
        d.arc((29,83,72,99),186,336,fill=(*_shade(a,.55),195),width=1)
    elif kind=="lantern":
        d.ellipse((42,26,58,44),fill=(255,224,148,44))
    elif kind=="crate":
        for yy in (71,83,94,105):
            d.line((22,yy,78,yy),fill=(*_shade(b,.24),160),width=1)
    elif kind=="banner":
        for yy in range(32,81,12):
            d.line((53,yy,77,yy-2),fill=(*_shade(a,.29),115),width=1)
    return image


def enemy_sheet(asset_id,region,boss=False):
    image=previous.enemy_sheet(asset_id,region,boss).convert("RGBA")
    d=ImageDraw.Draw(image,"RGBA")
    a,b,c=_palette(region)
    for f in range(4):
        x=f*128
        rng=random.Random(_seed(asset_id,f,"v8-enemy-material"))
        # Outline highlight plus body microtexture; each cell remains isolated.
        d.arc((x+20,18,x+109,112),210,338,
              fill=(*_shade(b,.60),134 if boss else 81),width=1)
        for i in range(20 if boss else 12):
            px=x+rng.randrange(37,92)
            py=rng.randrange(43,87)
            d.line((px,py,px+rng.randrange(1,4),py-rng.randrange(0,2)),
                   fill=(*_shade(c,rng.uniform(.07,.48)),rng.randrange(80,167)),width=1)
        for j in range(6):
            d.point((x+38+j*10,91+(j%3)),
                    fill=(*_shade(a,.64),175))
    return image


def landscape(entry,region):
    image=previous.landscape(entry,region).convert("RGBA")
    d=ImageDraw.Draw(image,"RGBA")
    a,b,c=_palette(region)
    rng=random.Random(_seed(entry["id"],"v8-background"))
    if entry.get("type") in ("town","landmark"):
        for x in range(115,1040,74):
            if 389 < x < 666: continue
            y=500+int(8*math.sin(x*.014))
            d.line((x,y,x,y+17),fill=(*_shade(c,-.44),145),width=2)
            d.line((x-9,y+6,x+9,y+6),fill=(*_shade(b,.22),165),width=1)
            d.line((x-9,y+12,x+9,y+12),fill=(*_shade(b,-.16),143),width=1)
    for i in range(180):
        x=rng.randrange(20,1132); y=rng.randrange(489,627)
        if entry.get("type") in ("town","landmark") and 385 < x < 675: continue
        d.line((x,y,x+rng.randrange(0,3),y-rng.randrange(1,4)),
               fill=(*_shade(a,rng.uniform(-.12,.48)),rng.randrange(67,165)),width=1)
    if "coast" in region["id"] or "isles" in region["id"]:
        for i in range(115):
            x=rng.randrange(8,1144); y=rng.randrange(550,640)
            d.line((x,y,x+rng.randrange(4,16),y),
                   fill=(*_shade(b,.56),rng.randrange(40,132)),width=1)
    return image.convert("RGB")
