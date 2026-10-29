"""Deterministic HD-2D procedural candidate renderer (V4).

Retains canonical 32px tile / 32x48 walker / four-frame enemy contracts.
Includes alpha-preserving normal-map baking from the older HD2D generator.
Outputs remain review-only: procedural silhouettes do not establish lore identity.
"""
from __future__ import annotations

import hashlib
import math
import random
from PIL import Image, ImageDraw, ImageFilter
from art_common import stable_seed


def _seed(*parts):
    return stable_seed(*parts)


def _mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(x * (1 - t) + y * t) for x, y in zip(a[:3], b[:3]))


def _shade(color, amount):
    return _mix(color, (253, 236, 204) if amount > 0 else (17, 25, 39), abs(amount))


def _palette(region):
    raw = region.get("style", {}).get("palette", ["#83B9C4", "#D7C59D", "#386A82"])
    if len(raw) < 3:
        raw = ["#83B9C4", "#D7C59D", "#386A82"]
    return [tuple(int(s[i:i+2], 16) for i in (1, 3, 5)) for s in raw[:3]]


def terrain_cell(draw, x, y, base, kind, seed):
    """Detailed tile variant; a constant 2px border avoids checkerboard seams."""
    rng = random.Random(seed)
    draw.rectangle((x, y, x+31, y+31), fill=base)
    if kind in ("grass", "sand", "road"):
        count = {"grass": 26, "sand": 23, "road": 17}[kind]
        for _ in range(count):
            px, py = x+rng.randrange(3, 29), y+rng.randrange(3, 29)
            c = _shade(base, rng.choice((-.23, -.13, -.07, .12, .21)))
            if kind == "grass":
                draw.line((px, py+2, px-1, py-1), fill=c)
                draw.line((px+1, py+2, px+2, py), fill=_shade(base, .17))
            elif kind == "sand":
                draw.ellipse((px, py, px+1, py+1), fill=c)
                if rng.random() < .16:
                    draw.arc((px-3, py-1, px+4, py+3), 10, 170, fill=_shade(base, .17))
            else:
                draw.line((px, py, px+rng.randrange(2, 5), py), fill=c)
                if rng.random() < .35:
                    draw.line((px+1, py+2, px+4, py+2), fill=_shade(base, .12))
    elif kind == "water":
        for k in range(4):
            px, py = x+rng.randrange(4, 16), y+4+7*k
            draw.arc((px, py, px+13, py+4), 15, 160, fill=_shade(base, .33))
            draw.line((px+3, py+3, px+8, py+3), fill=_shade(base, .15))
            if rng.random() < .4:
                draw.point((px+10, py+2), fill=_shade(base, .48))
    elif kind == "wood":
        for oy in (7, 15, 23):
            draw.line((x+2, y+oy, x+29, y+oy), fill=_shade(base, -.28))
            draw.line((x+2, y+oy+1, x+29, y+oy+1), fill=_shade(base, .18))
        for _ in range(8):
            px, py = x+rng.randrange(4, 25), y+rng.randrange(3, 29)
            draw.line((px, py, px+rng.randrange(2, 6), py), fill=_shade(base, rng.uniform(-.25, .17)))
        for px in (7, 25):
            for py in (8, 24):
                draw.point((x+px, y+py), fill=_shade(base, -.35))
    else:
        # Scattered, inset stone/brick slabs with directional rims, no visible repeat grid.
        for _ in range(7 if kind == "cobbles" else 5):
            px, py = x+rng.randrange(3, 23), y+rng.randrange(3, 25)
            w, h = rng.randrange(5, 11), rng.randrange(3, 6)
            stone = _shade(base, rng.uniform(-.19, .16))
            draw.polygon([(px,py+1),(px+2,py),(px+w,py+1),(px+w+1,py+h-1),(px+1,py+h)], fill=stone)
            draw.line((px+2,py,px+w-1,py+1), fill=_shade(stone, .32))
            draw.line((px+2,py+h,px+w,py+h), fill=_shade(stone, -.3))
        if kind == "wall":
            for py in (9, 19):
                draw.line((x+2,y+py,x+29,y+py), fill=_shade(base, -.22))


def character_sheet(asset_id, region):
    """12 unique direction/gait cells, role-influenced silhouette and highlights."""
    a, b, c = _palette(region)
    rng = random.Random(_seed(asset_id, "v6", "costume"))
    tunic = _shade(a, rng.uniform(-.12, .13))
    cloak = _mix(c, a, .25)
    trim = _shade(b, .36)
    hair = _shade(c, rng.uniform(-.36, -.03))
    skin = [(237, 192, 153), (194, 143, 105), (244, 207, 176)][_seed(asset_id, 'skin') % 3]
    boot = _shade(c, -.61)
    accent = [(239, 190, 85), (92, 199, 179), (201, 118, 88), (171, 147, 225)][_seed(asset_id) % 4]
    variant = _seed(asset_id, "gear") % 4
    out = Image.new("RGBA", (96, 192), (0,0,0,0))
    d = ImageDraw.Draw(out)
    for direction in range(4):
        for frame in range(3):
            ox, oy = frame * 32, direction * 48
            step = (-2, 0, 2)[frame]
            bob = (1, 0, 1)[frame]
            # Ground contact remains stable even while the upper body bobs.
            d.ellipse((ox+7,oy+43,ox+25,oy+46),fill=(12,23,35,63))
            d.polygon([(ox+12,oy+22+bob),(ox+20,oy+22+bob),(ox+25,oy+40),(ox+7,oy+40)], fill=_shade(cloak,-.18))
            d.line((ox+10,oy+26,ox+8,oy+38),fill=_shade(cloak,.19),width=2)
            d.line((ox+21,oy+26,ox+23,oy+38),fill=_shade(cloak,-.29),width=2)
            for foot, off in ((11,step),(20,-step)):
                d.line((ox+foot,oy+34,ox+foot+off,oy+42),fill=boot,width=4)
                d.rectangle((ox+foot+off-2,oy+40,ox+foot+off+2,oy+43),fill=_shade(boot,-.18))
            d.polygon([(ox+11,oy+21+bob),(ox+21,oy+21+bob),(ox+23,oy+32),(ox+9,oy+32)], fill=tunic)
            d.line((ox+11,oy+23,ox+11,oy+31),fill=_shade(tunic,.31),width=2)
            d.line((ox+21,oy+23,ox+21,oy+31),fill=_shade(tunic,-.31),width=2)
            d.rectangle((ox+10,oy+31,ox+22,oy+33),fill=_shade(tunic,-.31))
            d.rectangle((ox+15,oy+31,ox+17,oy+33),fill=accent)
            for arm, delta in ((8,step//2),(23,-step//2)):
                d.line((ox+arm,oy+23+bob,ox+arm+delta,oy+33),fill=_shade(tunic,-.19),width=4)
                d.line((ox+arm+delta,oy+32,ox+arm+delta,oy+35),fill=skin,width=2)
            d.ellipse((ox+10,oy+7+bob,ox+22,oy+23+bob),fill=skin)
            d.arc((ox+10,oy+7+bob,ox+22,oy+23+bob),5,170,fill=_shade(skin,.22))
            if direction == 2:
                d.polygon([(ox+10,oy+14),(ox+11,oy+7),(ox+16,oy+4),(ox+22,oy+8),
                           (ox+23,oy+19),(ox+11,oy+21)],fill=hair)
                d.line((ox+12,oy+21,ox+20,oy+21),fill=trim,width=2)
            else:
                d.polygon([(ox+9,oy+15),(ox+10,oy+8),(ox+14,oy+5),(ox+20,oy+7),
                           (ox+23,oy+12),(ox+20,oy+12),(ox+16,oy+10)],fill=hair)
                if direction == 0:
                    for eye in (13,20):
                        d.point((ox+eye,oy+17+bob), fill=_shade(c,-.71))
                    d.line((ox+15,oy+21+bob,ox+18,oy+21+bob),fill=_shade(skin,-.18))
                elif direction == 1:
                    d.rectangle((ox+11,oy+16+bob,ox+12,oy+17+bob),fill=_shade(c,-.71))
                else:
                    d.rectangle((ox+20,oy+16+bob,ox+21,oy+17+bob),fill=_shade(c,-.71))
            # Costume motifs and professions: staff, satchel, shoulder armour, scarf.
            if variant == 0:
                d.line((ox+25,oy+17,ox+26,oy+38),fill=_shade(b,-.32),width=2)
                d.ellipse((ox+23,oy+14,ox+28,oy+19),fill=accent)
            elif variant == 1:
                d.rectangle((ox+21,oy+28,ox+27,oy+36),fill=_shade(b,-.18))
                d.line((ox+21,oy+28,ox+27,oy+34),fill=trim,width=1)
            elif variant == 2:
                d.polygon([(ox+8,oy+23),(ox+13,oy+20),(ox+16,oy+23),(ox+12,oy+28)],fill=trim)
                d.polygon([(ox+19,oy+23),(ox+23,oy+21),(ox+25,oy+25)],fill=trim)
            else:
                d.line((ox+11,oy+23,ox+22,oy+29),fill=accent,width=2)
                d.point((ox+15,oy+26),fill=trim)
    return out


def draw_prop(region, kind):
    """More expressive props with restrained directional lighting and soft grounding."""
    a,b,c = _palette(region)
    rng = random.Random(_seed(region['id'],kind,"v6"))
    out=Image.new("RGBA",(96,128),(0,0,0,0)); d=ImageDraw.Draw(out)
    d.ellipse((10,109,89,120),fill=(18,27,36,42))
    if kind == "tree":
        d.polygon([(39,117),(42,64),(49,57),(55,76),(54,116)],fill=_shade(b,-.53))
        d.line((44,72,45,109),fill=_shade(b,.15),width=3)
        for cx,cy,r in [(35,57,22),(61,55,23),(48,31,24),(43,75,18),(67,73,17)]:
            d.ellipse((cx-r,cy-r//2,cx+r,cy+r//2+15),fill=_shade(a,rng.uniform(-.34,-.10)))
            d.arc((cx-r+3,cy-r//2+1,cx+r-6,cy+r//2+8),185,328,fill=_shade(a,.23),width=2)
            for _ in range(12):
                px=cx+rng.randint(-r+5,r-5);py=cy+rng.randint(-r//2+3,r//2)
                d.line((px,py,px+3,py-1),fill=_shade(a,rng.choice((.19,.29,-.20))),width=1)
    elif kind in ("cottage","shop","shrine"):
        d.polygon([(9,47),(48,10),(88,47),(86,107),(10,107)],fill=_shade(b,-.24))
        d.rectangle((14,50,82,105),fill=_shade(b,.17),outline=_shade(c,-.38),width=2)
        for y in range(55,103,12):
            d.line((15,y,81,y),fill=_shade(b,-.11))
        # Roof silhouette, ridge, shingle rhythms and warm eave shadow.
        d.polygon([(3,47),(48,9),(92,47),(85,54),(48,20),(11,54)],fill=_shade(c,-.24))
        d.line((8,44,48,12,87,44),fill=_shade(c,.3),width=2)
        for y in (27,35,43):
            half=(y-10)*.93
            for x in range(round(48-half),round(48+half),11):
                d.line((x,y,x+5,y),fill=_shade(c,.1))
        d.rectangle((38,76,60,106),fill=_shade(c,-.54))
        d.rectangle((41,79,58,106),fill=_shade(b,-.51))
        d.ellipse((54,93,56,96),fill=_shade(b,.67))
        for x in (20,69):
            d.rectangle((x,59,x+10,75),fill=_shade(a,.43),outline=_shade(c,-.32),width=2)
            d.line((x+5,60,x+5,74),fill=_shade(b,.17))
        if kind=="shop":
            d.polygon([(13,54),(83,54),(79,63),(18,63)],fill=_shade(a,-.23))
            for x in range(20,80,12):
                d.polygon([(x,54),(x+6,54),(x+4,63),(x-2,63)],fill=_shade(b,.33))
        if kind=="shrine":
            d.polygon([(48,16),(55,31),(48,42),(41,31)],fill=_shade(b,.67))
            d.line((48,16,48,42),fill=_shade(c,-.15),width=2)
    elif kind=="well":
        d.ellipse((16,69,82,110),fill=_shade(c,-.42))
        d.ellipse((23,72,75,101),fill=_shade(b,.17))
        d.ellipse((30,77,68,95),fill=_shade(a,-.55))
        d.arc((30,79,67,91),5,165,fill=_shade(a,.56),width=2)
        for x in (23,70):
            d.rectangle((x,33,x+5,89),fill=_shade(b,-.41))
            d.line((x+1,37,x+1,84),fill=_shade(b,.26))
        d.polygon([(13,38),(48,13),(86,38),(79,43),(48,23),(19,43)],fill=_shade(c,-.16))
        d.line((18,35,48,16,81,36),fill=_shade(c,.3),width=2)
    elif kind=="lantern":
        d.rectangle((46,52,51,116),fill=_shade(c,-.62))
        d.rectangle((43,114,55,118),fill=_shade(c,-.36))
        d.polygon([(29,48),(34,21),(64,21),(69,48),(63,55),(35,55)],fill=_shade(c,-.25))
        d.ellipse((36,26,62,53),fill=(*_shade(b,.71),220))
        d.polygon([(48,28),(56,41),(48,51),(40,41)],fill=_shade(b,.91))
        d.line((35,24,62,24),fill=_shade(c,.47),width=2)
    elif kind=="crate":
        d.rectangle((18,61,82,111),fill=_shade(b,-.16),outline=_shade(c,-.48),width=3)
        for y in (65,79,95,108):
            d.line((20,y,80,y),fill=_shade(b,.21),width=2)
        d.line((24,67,77,105),fill=_shade(c,-.34),width=4)
        d.line((78,67,24,105),fill=_shade(c,-.34),width=4)
        for x in (22,76):
            for y in (65,105): d.ellipse((x,y,x+2,y+2),fill=_shade(b,.62))
    elif kind=="banner":
        d.rectangle((45,11,50,118),fill=_shade(b,-.38))
        d.line((43,17,84,29),fill=_shade(b,-.32),width=3)
        d.polygon([(48,21),(82,31),(79,81),(63,74),(48,80)],fill=_shade(a,-.16))
        d.polygon([(61,38),(69,47),(62,57),(54,47)],fill=_shade(b,.57))
        d.line((51,25,77,33),fill=_shade(a,.32),width=2)
    return out


def enemy_sheet(asset_id,region,boss=False):
    """Seeded, morphologically distinct four-frame monsters with silhouette motifs."""
    a,b,c=_palette(region)
    seed=_seed(asset_id,"v6 enemy"); rng=random.Random(seed)
    kind=(2 if asset_id.endswith("ch002") else 1 if asset_id.endswith("ch003") else seed%5)
    out=Image.new("RGBA",(512,128),(0,0,0,0));d=ImageDraw.Draw(out)
    for frame in range(4):
        x=128*frame; sway=(-3,0,3,0)[frame];y=sway
        hue=_shade(a,(-.16,.02,.14,0)[frame]);rim=_shade(hue,.31)
        d.ellipse((x+28,106,x+102,118),fill=(18,29,39,61))
        if kind==0:  # Armoured sentry
            d.polygon([(x+30,94),(x+36,49+y),(x+63,30+y),(x+91,52+y),(x+100,98)],fill=_shade(c,-.25))
            d.polygon([(x+43,48+y),(x+63,25+y),(x+83,48+y),(x+76,70+y),(x+49,70+y)],fill=hue)
            d.polygon([(x+37,78),(x+62,66),(x+90,79),(x+88,100),(x+38,100)],fill=rim)
            for side in (28,93):
                d.polygon([(x+side,65),(x+side+(-11 if side==28 else 11),45+y),(x+side+3,84)],fill=_shade(c,.21))
        elif kind==1:  # Tide-mark sentinel
            d.polygon([(x+29,106),(x+35,42+y),(x+61,19+y),(x+96,50+y),(x+100,108)],fill=_shade(c,-.28))
            for offset in (0,13,27):
                d.line((x+42,65+offset,x+88,58+offset),fill=_shade(c,.25),width=3)
            d.polygon([(x+45,47+y),(x+65,31+y),(x+85,49+y),(x+75,74+y),(x+53,74+y)],fill=hue)
            d.polygon([(x+36,67),(x+15,43+y),(x+26,89)],fill=_shade(b,-.2))
            d.polygon([(x+94,67),(x+113,43+y),(x+105,89)],fill=_shade(b,-.2))
        elif kind==2:  # Fog-tide parasite: tentacles, translucent bell
            for k in range(7):
                bx=x+28+k*12
                tip=bx+(-7 if k%2 else 9)+sway
                d.line((bx,80+y,tip,112-k%3*5),fill=_shade(c,.18),width=5)
                d.line((bx-1,87+y,tip,112-k%3*5),fill=_shade(a,.27),width=2)
            d.ellipse((x+25,33+y,x+105,87+y),fill=_shade(c,-.2),outline=rim,width=3)
            d.arc((x+35,39+y,x+95,78+y),185,347,fill=_shade(a,.5),width=4)
            for ox in (49,81): d.ellipse((x+ox-5,59+y,x+ox+5,68+y),fill=_shade(b,.69))
        elif kind==3:  # Winged thing
            d.polygon([(x+60,70+y),(x+24,28+y),(x+13,83),(x+42,93),(x+62,89)],fill=_shade(c,-.1))
            d.polygon([(x+66,70+y),(x+103,21+y),(x+116,82),(x+88,95),(x+65,89)],fill=_shade(c,-.29))
            d.ellipse((x+43,47+y,x+84,103+y),fill=hue)
            for ox in (21,107): d.line((x+ox,71,x+63,87),fill=_shade(a,.36),width=2)
        else:  # Crystal creature
            d.polygon([(x+63,15+y),(x+94,58+y),(x+82,109),(x+43,109),(x+31,57+y)],fill=_shade(c,-.28))
            for i in range(6):
                ox=x+42+i*8
                d.polygon([(ox,51+y),(ox+4,22+y-(i%3)*5),(ox+8,54+y)],fill=_shade(a,(i%3)*.12))
            d.polygon([(x+46,71+y),(x+63,48+y),(x+81,72+y),(x+70,97),(x+52,97)],fill=hue)
            d.line((x+53,70,x+62,52),fill=_shade(b,.51),width=2)
        for eye in (54,74):
            if kind != 2: d.ellipse((x+eye-4,66+y,x+eye+3,71+y),fill=_shade(b,.77))
        if boss:
            d.arc((x+16,17+y,x+111,111+y),195,340,fill=_shade(b,.38),width=2)
            for ox in (35,92): d.point((x+ox,31+y),fill=_shade(b,.77))
    return out


def landscape(entry,region):
    """Layered painterly backdrop, deterministic per map and biased by map type."""
    a,b,c=_palette(region)
    rng=random.Random(_seed(entry['id'],"v6 landscape"))
    w,h=1152,648;out=Image.new('RGB',(w,h));d=ImageDraw.Draw(out)
    for y in range(h):
        t=y/h
        d.line((0,y,w,y),fill=_mix(_shade(c,.58),_shade(a,-.23),t*.89))
    d=ImageDraw.Draw(out,'RGBA')
    sun=(rng.randrange(705,960),rng.randrange(70,150))
    for r,opacity in ((125,12),(90,20),(62,39),(45,80)):
        d.ellipse((sun[0]-r,sun[1]-r,sun[0]+r,sun[1]+r),fill=(*_shade(b,.7),opacity))
    d.ellipse((sun[0]-36,sun[1]-36,sun[0]+36,sun[1]+36),fill=(*_shade(b,.82),155))
    for layer in range(6):
        baseline=245+layer*54; amplitude=21+layer*9
        pts=[(-4,h)]
        offset=rng.random()*10
        for x in range(-4,w+70,28):
            height=int(math.sin(x*.007+offset)*amplitude+math.sin(x*.018+layer)*amplitude*.3)
            pts.append((x,baseline+height+rng.randrange(-9,10)))
        pts.append((w+4,h))
        fill=_shade(_mix(a,c,min(1,layer*.18)),layer*(-.047))
        d.polygon(pts,fill=(*fill,255))
        if layer<3:
            d.line(pts[1:-1],fill=(*_shade(fill,.26),120),width=2)
    # Add contextual landmarks without touching gameplay collision geometry.
    is_town=entry.get('type') in ('town','landmark')
    for i in range(17 if is_town else 10):
        x=rng.randrange(25,w-130);base_y=rng.randrange(456,575)
        size=rng.randrange(27,72)
        if is_town:
            wall=_shade(b,rng.uniform(-.19,.12)); roof=_shade(c,rng.uniform(-.30,-.05))
            d.rectangle((x,base_y-size+13,x+size,base_y),fill=(*wall,255))
            d.polygon([(x-9,base_y-size+15),(x+size//2,base_y-size-15),(x+size+9,base_y-size+15)],fill=(*roof,255))
            d.line((x,base_y-size+14,x+size//2,base_y-size-13,x+size,base_y-size+14),fill=(*_shade(roof,.35),235),width=2)
            d.rectangle((x+size//3,base_y-18,x+size//3+10,base_y-4),fill=(*_shade(c,-.38),255))
            for xx in range(x+8,x+size-8,15):
                d.line((xx,base_y-size+29,xx+7,base_y-size+29),fill=(*_shade(wall,-.22),225),width=2)
        else:
            d.ellipse((x,base_y-size,x+size,base_y),fill=(*_shade(c,-.12),255))
            d.ellipse((x-8,base_y-size+8,x+size-17,base_y-8),fill=(*_shade(a,-.19),245))
    for i in range(60):
        xx=rng.randrange(w); yy=rng.randrange(370,620)
        d.line((xx,yy,xx+rng.randrange(4,22),yy),fill=(*_shade(b,.28),rng.randrange(30,100)))
    return out


def normal_map(image, strength=2.2):
    """Sobel baked tangent-space normal PNG; keeps source alpha and neutral transparent pixels."""
    rgba=image.convert('RGBA');w,h=rgba.size
    alpha=rgba.getchannel('A')
    lum=rgba.convert('L')
    # Original generator's brightness-derived height field, with alpha-masked edges.
    height=Image.blend(Image.new('L',(w,h),102),lum,.55)
    height=Image.composite(height,Image.new('L',(w,h),0),alpha)
    dx=height.filter(ImageFilter.Kernel((3,3),(-1,0,1,-2,0,2,-1,0,1),scale=4,offset=128))
    dy=height.filter(ImageFilter.Kernel((3,3),(-1,-2,-1,0,0,0,1,2,1),scale=4,offset=128))
    ox=dx.tobytes();oy=dy.tobytes();oa=alpha.tobytes()
    out=bytearray(w*h*4)
    for i,opacity in enumerate(oa):
        j=4*i
        if not opacity:
            out[j:j+4]=b'\x80\x80\xff\x00';continue
        nx=(128-ox[i])*strength/127
        ny=(128-oy[i])*strength/127
        inv=1/math.sqrt(nx*nx+ny*ny+1)
        out[j]=max(0,min(255,round(128+127*nx*inv)))
        out[j+1]=max(0,min(255,round(128+127*ny*inv)))
        out[j+2]=max(0,min(255,round(128+127*inv)))
        out[j+3]=opacity
    return Image.frombytes('RGBA',(w,h),bytes(out))


def write_auxiliary_svgs(output):
    """Merge the old generator's eight job glyphs and four evidence UI concepts.

    Vector UI lives in the candidate folder, not the runtime. Consumers may
    independently verify/approve each SVG before importing into Godot.
    """
    from pathlib import Path
    from xml.sax.saxutils import escape
    jobs = [
        ('SHIELD_GUARDIAN','守御盾卫','#C3A058','shield'),
        ('STARLIGHT_HEALER','星灯药师','#4DB6AC','heal'),
        ('TIDE_RANGER','潮猎游侠','#E57373','arrow'),
        ('GEAR_ARTIFICER','齿轮工匠','#4DD0E1','gear'),
        ('RESONANCE_BARD','共鸣乐师','#9575CD','music'),
        ('MIRROR_BLADE','镜影剑舞','#FFD54F','blade'),
        ('CHRONICLE_KEEPER','岁影记述','#90CAF9','book'),
        ('ASTRA_ARBITER','星轨裁定','#CE93D8','star'),
    ]
    glyphs = {
        'shield':'<path d="M60 27L79 35V52Q77 67 60 75Q43 67 41 52V35Z"/>',
        'heal':'<path d="M53 29H67V44H81V56H67V70H53V56H39V44H53Z"/>',
        'arrow':'<path d="M36 67L80 31M59 28L82 28L83 51M36 67L53 63L41 52"/>',
        'gear':'<circle cx="60" cy="50" r="20"/><circle cx="60" cy="50" r="9"/><path d="M60 26V18M60 74V82M36 50H28M84 50H92M43 33L37 27M77 67L83 73"/>',
        'music':'<path d="M57 31L79 25V59Q79 68 69 69Q59 70 61 60Q62 55 72 56V36L57 40V67Q56 78 46 78Q35 79 39 67Q41 62 50 63V34Z"/>',
        'blade':'<path d="M34 72L77 26L85 19L79 38L45 77M32 70L48 83M41 61L57 77"/>',
        'book':'<path d="M30 29Q45 21 60 30Q75 21 90 29V75Q75 68 60 77Q45 68 30 75Z M60 30V77"/>',
        'star':'<path d="M60 23L70 43L92 47L76 62L80 83L60 72L40 83L44 62L28 47L50 43Z"/>'
    }
    produced=[]
    for job_id,name,color,glyph in jobs:
        path=Path(output)/'ui_svg/job_icons'/(job_id+'.svg')
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">
<defs><linearGradient id="g" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#27384C"/><stop offset="1" stop-color="#121C2B"/></linearGradient></defs>
<path d="M60 7L109 35V85L60 113L11 85V35Z" fill="url(#g)" stroke="{color}" stroke-width="3"/>
<path d="M60 14L101 39V81L60 105L19 81V39Z" fill="none" stroke="{color}" stroke-opacity=".28"/>
<g fill="none" stroke="{color}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">{glyphs[glyph]}</g>
<text x="60" y="98" fill="#F5F3EA" text-anchor="middle" font-size="10" font-family="sans-serif">{escape(name)}</text></svg>''',encoding='utf-8')
        produced.append(path.relative_to(output).as_posix())
    evidences=[
        ('ev_ch001_envelope','蓝染海盐信封','<rect x="90" y="54" width="220" height="142" rx="5"/><path d="M90 54L200 130L310 54"/><circle cx="144" cy="157" r="17"/>'),
        ('ev_ch003_half_badge','潮痕残破船徽','<path d="M150 47Q74 126 150 213L236 183L215 141L241 105L215 67Z"/><path d="M170 173Q155 122 187 88M168 137L144 119"/>'),
        ('ev_ch007_seal_rubbing','三枚退回印章','<rect x="56" y="68" width="77" height="76"/><rect x="161" y="68" width="77" height="76"/><rect x="266" y="68" width="77" height="76"/>'),
        ('ev_ch039_noe_ticket','岁影旧洲车票','<rect x="69" y="66" width="262" height="135" rx="9"/><path d="M92 119H308M92 153H250"/>'),
    ]
    for key,title,shapes in evidences:
        path=Path(output)/'ui_svg/evidence_svg'/(key+'.svg')
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 260">
<rect width="400" height="260" rx="11" fill="#152332"/>
<path d="M19 19H381V241H19Z" fill="none" stroke="#BDA578" stroke-width="2"/>
<g stroke="#A68B64" fill="#E9D9B9" stroke-width="3" stroke-linejoin="round">{shapes}</g>
<text x="200" y="234" text-anchor="middle" font-family="sans-serif" font-size="18" fill="#EEE0C3">{escape(title)}</text></svg>''',encoding='utf-8')
        produced.append(path.relative_to(output).as_posix())
    return produced