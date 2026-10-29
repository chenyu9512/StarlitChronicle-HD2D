#!/usr/bin/env python3
"""Coherent generated HD-2D pixel styling for 32px terrain and 3x4 walkers.

All tile edges share the same base shade, unlike the old per-column tint,
so roads/grass do not form bright vertical bands when TileMap cells repeat.
Variations and characters are deterministic by canonical identity.
"""
from __future__ import annotations

import hashlib
import math
import random
from PIL import Image, ImageDraw

def _seed(*values):
    return int.from_bytes(hashlib.sha256("|".join(map(str, values)).encode()).digest()[:8], "big")

def _mix(a, b, t):
    return tuple(max(0,min(255,round(x*(1-t)+y*t))) for x,y in zip(a,b))

def _shade(c, t):
    return _mix(c, (247,232,197) if t>0 else (19,26,37), abs(t))

def _dot(d, x, y, c, w=1, h=1):
    d.rectangle((x,y,x+w-1,y+h-1), fill=c)

def terrain_cell(d, x, y, base, kind, seed):
    """Draw a contiguous-edge-safe material sample in a 32x32 atlas cell."""
    rng=random.Random(seed)
    d.rectangle((x,y,x+31,y+31),fill=base)
    # No per-column tint and no heavy cell perimeter. The 2px outer ring
    # always shares the same material base across every variant.
    if kind in ("grass","road","sand"):
        density={"grass":19,"road":10,"sand":12}[kind]
        for _ in range(density):
            px=x+rng.randrange(3,29);py=y+rng.randrange(3,29)
            c=_shade(base,rng.choice((-.18,-.12,.10,.16)))
            if kind=="grass":
                _dot(d,px,py,c,1,2)
                _dot(d,px+2,py-1,_shade(c,.08),1,2)
                if rng.random()<.12: _dot(d,px-1,py-1,_shade(base,.38),2,1)
            elif kind=="road":
                _dot(d,px,py,c,rng.randrange(2,5),1)
                if rng.random()<.25: _dot(d,px+1,py+2,_shade(base,.22),1,1)
            else:
                _dot(d,px,py,c,rng.randrange(1,4),1)
                if rng.random()<.24: _dot(d,px+1,py+1,_shade(base,.25),2,1)
        if kind=="road":
            # Sparse embedded stones without a repeated thick border.
            for _ in range(3):
                px=x+rng.randrange(5,24); py=y+rng.randrange(5,24)
                d.polygon([(px,py+2),(px+4,py),(px+7,py+2),
                           (px+6,py+5),(px+1,py+5)],
                          fill=_shade(base,rng.uniform(-.18,.09)))
                d.line((px+1,py+1,px+4,py),fill=_shade(base,.24))
    elif kind in ("stone","cobbles","wall"):
        # Break the fake repeated cliff glyph by irregularly sized stones.
        for _ in range(5 if kind=="cobbles" else 4):
            px=x+rng.randrange(4,23);py=y+rng.randrange(4,24)
            rw=rng.randrange(5,10);rh=rng.randrange(3,6)
            stone=_shade(base,rng.uniform(-.12,.11))
            d.polygon([(px,py+1),(px+2,py),(px+rw,py+1),
                       (px+rw+1,py+rh-1),(px+1,py+rh)],fill=stone)
            d.line((px+1,py+1,px+rw-1,py+1),fill=_shade(stone,.18))
            d.line((px+2,py+rh,px+rw,py+rh),fill=_shade(stone,-.18))
        if kind=="wall":
            for py in (9,19):
                d.line((x+3, y+py, x+28, y+py),fill=_shade(base,-.17))
    elif kind=="wood":
        for offset in (7,15,23):
            d.line((x+3,y+offset,x+28,y+offset),fill=_shade(base,-.16))
            d.line((x+3,y+offset+1,x+28,y+offset+1),fill=_shade(base,.10))
        for _ in range(5):
            px=x+rng.randrange(6,25);py=y+rng.randrange(5,28)
            d.line((px,py,px+rng.randrange(2,6),py),fill=_shade(base,rng.uniform(-.19,.20)))
        for px in (7,24):
            _dot(d,x+px,y+7,_shade(base,-.25))
            _dot(d,x+px,y+23,_shade(base,-.25))
    elif kind=="water":
        # All variants share near-identical edge color, with short ripples
        # fully inside the cell. No hard rectangular borders.
        for k in range(4):
            px=x+rng.randrange(5,16);py=y+4+k*7
            d.arc((px,py,px+13,py+4), 8, 160, fill=_shade(base,.25))
            _dot(d,px+4,py+2,_shade(base,.10),4,1)
    else:
        for _ in range(10):
            px=x+rng.randrange(3,29);py=y+rng.randrange(3,29)
            _dot(d,px,py,_shade(base,rng.uniform(-.12,.15)))

def character_sheet(asset_id, region):
    """Four direction rows, three real gait frames (96x192, 32x48 cells)."""
    palette=region.get("style",{}).get("palette",["#83B9C4","#D7C59D","#386A82"])
    def parse(s):
        s=s.lstrip("#")
        return tuple(int(s[i:i+2],16) for i in (0,2,4))
    a,b,c=tuple(map(parse,palette[:3]))
    rng=random.Random(_seed(asset_id,"v5-walker"))
    tunic=_shade(a,rng.uniform(-.1,.12)); trim=_shade(b,.25)
    cloak=_mix(c,a,.26); hair=_shade(c,rng.uniform(-.30,.14))
    shoes=_shade(c,-.48); skin=(223,177,141)
    if rng.randrange(3)==0: skin=(176,119,85)
    if rng.randrange(4)==0: skin=(242,205,165)
    accent=[(193,115,79),(74,146,131),(202,172,102),(132,124,180)][_seed(asset_id)%4]
    out=Image.new("RGBA",(96,192),(0,0,0,0)); d=ImageDraw.Draw(out)
    for direction in range(4):
        for frame in range(3):
            ox,oy=frame*32,direction*48
            stride=(-2,0,2)[frame];arm_shift=(1,0,-1)[frame]
            # Shadow and distant cloak should not change the walker's floor
            # contact or exceed the 32x48 collision-independent frame.
            d.ellipse((ox+8,oy+43,ox+24,oy+46), fill=(16,28,39,70))
            d.polygon([(ox+11,oy+22),(ox+21,oy+22),(ox+25,oy+39),
                       (ox+7,oy+39)],fill=_shade(cloak,-.20))
            for sx,step in ((11,stride),(20,-stride)):
                d.line((ox+sx,oy+34,ox+sx+step,oy+42),fill=shoes,width=4)
                _dot(d,ox+sx+step-2,oy+41,_shade(shoes,-.13),5,3)
            # Warm-lit tunic with clearly separated sleeves and sash.
            d.polygon([(ox+11,oy+21),(ox+21,oy+21),(ox+24,oy+33),
                       (ox+9,oy+33)],fill=tunic)
            d.line((ox+12,oy+23,ox+11,oy+31),fill=_shade(tunic,.25),width=2)
            _dot(d,ox+10,oy+31,14,3,_shade(tunic,-.20)) if False else None
            d.rectangle((ox+11,oy+31,ox+21,oy+33),fill=_shade(tunic,-.24))
            _dot(d,ox+15,oy+31,3,3,accent)
            for sx,offset in ((8,arm_shift),(23,-arm_shift)):
                d.line((ox+sx,oy+24,ox+sx+offset,oy+33),fill=_shade(tunic,-.12),width=4)
                d.line((ox+sx+offset,oy+32,ox+sx+offset,oy+36),fill=skin,width=3)
            # Nose/eye placement depends on direction; prevent four rows
            # from being copies of the exact same frontal face.
            d.ellipse((ox+10,oy+7,ox+22,oy+23),fill=skin)
            d.arc((ox+10,oy+7,ox+22,oy+23),180,350,fill=_shade(skin,-.26),width=1)
            if direction==2: # walking north, back of head/collar
                d.polygon([(ox+9,oy+12),(ox+11,oy+6),(ox+21,oy+6),
                           (ox+24,oy+18),(ox+21,oy+22),(ox+11,oy+21)],fill=hair)
                _dot(d,ox+12,oy+20,8,3,_shade(cloak,.14))
            else:
                d.polygon([(ox+10,oy+14),(ox+9,oy+9),(ox+13,oy+5),
                           (ox+21,oy+7),(ox+23,oy+14),(ox+18,oy+11)],fill=hair)
                if direction==0: # frontal
                    for xx in (13,20): _dot(d,ox+xx,oy+17,1,2,_shade(c,-.65))
                    _dot(d,ox+16,oy+21,2,1,_shade(skin,-.33))
                elif direction==1: _dot(d,ox+11,oy+17,2,2,_shade(c,-.65))
                elif direction==3: _dot(d,ox+21,oy+17,2,2,_shade(c,-.65))
            # Matching region costume detail, independent for each identity.
            _dot(d,ox+15,oy+25,2,3,trim)
            if _seed(asset_id)%3==0:
                d.line((ox+21,oy+24,ox+23,oy+30),fill=accent,width=2)
    return out
