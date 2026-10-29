
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Starlit Chronicle HD-2D Studio V7.

Identity-driven asset generator focused on *recognizable* character silhouettes,
regional scene flavor, and automatic distinctiveness auditing.

This is still an offline art-production bridge, not a replacement for final
commercial illustration approval.
"""
from __future__ import annotations
import argparse, hashlib, json, math, random, shutil
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, List, Tuple
from PIL import Image, ImageDraw, ImageFilter, ImageOps
from art_common import sha256_file

VERSION = '7.0.0'
DIRS = ('front','left','back','right')
POSES = ('step_left','idle','step_right')

@dataclass(frozen=True)
class IdentityProfile:
    cid: str
    title: str
    role: str
    primary: str
    secondary: str
    dark: str
    skin: str
    hair: str
    hair2: str
    motif: str
    gear: str
    body: str
    hem: str
    crest: str
    aura: str
    region: str

PROFILES: Dict[str, IdentityProfile] = {
    'protagonist': IdentityProfile('protagonist','主角','灯行旅人','#3f6f8e','#f2cb85','#26334a','#efcfb4','#27324b','#4f6490','lantern','lantern','traveler','split','star','amber','coast'),
    'lanyin': IdentityProfile('lanyin','岚音','星灯药师','#2f8a86','#d8efc9','#25445d','#efd7c3','#3ba6a1','#daf0e9','halo','staff','robe','petal','cross','mint','coast'),
    'shuoxian': IdentityProfile('shuoxian','朔弦','潮汐游侠','#415f73','#df8a59','#24344c','#e4c5ad','#3d5f87','#8eb6d1','wave','bow','ranger','angled','arrow','teal','isles'),
    'leiso': IdentityProfile('leiso','雷索','守御队长','#937652','#c8d0d5','#2e3446','#ddb79f','#e7d7bb','#6f5a44','tower','shield','armor','straight','chevron','steel','oaths'),
    'tifa': IdentityProfile('tifa','缇珐','齿轮匠匠','#976146','#f4bf72','#44404f','#e7c0a5','#b0633e','#f1bf6e','gear','hammer','smith','apron','bolt','copper','forge'),
    'ize': IdentityProfile('ize','伊泽','共鸣乐师','#6d5a96','#e8c988','#322f50','#edcfbd','#5e4f84','#cab3ef','note','lyre','bard','tail','treble','violet','city'),
    'xuanli': IdentityProfile('xuanli','玄璃','镜影剑舞','#a9b0cf','#f2e4eb','#343752','#efd7cc','#d9d8ef','#8d92cb','mirror','blade','dancer','ribbon','diamond','lilac','mirror'),
    'noe': IdentityProfile('noe','诺依','编年记录者','#6a86a8','#f3d8a4','#334157','#efd1bc','#90b4dd','#fbf4db','book','book','scribe','cape','page','azure','sanctum'),
    'visha': IdentityProfile('visha','维莎','星轨裁定','#705b93','#d9b6f1','#24263f','#ebd0c0','#5b3d7a','#d8c2f3','orb','scepter','judge','taper','sigil','amethyst','city'),
}

REGIONS = {
    'coast': {'sky':'#709ab0','horizon':'#f7c48b','ground':'#4f766b','detail':'#d6c790','shadow':'#213346'},
    'isles': {'sky':'#5a99b4','horizon':'#f0d8b5','ground':'#2d736f','detail':'#a9ebd2','shadow':'#1c4b5d'},
    'forge': {'sky':'#545164','horizon':'#ea9e69','ground':'#6b4d49','detail':'#f8bd77','shadow':'#2b2333'},
    'mirror': {'sky':'#8096b9','horizon':'#f1d4dc','ground':'#53667f','detail':'#c3d8f0','shadow':'#272d48'},
    'city': {'sky':'#717ea3','horizon':'#eed9ba','ground':'#6d6d79','detail':'#e7d0a0','shadow':'#293246'},
    'oaths': {'sky':'#7f8697','horizon':'#f0cda4','ground':'#69655f','detail':'#e6c28d','shadow':'#353742'},
    'sanctum': {'sky':'#6178a1','horizon':'#ead6e9','ground':'#51648d','detail':'#f5e2b4','shadow':'#202940'},
}


def rgb(c: str):
    c = c.lstrip('#')
    return tuple(int(c[i:i+2],16) for i in (0,2,4))

def rgba(c, a=255):
    if isinstance(c, str):
        return (*rgb(c), a)
    if len(c)==4:
        return c
    return (*c, a)

def mix(a,b,t):
    a = rgb(a) if isinstance(a,str) else a
    b = rgb(b) if isinstance(b,str) else b
    return tuple(round((1-t)*x+t*y) for x,y in zip(a,b))

def save_png(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix('.tmp.png')
    img.save(tmp, 'PNG', optimize=True)
    with Image.open(tmp) as check:
        check.verify()
    tmp.replace(path)

def sha256(path: Path):
    return sha256_file(path)

def gradient(size, top, bottom):
    im = Image.new('RGBA', size)
    d = ImageDraw.Draw(im)
    w,h=size
    for y in range(h):
        t = y/max(1,h-1)
        t = 0.5 - 0.5*math.cos(math.pi*t)
        d.line((0,y,w,y), fill=(*mix(top,bottom,t),255))
    return im

def soft_light(im, center, radius, color, alpha=160):
    overlay = Image.new('RGBA', im.size, (0,0,0,0))
    d = ImageDraw.Draw(overlay)
    cx,cy=center
    for r in range(radius, 0, -9):
        a = int(alpha * (r/radius)**2 * 0.18)
        d.ellipse((cx-r,cy-r,cx+r,cy+r), fill=(*rgb(color), a))
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius//8))
    return Image.alpha_composite(im, overlay)

def add_painterly_noise(im, seed=1, amount=16):
    rnd=random.Random(seed)
    out=im.copy(); d=ImageDraw.Draw(out,'RGBA')
    w,h=out.size
    for _ in range(amount*w*h//120000):
        x=rnd.randrange(w); y=rnd.randrange(h); r=rnd.randrange(4,11)
        col = (255,255,255,rnd.randrange(3,8)) if rnd.random()<0.55 else (20,28,36,rnd.randrange(2,7))
        d.ellipse((x-r,y-r,x+r,y+r), fill=col)
    return out.filter(ImageFilter.GaussianBlur(0.35))

def draw_house(d, x,y, scale, roof, wall, light, seed):
    rnd=random.Random(seed)
    w=int(170*scale); h=int(110*scale)
    d.ellipse((x-12,y+h-6,x+w+20,y+h+16), fill=(10,20,26,55))
    d.polygon([(x+8,y+16),(x+w-10,y+12),(x+w,y+h),(x,y+h)], fill=rgba(wall))
    d.polygon([(x-20,y+18),(x+w//2,y-int(48*scale)),(x+w+20,y+18)], fill=rgba(mix(roof,'#162533',0.35)))
    d.polygon([(x-14,y+10),(x+w//2,y-int(42*scale)),(x+w+14,y+12)], fill=rgba(roof))
    d.line((x-12,y+12,x+w+12,y+12), fill=(240,210,160,220), width=max(2,int(scale*2)))
    # door
    d.rounded_rectangle((x+int(w*0.43),y+int(h*0.55),x+int(w*0.58),y+h), radius=int(6*scale), fill=(55,53,60,255), outline=(32,28,36,255), width=max(1,int(scale)))
    # windows
    for wy in range(y+24, y+int(h*0.54), max(22,int(28*scale))):
        for wx in range(x+14, x+w-20, max(22,int(28*scale))):
            if rnd.random()<0.86:
                d.rectangle((wx,wy,wx+int(11*scale),wy+int(14*scale)), fill=(32,38,44,255), outline=(208,177,127,255), width=1)
                d.rectangle((wx+2,wy+2,wx+int(9*scale),wy+int(12*scale)), fill=light)
    # shingles
    for row in range(6):
        yy = y+5+row*int(6*scale)
        for xx in range(x-7 + (row%2)*int(8*scale), x+w+12, int(16*scale)):
            d.arc((xx,yy,xx+int(16*scale),yy+int(10*scale)),180,360,fill=(170,130,125,80), width=1)

def draw_tree(d, x,y,r, seed, primary, secondary):
    rnd=random.Random(seed)
    d.ellipse((x-r*0.5,y-6,x+r*0.6,y+13), fill=(18,28,33,60))
    d.line((x,y-38,x+5,y-r*1.45), fill=(88,62,49,255), width=max(3,int(r*0.16)))
    for _ in range(16):
        dx=rnd.uniform(-1.0,1.0)*r; dy=rnd.uniform(-1.65,-0.6)*r; rr=rnd.uniform(0.38,0.8)*r
        fill = mix(primary, secondary, rnd.random()*0.45)
        d.ellipse((x+dx-rr,y+dy-rr,x+dx+rr,y+dy+rr), fill=(*fill,255))
    for _ in range(18):
        dx=rnd.uniform(-1.2,1.2)*r; dy=rnd.uniform(-1.8,-0.9)*r
        d.ellipse((x+dx,y+dy,x+dx+5,y+dy+3), fill=(220,230,180,80))

def sea(d, w,h, seed):
    rnd=random.Random(seed)
    d.polygon([(0,340),(w,315),(w,h),(0,h)], fill=(46,101,112,255))
    for layer in range(6):
        for _ in range(80):
            x=rnd.randrange(w); y=rnd.randrange(340,h); ww=rnd.randrange(12,84)
            shade=(127,202,198,38+layer*5) if y%4<2 else (248,216,170,28)
            d.arc((x,y,x+ww,y+8),0,180,fill=shade,width=1)

def scene(name, region, seed=20261101, size=(1280,720)):
    R=REGIONS[region]; rnd=random.Random(seed+sum(map(ord,name))); w,h=size
    out = gradient(size, R['sky'], R['horizon'])
    d = ImageDraw.Draw(out,'RGBA')
    # celestial lighting
    sunx = 230 if name=='tavern' else 985
    d.ellipse((sunx-110,88,sunx+110,308), fill=(255,226,175,28))
    d.ellipse((sunx-46,158,sunx+46,250), fill=(255,243,200,108))
    # distant mountains
    for idx,(base,amp,col) in enumerate([(302,54,mix(R['shadow'],R['sky'],0.42)),(350,38,mix(R['shadow'],R['sky'],0.55))]):
        pts=[(-20,h)]
        for x in range(-20,w+80,54):
            y=base+amp*(0.55*math.sin((x+idx*13)*0.011)+0.44*math.cos((x+idx*17)*0.021)+rnd.uniform(-0.27,0.27))
            pts.append((x,round(y)))
        pts.extend([(w+60,h),(-20,h)])
        d.polygon(pts, fill=(*col,255))
    # clouds
    for _ in range(11):
        x=rnd.randrange(w); y=rnd.randrange(48,220); scale=rnd.uniform(.55,1.35)
        for dx,dy,rx,ry in [(-55,5,56,14),(-25,-7,55,22),(25,-2,56,21),(67,7,42,11)]:
            d.ellipse((x+dx*scale-rx*scale,y+dy*scale-ry*scale,x+dx*scale+rx*scale,y+dy*scale+ry*scale), fill=(251,239,213,28))
    if name=='morning_dew':
        d.polygon([(0,436),(w,450),(w,h),(0,h)], fill=(72,102,88,255))
        d.polygon([(440,h),(596,458),(712,458),(870,h)], fill=(183,154,115,255))
        d.polygon([(510,h),(600,466),(644,466),(689,h)], fill=(213,187,144,118))
        # houses with unique roofs
        draw_house(d,100,355,1.14,'#6f5965','#e1bb8f',(248,202,116,255),101)
        draw_house(d,395,354,1.08,'#46576e','#d1bb91',(237,194,104,255),102)
        draw_house(d,705,348,1.12,'#825d43','#d9bf8d',(247,191,110,255),103)
        draw_house(d,912,317,0.97,'#81635a','#d4b697',(252,212,134,255),104)
        for x,y,r,s in ((48,486,66,1),(306,497,52,2),(672,492,56,3),(1120,481,74,4)):
            draw_tree(d,x,y,r,s,'#557c63','#2e5147')
        d.line((617,420,617,554), fill=(60,66,74,255), width=10)
        d.ellipse((589,391,644,448), fill=(230,182,99,220), outline=(57,69,76,255), width=6)
        d.ellipse((600,402,633,436), fill=(255,230,160,230))
        d.line((590,396,642,396), fill=(58,66,70,255), width=7)
        out = soft_light(out,(618,423),240,'#ffca8f',190)
        out = soft_light(out,(968,278),310,'#efd2a3',110)
    elif name=='tavern':
        d.polygon([(0,473),(w,430),(w,h),(0,h)], fill=(73,73,68,255))
        draw_house(d,240,315,3.28,'#425064','#bda17b',(241,188,101,255),148)
        d.polygon([(236,364),(523,210),(818,363)], fill=(44,53,68,255))
        d.polygon([(371,334),(471,267),(579,334)], fill=(77,89,106,255))
        # black sail emblem
        d.polygon([(675,302),(715,279),(755,302),(755,330),(675,330)], fill=(29,39,59,255))
        d.arc((688,283,742,327),14,166,fill=(246,210,142,255),width=4)
        for xx in (350,796):
            d.line((xx,360,xx,446), fill=(55,48,46,255), width=5)
            d.ellipse((xx-22,424,xx+22,462), fill=(250,188,99,205), outline=(44,46,56,255), width=4)
        for x in (126,1020): draw_tree(d,x,570,55,x,'#4d6f61','#27453e')
        out = soft_light(out,(710,478),210,'#f2b579',180)
        out = soft_light(out,(345,441),162,'#ffd39c',150)
    else:  # shallow
        sea(d,w,h,seed)
        d.polygon([(0,379),(115,346),(232,389),(265,491),(201,571),(0,546)], fill=(47,79,83,255))
        d.polygon([(846,376),(1036,320),(w,355),(w,540),(919,487)], fill=(44,75,80,255))
        # lighthouse
        d.polygon([(995,351),(1040,212),(1068,212),(1115,366)], fill=(214,199,175,255))
        d.rectangle((1032,198,1074,224), fill=(57,73,90,255))
        d.ellipse((1040,193,1068,223), fill=(255,222,160,218))
        d.polygon([(0,552),(332,530),(508,575),(659,548),(w,584),(w,h),(0,h)], fill=(211,180,138,255))
        for x,y in ((94,545),(354,588),(727,600),(982,621)):
            d.ellipse((x-36,y-16,x+38,y+12), fill=(70,88,87,255))
            d.arc((x-38,y-18,x+38,y+14),200,332, fill=(172,194,182,220), width=3)
        out = soft_light(out,(941,273),188,'#ead9b3',170)
    out = add_painterly_noise(out, seed, amount=6)
    # mist particles
    d=ImageDraw.Draw(out,'RGBA')
    for _ in range(130):
        x=rnd.randrange(w); y=rnd.randrange(160,h); r=rnd.randint(1,2)
        d.ellipse((x-r,y-r,x+r,y+r), fill=(248,224,167,rnd.randint(22,92)))
    return out.convert('RGB')


def _body_points(body: str, S:int, cx:int, bottom:int):
    if body=='armor':
        return [(cx-13*S,bottom-44*S),(cx+13*S,bottom-44*S),(cx+16*S,bottom-15*S),(cx+8*S,bottom-8*S),(cx-9*S,bottom-10*S),(cx-14*S,bottom-15*S)]
    if body=='robe':
        return [(cx-12*S,bottom-45*S),(cx+12*S,bottom-45*S),(cx+19*S,bottom-8*S),(cx-19*S,bottom-8*S)]
    if body=='ranger':
        return [(cx-13*S,bottom-44*S),(cx+13*S,bottom-44*S),(cx+10*S,bottom-16*S),(cx+17*S,bottom-7*S),(cx-10*S,bottom-10*S),(cx-15*S,bottom-17*S)]
    if body=='smith':
        return [(cx-12*S,bottom-43*S),(cx+12*S,bottom-43*S),(cx+14*S,bottom-10*S),(cx-14*S,bottom-10*S)]
    if body=='bard':
        return [(cx-12*S,bottom-44*S),(cx+12*S,bottom-44*S),(cx+15*S,bottom-12*S),(cx+6*S,bottom-7*S),(cx-16*S,bottom-10*S)]
    if body=='dancer':
        return [(cx-11*S,bottom-43*S),(cx+11*S,bottom-43*S),(cx+18*S,bottom-11*S),(cx,bottom-5*S),(cx-18*S,bottom-11*S)]
    if body=='scribe':
        return [(cx-12*S,bottom-45*S),(cx+12*S,bottom-45*S),(cx+15*S,bottom-11*S),(cx+8*S,bottom-7*S),(cx-13*S,bottom-9*S)]
    if body=='judge':
        return [(cx-11*S,bottom-45*S),(cx+11*S,bottom-45*S),(cx+16*S,bottom-11*S),(cx+5*S,bottom-7*S),(cx-15*S,bottom-11*S)]
    return [(cx-13*S,bottom-44*S),(cx+13*S,bottom-44*S),(cx+14*S,bottom-10*S),(cx-14*S,bottom-10*S)]

def draw_hair(d, p: IdentityProfile, S:int, cx:int, y:int, facing:str):
    dark=rgba(mix(p.hair,'#121724',0.25))
    base=rgba(p.hair)
    shine=rgba(p.hair2,190)
    if p.body=='dancer':
        d.pieslice((cx-12*S,y-6*S,cx+12*S,y+12*S),180,360,fill=dark)
        d.polygon([(cx-11*S,y+1*S),(cx-17*S,y+10*S),(cx-9*S,y+26*S),(cx-3*S,y+8*S)], fill=base)
        d.polygon([(cx+11*S,y+1*S),(cx+18*S,y+10*S),(cx+8*S,y+27*S),(cx+2*S,y+8*S)], fill=base)
        d.ellipse((cx-4*S,y+1*S,cx+4*S,y+8*S), fill=shine)
    elif p.body=='scribe':
        d.pieslice((cx-12*S,y-7*S,cx+13*S,y+13*S),180,360,fill=dark)
        d.rounded_rectangle((cx-11*S,y+2*S,cx+10*S,y+11*S), radius=3*S, fill=base)
        d.rectangle((cx+9*S,y+4*S,cx+13*S,y+26*S), fill=shine)
    elif p.body=='armor':
        d.pieslice((cx-11*S,y-7*S,cx+11*S,y+12*S),180,360,fill=dark)
        d.polygon([(cx-9*S,y+4*S),(cx+9*S,y+3*S),(cx+7*S,y+11*S),(cx-7*S,y+11*S)], fill=base)
        d.polygon([(cx,y-4*S),(cx+7*S,y+4*S),(cx+3*S,y+6*S)], fill=shine)
    elif p.body=='smith':
        d.pieslice((cx-12*S,y-6*S,cx+12*S,y+12*S),180,360,fill=dark)
        d.polygon([(cx-10*S,y+2*S),(cx+10*S,y+2*S),(cx+5*S,y+13*S),(cx-5*S,y+11*S)], fill=base)
        d.ellipse((cx-3*S,y+1*S,cx+3*S,y+6*S), fill=shine)
    elif p.body=='judge':
        d.pieslice((cx-13*S,y-7*S,cx+13*S,y+13*S),180,360,fill=dark)
        d.polygon([(cx-10*S,y+1*S),(cx+10*S,y+1*S),(cx+7*S,y+8*S),(cx-6*S,y+12*S)], fill=base)
        d.polygon([(cx-15*S,y+7*S),(cx-7*S,y+22*S),(cx-10*S,y+24*S)], fill=shine)
    elif p.body=='robe':
        d.pieslice((cx-12*S,y-7*S,cx+12*S,y+13*S),180,360,fill=dark)
        d.polygon([(cx-10*S,y+1*S),(cx+10*S,y+1*S),(cx+8*S,y+11*S),(cx-8*S,y+12*S)], fill=base)
        d.ellipse((cx-4*S,y+1*S,cx+4*S,y+5*S), fill=shine)
    elif p.body=='ranger':
        d.pieslice((cx-12*S,y-7*S,cx+12*S,y+12*S),180,360,fill=dark)
        d.polygon([(cx-10*S,y+1*S),(cx+10*S,y+1*S),(cx+6*S,y+10*S),(cx-8*S,y+12*S)], fill=base)
        d.polygon([(cx+8*S,y+5*S),(cx+17*S,y+15*S),(cx+10*S,y+18*S)], fill=shine)
    else:
        d.pieslice((cx-12*S,y-7*S,cx+12*S,y+12*S),180,360,fill=dark)
        d.rounded_rectangle((cx-10*S,y+1*S,cx+10*S,y+11*S), radius=4*S, fill=base)
        d.ellipse((cx-5*S,y+1*S,cx+3*S,y+5*S), fill=shine)

def draw_gear(d, p: IdentityProfile, S:int, x:int, bottom:int, facing:str):
    # recognizable role-defining accessory
    if p.gear=='lantern':
        d.line((x,bottom-43*S,x,bottom-10*S), fill=(118,86,65,255), width=2*S)
        d.rounded_rectangle((x-5*S,bottom-46*S,x+5*S,bottom-36*S), radius=2*S, fill=rgba(p.secondary), outline=rgba(p.dark), width=max(1,S))
        d.line((x-4*S,bottom-41*S,x+4*S,bottom-41*S), fill=(255,236,170,255), width=S)
    elif p.gear=='staff':
        d.line((x,bottom-47*S,x,bottom-10*S), fill=(115,85,63,255), width=2*S)
        d.ellipse((x-6*S,bottom-53*S,x+6*S,bottom-41*S), fill=rgba(p.secondary), outline=rgba(p.dark), width=max(1,S))
        if p.motif=='halo':
            d.arc((x-9*S,bottom-57*S,x+9*S,bottom-39*S),0,360,fill=(228,255,224,255),width=max(1,S))
    elif p.gear=='bow':
        d.arc((x-11*S,bottom-50*S,x+11*S,bottom-16*S),-88,88, fill=rgba(p.secondary), width=2*S)
        d.line((x,bottom-50*S,x,bottom-16*S), fill=(235,221,190,255), width=S)
    elif p.gear=='shield':
        d.polygon([(x-8*S,bottom-38*S),(x+8*S,bottom-38*S),(x+6*S,bottom-24*S),(x,bottom-16*S),(x-6*S,bottom-24*S)], fill=rgba(p.secondary), outline=rgba(p.dark), width=max(1,S))
        d.line((x,bottom-34*S,x,bottom-20*S), fill=(255,249,230,140), width=S)
    elif p.gear=='hammer':
        d.line((x,bottom-39*S,x+6*S,bottom-12*S), fill=(102,80,67,255), width=2*S)
        d.rounded_rectangle((x-8*S,bottom-44*S,x+8*S,bottom-37*S), radius=2*S, fill=rgba(p.secondary), outline=rgba(p.dark), width=max(1,S))
    elif p.gear=='lyre':
        d.arc((x-8*S,bottom-46*S,x+8*S,bottom-22*S),180,360, fill=rgba(p.secondary), width=2*S)
        d.arc((x-8*S,bottom-46*S,x+8*S,bottom-22*S),0,180, fill=rgba(p.secondary), width=2*S)
        for dx in (-4*S,-1*S,2*S,5*S):
            d.line((x+dx,bottom-43*S,x+dx,bottom-25*S), fill=(247,241,226,220), width=1)
    elif p.gear=='blade':
        d.polygon([(x,bottom-16*S),(x+4*S,bottom-49*S),(x+6*S,bottom-49*S),(x+7*S,bottom-16*S)], fill=(219,232,238,255), outline=(94,114,133,255))
        d.rectangle((x-2*S,bottom-18*S,x+8*S,bottom-16*S), fill=rgba(p.secondary))
    elif p.gear=='book':
        d.rectangle((x-6*S,bottom-33*S,x+6*S,bottom-21*S), fill=rgba(p.secondary), outline=rgba(p.dark), width=max(1,S))
        d.line((x,bottom-33*S,x,bottom-21*S), fill=(255,241,210,160), width=1)
    elif p.gear=='scepter':
        d.line((x,bottom-47*S,x,bottom-11*S), fill=(117,84,63,255), width=2*S)
        d.ellipse((x-5*S,bottom-55*S,x+5*S,bottom-45*S), fill=rgba(p.secondary), outline=rgba(p.dark), width=max(1,S))
        d.arc((x-8*S,bottom-58*S,x+8*S,bottom-42*S),30,330,fill=(240,216,255,180),width=max(1,S))

def draw_crest(d, p: IdentityProfile, S:int, cx:int, y:int):
    sec=rgba(p.secondary)
    dark=rgba(p.dark)
    if p.crest=='star':
        pts=[(cx,y-3*S),(cx+3*S,y+4*S),(cx+10*S,y+4*S),(cx+5*S,y+8*S),(cx+7*S,y+15*S),(cx,y+11*S),(cx-7*S,y+15*S),(cx-5*S,y+8*S),(cx-10*S,y+4*S),(cx-3*S,y+4*S)]
        d.polygon(pts, fill=sec)
    elif p.crest=='cross':
        d.rectangle((cx-2*S,y,cx+2*S,y+13*S), fill=sec); d.rectangle((cx-7*S,y+5*S,cx+7*S,y+8*S), fill=sec)
    elif p.crest=='arrow':
        d.polygon([(cx,y),(cx+7*S,y+10*S),(cx+3*S,y+10*S),(cx+3*S,y+15*S),(cx-3*S,y+15*S),(cx-3*S,y+10*S),(cx-7*S,y+10*S)], fill=sec)
    elif p.crest=='chevron':
        d.polygon([(cx-9*S,y+2*S),(cx,y+13*S),(cx+9*S,y+2*S),(cx+6*S,y),(cx,y+8*S),(cx-6*S,y)], fill=sec)
    elif p.crest=='bolt':
        d.polygon([(cx-2*S,y),(cx+4*S,y),(cx,y+8*S),(cx+5*S,y+8*S),(cx-4*S,y+17*S),(cx-1*S,y+10*S),(cx-6*S,y+10*S)], fill=sec)
    elif p.crest=='treble':
        d.ellipse((cx-5*S,y,cx+5*S,y+9*S), outline=sec, width=max(1,S)); d.line((cx+2*S,y-3*S,cx+2*S,y+15*S), fill=sec, width=max(1,S))
    elif p.crest=='diamond':
        d.polygon([(cx,y),(cx+7*S,y+8*S),(cx,y+16*S),(cx-7*S,y+8*S)], fill=sec)
    elif p.crest=='page':
        d.rectangle((cx-6*S,y,cx+6*S,y+14*S), fill=sec, outline=dark, width=1); d.line((cx-2*S,y+3*S,cx+4*S,y+3*S), fill=dark, width=1)
    elif p.crest=='sigil':
        d.ellipse((cx-7*S,y,cx+7*S,y+14*S), outline=sec, width=max(1,S)); d.line((cx,y,cx,y+14*S), fill=sec, width=1); d.line((cx-7*S,y+7*S,cx+7*S,y+7*S), fill=sec, width=1)

def character_frame(p: IdentityProfile, direction:int, pose:int, scale=3, tw=32, th=48):
    S=scale; W,H=tw*S,th*S
    out=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(out,'RGBA')
    cx=W//2; bottom=H-6*S
    facing = DIRS[direction]
    walk = (-3,0,3)[pose]
    stride = abs(walk)
    # shadow
    d.ellipse((cx-15*S,bottom-6*S,cx+16*S,bottom+5*S), fill=(20,28,38,68))
    # legs
    for side in (-1,1):
        shift = walk*(1 if side==-1 else -1)
        x = cx + side*7*S + shift*S//2
        d.polygon([(x-4*S,bottom-24*S),(x+4*S,bottom-24*S),(x+4*S,bottom),(x-6*S,bottom)], fill=rgba(p.dark))
        d.rectangle((x-5*S,bottom-5*S,x+5*S,bottom), fill=rgba('#253149'))
    # cloak/tunic silhouette
    d.polygon(_body_points(p.body,S,cx,bottom), fill=rgba(p.primary))
    # hem variation
    if p.hem=='split':
        d.polygon([(cx-13*S,bottom-15*S),(cx-2*S,bottom-9*S),(cx-6*S,bottom-6*S)], fill=rgba(mix(p.primary,p.dark,0.3)))
        d.polygon([(cx+13*S,bottom-15*S),(cx+2*S,bottom-9*S),(cx+6*S,bottom-6*S)], fill=rgba(mix(p.primary,p.dark,0.28)))
    elif p.hem=='petal':
        for off in (-9*S,0,9*S): d.pieslice((cx+off-7*S,bottom-16*S,cx+off+7*S,bottom-2*S),0,180,fill=rgba(mix(p.primary,p.secondary,0.22)))
    elif p.hem=='angled':
        d.polygon([(cx-14*S,bottom-14*S),(cx+13*S,bottom-10*S),(cx+15*S,bottom-4*S),(cx-11*S,bottom-8*S)], fill=rgba(mix(p.primary,p.secondary,0.18)))
    elif p.hem=='apron':
        d.rounded_rectangle((cx-8*S,bottom-32*S,cx+8*S,bottom-5*S), radius=3*S, fill=rgba(mix(p.secondary,'#ffffff',0.12)))
    elif p.hem=='tail':
        d.polygon([(cx+8*S,bottom-13*S),(cx+18*S,bottom-7*S),(cx+6*S,bottom-2*S)], fill=rgba(mix(p.primary,p.secondary,0.24)))
    elif p.hem=='ribbon':
        d.polygon([(cx,bottom-14*S),(cx+14*S,bottom-7*S),(cx+2*S,bottom-3*S)], fill=rgba(p.secondary,190))
        d.polygon([(cx,bottom-14*S),(cx-14*S,bottom-7*S),(cx-2*S,bottom-3*S)], fill=rgba(p.secondary,190))
    elif p.hem=='cape':
        d.polygon([(cx-15*S,bottom-42*S),(cx+15*S,bottom-42*S),(cx+18*S,bottom-13*S),(cx-6*S,bottom-8*S),(cx-17*S,bottom-12*S)], fill=rgba(mix(p.primary,p.dark,0.35),230))
    elif p.hem=='taper':
        d.polygon([(cx-9*S,bottom-45*S),(cx+9*S,bottom-45*S),(cx+16*S,bottom-8*S),(cx,bottom-3*S),(cx-16*S,bottom-8*S)], fill=rgba(mix(p.primary,p.secondary,0.18)))
    # shoulders and accents
    for side in (-1,1):
        x=cx+side*12*S; dy=walk if side==-1 else -walk
        d.ellipse((x-5*S,bottom-(39+dy)*S,x+5*S,bottom-(23+dy)*S), fill=rgba(mix(p.primary,p.dark,0.15)))
        d.line((x,bottom-(31+dy)*S,x,bottom-(26+dy)*S), fill=rgba(p.secondary), width=2*S)
    # head/face
    head_x = cx + (-3*S if facing=='left' else 3*S if facing=='right' else 0)
    d.ellipse((head_x-8*S,bottom-61*S,head_x+8*S,bottom-44*S), fill=rgba(p.skin))
    draw_hair(d,p,S,head_x,bottom-62*S,facing)
    if facing=='back':
        d.polygon([(head_x-8*S,bottom-56*S),(head_x+8*S,bottom-56*S),(head_x+6*S,bottom-43*S),(head_x-7*S,bottom-43*S)], fill=rgba(mix(p.hair,'#16202e',0.35)))
    elif facing in ('left','right'):
        eye = head_x+(-5*S if facing=='left' else 5*S)
        d.ellipse((eye-1*S,bottom-53*S,eye+1*S,bottom-51*S), fill=(28,35,44,255))
    else:
        for dx in (-4,4): d.rectangle((head_x+(dx-1)*S,bottom-53*S,head_x+(dx+1)*S,bottom-52*S), fill=(34,44,55,255))
    # chest emblem
    draw_crest(d,p,S,cx,bottom-38*S)
    # motif / aura
    if p.motif=='halo':
        d.arc((cx-11*S,bottom-65*S,cx+11*S,bottom-47*S),0,360,fill=(220,255,236,160),width=max(1,S))
    elif p.motif=='orb':
        d.ellipse((cx+10*S,bottom-38*S,cx+17*S,bottom-31*S), fill=rgba(p.secondary,200))
    elif p.motif=='note':
        d.line((cx+12*S,bottom-53*S,cx+12*S,bottom-43*S), fill=rgba(p.secondary), width=1)
        d.ellipse((cx+8*S,bottom-44*S,cx+12*S,bottom-40*S), fill=rgba(p.secondary))
        d.ellipse((cx+12*S,bottom-41*S,cx+16*S,bottom-37*S), fill=rgba(p.secondary))
    elif p.motif=='gear':
        d.ellipse((cx-18*S,bottom-34*S,cx-10*S,bottom-26*S), outline=rgba(p.secondary,200), width=2)
        d.line((cx-14*S,bottom-35*S,cx-14*S,bottom-25*S), fill=rgba(p.secondary,200), width=1)
        d.line((cx-19*S,bottom-30*S,cx-9*S,bottom-30*S), fill=rgba(p.secondary,200), width=1)
    # role gear
    gx = cx + (17*S if facing!='left' else -17*S)
    draw_gear(d,p,S,gx,bottom,facing)
    # rim light
    d.line((cx-11*S,bottom-43*S,cx-8*S,bottom-11*S), fill=rgba(mix(p.secondary,'#fff0c0',0.35),110), width=S)
    return out

def character_sheet(cid:str, mode='runtime'):
    p=PROFILES[cid]
    tw,th=(80,112) if mode=='master' else (32,48)
    atlas=Image.new('RGBA',(tw*3,th*4),(0,0,0,0))
    for row in range(4):
        for col in range(3):
            raw = character_frame(p,row,col,scale=3,tw=32,th=48)
            tile = raw.resize((tw,th), Image.Resampling.LANCZOS if mode=='master' else Image.Resampling.NEAREST)
            atlas.paste(tile,(col*tw,row*th),tile)
    return atlas

def height_normal(im, strength=3.2):
    import numpy as np
    pix=np.asarray(im.convert('RGBA'),dtype=np.float32)
    a=pix[:,:,3]/255.0
    sm=Image.fromarray((a*255).astype('uint8'),'L').filter(ImageFilter.GaussianBlur(1.2))
    z=np.asarray(sm,dtype=np.float32)/255.0
    gy,gx=np.gradient(z)
    nx=np.clip(-gx*strength,-1,1); ny=np.clip(-gy*strength,-1,1)
    norm=np.sqrt(nx*nx+ny*ny+1)
    out=np.zeros_like(pix,dtype='uint8')
    out[:,:,0]=((nx/norm*0.5+0.5)*255).astype('uint8')
    out[:,:,1]=((ny/norm*0.5+0.5)*255).astype('uint8')
    out[:,:,2]=((1/norm*0.5+0.5)*255).astype('uint8')
    out[:,:,3]=(a*255).astype('uint8')
    return Image.fromarray(out,'RGBA')

def transparency_bbox(frame):
    alpha = frame.getchannel('A')
    return alpha.getbbox()

def qa_runtime(atlas):
    if atlas.size!=(96,192): raise ValueError(f'Runtime atlas must be 96x192, got {atlas.size}')
    frames=[]
    boxes=[]
    for row in range(4):
        for col in range(3):
            frame=atlas.crop((col*32,row*48,(col+1)*32,(row+1)*48)).convert('RGBA')
            bbox=transparency_bbox(frame)
            if bbox is None: raise ValueError(f'Empty frame {row},{col}')
            frames.append(hashlib.sha256(frame.tobytes()).hexdigest())
            boxes.append(bbox)
    if len(set(frames))<6: raise ValueError('Too many duplicated poses')
    return {'cells':12,'distinct_frames':len(set(frames)),'alpha':True,'boxes':boxes[:4]}

def image_signature(im):
    small=im.convert('RGBA').resize((24,24), Image.Resampling.BILINEAR)
    a=small.getchannel('A')
    b=a.point(lambda v: 255 if v>4 else 0)
    return b.tobytes()

def silhouette_distance(sig1: bytes, sig2: bytes):
    return sum(a!=b for a,b in zip(sig1,sig2))/len(sig1)

def palette_mean(im):
    import numpy as np
    arr = np.asarray(im.convert('RGBA'), dtype=np.float32)
    mask = arr[:,:,3] > 4
    if not mask.any():
        return (0.0, 0.0, 0.0)
    rgb = arr[:,:,:3][mask]
    mean = rgb.mean(axis=0)
    return tuple(float(x) for x in mean)

def color_distance(a,b):
    return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))/441.67

def audit_distinctiveness(runtime_files: Dict[str,Path]):
    sprites={cid: Image.open(path).convert('RGBA') for cid,path in runtime_files.items()}
    sig={cid:image_signature(im.crop((32,0,64,48))) for cid,im in sprites.items()}  # idle front frame
    pal={cid:palette_mean(im.crop((32,0,64,48))) for cid,im in sprites.items()}
    pairs=[]
    ids=list(runtime_files.keys())
    min_score=1.0
    for i in range(len(ids)):
        for j in range(i+1,len(ids)):
            a,b=ids[i],ids[j]
            sil=silhouette_distance(sig[a],sig[b])
            col=color_distance(pal[a],pal[b])
            gear = 1.0 if PROFILES[a].gear!=PROFILES[b].gear else 0.0
            body = 1.0 if PROFILES[a].body!=PROFILES[b].body else 0.0
            score = round(0.45*sil + 0.25*col + 0.15*gear + 0.15*body, 4)
            min_score=min(min_score,score)
            pairs.append({'a':a,'b':b,'silhouette':round(sil,4),'palette':round(col,4),'gear_diff':gear,'body_diff':body,'recognition_score':score})
    grades = []
    for cid in ids:
        others=[p['recognition_score'] for p in pairs if p['a']==cid or p['b']==cid]
        grades.append({'id':cid,'min_pair_score':round(min(others),4),'avg_pair_score':round(sum(others)/len(others),4),'identity':asdict(PROFILES[cid])})
    return {'schema':'starlit.hd2d.identity_audit.v1','pairwise':pairs,'characters':grades,'global_min_pair_score':round(min_score,4),'status':'成功' if min_score>=0.22 else '需提升'}

def draw_contact_sheet(out_dir: Path, scenes: Dict[str,Path], runtime_files: Dict[str,Path]):
    W,H=1700,1380
    sheet=Image.new('RGB',(W,H),rgb('#0f1a28'))
    d=ImageDraw.Draw(sheet)
    # title
    d.rounded_rectangle((18,18,W-18,104), radius=18, fill=(17,37,58))
    d.text((44,38), '《星灯纪行》HD-2D 美术生成器 V7 · 辨识度驱动升级版', fill=(239,233,220))
    d.text((46,70), '身份轮廓 + 职业器物 + 配色语言 + 地区审美 + 自动辨识度审计', fill=(199,214,226))
    # scenes
    order=['morning_dew','tavern','shallow']
    titles={'morning_dew':'晨露村','tavern':'黑帆酒馆','shallow':'浅滩'}
    x=20; y=126
    for idx,name in enumerate(order):
        with Image.open(scenes[name]) as im:
            thumb=im.resize((530,298), Image.Resampling.LANCZOS)
        bx = 20 + idx*556
        sheet.paste(thumb,(bx,y))
        d.rounded_rectangle((bx,y-34,bx+530,y-4), radius=10, fill=(18,45,72))
        d.text((bx+12,y-28), titles[name], fill=(235,225,200))
    # character strip
    y2=460
    d.rounded_rectangle((18,y2-38,W-18,y2-6), radius=10, fill=(18,45,72))
    d.text((30,y2-32),'九名主角（运行尺寸四方向图集 + 高清母稿缩略）', fill=(235,225,200))
    ids=list(PROFILES.keys())
    for i,cid in enumerate(ids):
        bx=22 + (i%3)*554
        by=y2 + (i//3)*286
        d.rounded_rectangle((bx,by,bx+538,by+252), radius=14, fill=(20,31,46))
        # master
        m=Image.open(out_dir/'characters'/f'{cid}_master.png').convert('RGBA').resize((168,235), Image.Resampling.NEAREST)
        checker=Image.new('RGB',m.size,(39,52,72)); cd=ImageDraw.Draw(checker)
        for yy in range(0,m.height,16):
            for xx in range(0,m.width,16):
                if (xx//16 + yy//16)%2: cd.rectangle((xx,yy,xx+15,yy+15), fill=(50,64,86))
        checker.paste(m,(0,0),m)
        sheet.paste(checker,(bx+12,by+10))
        # runtime preview
        rt=Image.open(out_dir/'characters'/f'{cid}_runtime.png').convert('RGBA').resize((252,252), Image.Resampling.NEAREST)
        bg=Image.new('RGB',rt.size,(28,37,54)); bg.paste(rt,(0,0),rt)
        sheet.paste(bg,(bx+194,by+6))
        p=PROFILES[cid]
        d.text((bx+12,by+218), f'{p.title} / {p.role}', fill=(236,225,196))
        d.text((bx+12,by+236), f'器物: {p.gear}  |  轮廓: {p.body}  |  地区: {p.region}', fill=(184,205,217))
    save_png(sheet, out_dir/'studio_contact_sheet_v7.png')
    return out_dir/'studio_contact_sheet_v7.png'

def demo(root: Path, out: Path):
    out.mkdir(parents=True, exist_ok=True)
    manifest={'schema':'starlit.hd2d.studio.v7','version':VERSION,'approval':'candidate_not_approved','assets':[],'runtime_modified':False,'style':'identity-driven painterly hd2d'}
    scenes={}
    for name,region in [('morning_dew','coast'),('tavern','coast'),('shallow','isles')]:
        im=scene(name,region)
        path=out/'scenes'/f'{name}.png'; save_png(im,path); scenes[name]=path
        manifest['assets'].append({'path':path.relative_to(out).as_posix(),'sha256':sha256(path),'kind':'scene','id':name,'bytes':path.stat().st_size,'qa':{'width':im.width,'height':im.height}})
    runtime_files={}
    for cid in PROFILES:
        master=character_sheet(cid,'master')
        runtime=character_sheet(cid,'runtime')
        normal=height_normal(runtime)
        for kind,im in [('master',master),('runtime',runtime),('normal',normal)]:
            path=out/'characters'/f'{cid}_{kind}.png'; save_png(im,path)
            qa={'width':im.width,'height':im.height}
            if kind=='runtime': qa.update(qa_runtime(im))
            manifest['assets'].append({'path':path.relative_to(out).as_posix(),'sha256':sha256(path),'kind':f'character_{kind}','id':cid,'bytes':path.stat().st_size,'qa':qa})
        runtime_files[cid]=out/'characters'/f'{cid}_runtime.png'
    audit=audit_distinctiveness(runtime_files)
    (out/'identity_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    manifest['identity_audit']={'global_min_pair_score':audit['global_min_pair_score'],'status':audit['status']}
    sheet = draw_contact_sheet(out, scenes, runtime_files)
    manifest['assets'].append({'path':sheet.relative_to(out).as_posix(),'sha256':sha256(sheet),'kind':'gallery','id':'contact_sheet_v7','bytes':sheet.stat().st_size,'qa':{'width':1700,'height':1380}})
    (out/'candidate_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    return manifest, audit

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--out', type=Path, default=Path(__file__).resolve().parents[1]/'build'/'starlit_hd2d_studio_v7')
    args=parser.parse_args()
    manifest,audit=demo(args.project.resolve(), args.out.resolve())
    print(json.dumps({'status':'成功','version':VERSION,'output':str(args.out),'assets':len(manifest['assets']),'identity_global_min_pair_score':audit['global_min_pair_score'],'identity_status':audit['status']}, ensure_ascii=False, indent=2))

if __name__=='__main__':
    main()