#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Starlit Chronicle HD-2D Studio V8: canonical-ID driven 2D candidate factory.

Features:
* canonical Main2 registry input instead of fabricated asset IDs;
* geometry-authored four-direction 12-cell cast with silhouette/gear/identity;
* semantic monster/Boss archetype classification with 4 poses and layered detail;
* 8-region motif, background and seam-safe texture atlases;
* purely visual pairwise distinctiveness audit (no metadata bonus);
* deterministic seeds, image verification, reproducible SHA256 manifest;
* no edits to runtime images, map collisions, rewards or saved games.

Offline art is *candidate/reference*, never passed off as studio-quality
model-painted production art or approved identity art. Source-locked AI editing
still requires an actual image model and manual visual review.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import random
import re
import sys
import os
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

from hd2d_studio_v7 import (rgb, mix, rgba, save_png, height_normal,
                            scene as legacy_scene)

VERSION = '8.0.0'
GROUPS = ('characters','monsters','bosses','regions')
CANONICAL = {'characters':12,'monsters':63,'bosses':66,'regions':8}
DIRECTIONS = ('front','left','back','right')
REGION_MOTIFS = {
 'coast':'waves', 'oaths':'banners', 'forge':'furnaces', 'isles':'sails',
 'mirror':'mirrors', 'oldland':'roots', 'sanctum':'rings', 'city':'lanterns',
}
CAST_ROLES = {
 'char_wayfarer':('wayfarer','lantern','cloak','star', '#315c77','#e9c68a','#203146'),
 'char_tidecaller':('healer','staff','robe','flower','#278a87','#cde7c6','#213f51'),
 'char_vanguard':('guardian','shield','armor','crest','#7e6c54','#e2c28a','#353a4a'),
 'char_seeker':('ranger','bow','split','wave','#496478','#dc9365','#26374d'),
 'char_smith':('artificer','hammer','apron','gear','#a06c4d','#f8c078','#443949'),
 'char_navigator':('bard','lyre','tails','music','#735d9b','#e7c588','#303050'),
 'char_mirrorweaver':('dancer','blade','ribbon','mirror','#a9afca','#ebe3f0','#35334b'),
 'char_alchemist':('scribe','book','cape','book','#64809a','#f0d39c','#333f58'),
 'char_cantor':('arbiter','scepter','taper','ring','#665086','#d9b5ea','#232644'),
 'char_chengzhou':('sailor','anchor','jacket','anchor','#397c87','#e9d49c','#254359'),
 'char_hessian':('scholar','scroll','longcoat','hourglass','#695674','#c7b69d','#2c3142'),
 'char_kuro':('commander','sword','coat','flame','#993e40','#f2b986','#282b38'),
}
MORPH = {
 # Chinese semantic anchors; order is critical and affects archetype selection.
 'cephalopod':['巨蛸','触手','章鱼'],
 'crab':['蟹','刺螯','空贝','寄居'],
 'serpent':['蛇','巨鳗','海蛇','岩蛇'],
 'moth':['蝶','蛾','蝠','蜂'],
 'avian':['鸟','鹰','羽灵'],
 'fish':['鳐','鱼群','海歌'],
 'canine':['狼','猎犬','石犬','捕食','窃光兽'],
 'lizard':['蜥','巨蜥'],
 'insect':['蚁狮','蚂蚁','甲虫','矿螳','螳螂','蚁','蛛'],
 'floral':['蔓藤','缠根','园丁','根忆','迷梦菇','菇'],
 'mechanical':['机械','机关','机兵','采矿机','巨机','战舰','熔炉','齿','星阵','算偶','主力机','搬运偶'],
 'golem':['傀儡','石','岩','碎碑','偶'],
 'ghost':['魂','灵','幻','影','残响','幽','怨','梦','意志','残音','迷雾'],
 'knight':['守卫','队长','将军','裁决','判官','监守','监察','执刑','禁卫','骑','追猎','执剑','游者','巡者','使者','守门人','门卫'],
 'beast':['兽','鹿','狮','鼠','古兽','异兽'],
}

def seed(*parts):
    return int.from_bytes(hashlib.sha256('|'.join(map(str,parts)).encode()).digest()[:8],'big')

def safe_id(name):
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,90}',str(name)):
        raise ValueError('Unsafe canonical asset ID: '+str(name))
    return str(name)

def classify(name:str):
    for kind,words in MORPH.items():
        if any(w in name for w in words):return kind
    return 'arcane'

def color_layers(region):
    colors=region['style']['palette']
    return tuple(rgb(c) for c in colors[:3])

def _rgba(c,a=255):return (*c[:3],a)

def _shade(c,alpha):return mix(c,(255,255,240) if alpha>=0 else (16,22,35),abs(alpha))

def draw_character_tile(role, cid, direction, pose, at_scale=4):
    # Unlike V7, coordinates here are native 32x48, so the head fits the cell.
    style,gear,hem,crest,primary,accent,dark=role
    w,h=32,48;s=at_scale
    im=Image.new('RGBA',(w*s,h*s),(0,0,0,0))
    d=ImageDraw.Draw(im,'RGBA')
    rnd=random.Random(seed('cast',cid,direction,pose))
    color=rgb(primary);metal=rgb(accent);shadow=rgb(dark)
    skin=(235,195,167);hair=_shade(shadow,0.13)
    # Different silhouettes deliberately change headgear, shoulder width and coat hem.
    broad={'armor':12,'apron':10,'jacket':9,'coat':9,'cloak':8}.get(hem,8)
    swing=(-2,0,2)[pose]
    turn=(-2 if direction==1 else 2 if direction==3 else 0)
    def poly(pts,fill, outline=None, width=1):
        d.polygon([(int(x*s),int(y*s)) for x,y in pts],fill=_rgba(fill))
        if outline:d.line([(int(x*s),int(y*s)) for x,y in pts+[pts[0]]],fill=_rgba(outline),width=max(1,width*s),joint='curve')
    def ell(box,fill,outline=None,width=1):
        d.ellipse(tuple(int(x*s) for x in box),fill=_rgba(fill),outline=_rgba(outline) if outline else None,width=max(1,width*s))
    def lin(pts,c,width=1):d.line([(int(x*s),int(y*s)) for x,y in pts],fill=_rgba(c),width=max(1,width*s),joint='curve')
    def rect(box,fill):d.rectangle(tuple(int(x*s) for x in box), fill=_rgba(fill))
    # Tiny contact shadow, fully inside bottom margin.
    ell((6,43,26,46),(20,27,37,47))
    # Distinct walk phase and asymmetric foot placement.
    for sign in (-1,1):
        x=16+sign*4 + (-swing if sign==-1 else swing)
        poly([(x-3,32),(x+2,32),(x+3,42),(x-2,42)], _shade(shadow,0.05))
        rect((x-4,41,x+3,44),shadow)
        lin([(x-2,41),(x+2,41)],_shade(shadow,0.28))
    # garment shape, not simple template recolor.
    if hem=='armor':
        pts=[(16-broad,19),(16+broad,19),(16+broad,33),(23,37),(9,37),(16-broad,33)]
    elif hem in ('robe','ribbon','taper'):
        pts=[(7,19),(25,19),(25+rnd.choice((1,2)),36),(27,42),(5,42),(7,36)]
    elif hem=='tails':
        pts=[(8,19),(24,19),(23,35),(28,43),(18,40),(7,43),(9,36)]
    elif hem=='cape':
        pts=[(7,19),(25,19),(26,38),(22,41),(6,38)]
    elif hem=='split':
        pts=[(8,19),(24,19),(23,34),(27,41),(16,36),(6,41),(9,34)]
    else: pts=[(16-broad,19),(16+broad,19),(25,37),(22,39),(9,39),(7,37)]
    poly(pts,color,shadow,1)
    # Material folds and gradient-like painterly details.
    lin([(12,21),(10,34),(12,37)],_shade(color,-0.22))
    lin([(20,21),(23,33),(21,37)],_shade(color,0.25))
    poly([(13,19),(20,19),(18,29),(14,29)],_shade(color,0.17))
    if hem=='apron':
        poly([(12,24),(21,24),(22,39),(10,39)],_shade(metal,-0.1),_shade(shadow,0.1))
        rect((12,29,20,30),_shade(shadow,0.2))
    if hem=='armor':
        for x in (7,20):
            rect((x,20,x+6,25),_shade(metal,0.1))
            lin([(x,20),(x+6,20)],_shade(metal,0.48))
        poly([(11,26),(21,26),(19,33),(13,33)],_shade(shadow,-0.05))
    if hem=='ribbon':
        lin([(8,25),(3,39),(10,37)],_shade(metal,0.24),2)
        lin([(24,24),(29,40),(23,38)],_shade(metal,0.24),2)
    if hem=='cloak':
        poly([(8,21),(12,20),(9,37),(4,41)],_shade(color,-0.24))
    if hem=='coat':
        rect((10,24,12,38),_shade(metal,-0.2))
    if hem=='jacket':
        rect((8,28,24,30),_shade(shadow,0.2))
    # arms, one up one down, different for facing.
    arm1 = 18 if direction==2 else 20
    ell((5,arm1,11,32+swing//2),_shade(color,-0.1),shadow)
    ell((22,arm1,28,32-swing//2),_shade(color,-0.1),shadow)
    lin([(6,29),(9,29)],_shade(metal,0.18))
    lin([(23,29),(26,29)],_shade(metal,0.18))
    # Head located at y=6..19: fixes V7 clipped head and silhouette collapse.
    head_x=16+turn
    ell((head_x-6,7,head_x+6,21),skin,_shade(shadow,0.08))
    # hair and headgear are identity-specific
    if cid in ('char_vanguard','char_kuro'):
        poly([(head_x-8,8),(head_x-6,4),(head_x+6,4),(head_x+8,8),(head_x+6,13),(head_x-6,13)],_shade(metal,-0.2),shadow)
        lin([(head_x,5),(head_x,13)],_shade(metal,0.4),2)
    elif cid=='char_mirrorweaver':
        ell((head_x-8,3,head_x+8,16),hair)
        poly([(head_x-9,9),(head_x-5,12),(head_x-12,26),(head_x-14,20)],hair)
        poly([(head_x+9,9),(head_x+5,12),(head_x+12,27),(head_x+14,20)],hair)
        lin([(head_x-8,7),(head_x+8,6)],_shade(metal,0.42),2)
    elif cid=='char_tidecaller':
        ell((head_x-8,4,head_x+8,16),_shade(hair,0.12))
        poly([(head_x-8,10),(head_x-3,15),(head_x-6,24),(head_x-11,18)],hair)
        lin([(head_x-6,10),(head_x+6,10)],_shade(metal,0.44))
    elif cid=='char_smith':
        ell((head_x-8,4,head_x+8,15),_shade(hair,0.06))
        poly([(head_x-7,5),(head_x+8,6),(head_x+4,11),(head_x-9,11)],hair)
        lin([(head_x-7,5),(head_x+8,5)],_shade(metal,0.16),2)
    elif cid=='char_hessian':
        ell((head_x-8,4,head_x+8,16),hair)
        poly([(head_x-7,5),(head_x+7,5),(head_x+9,11),(head_x-9,11)],_shade(color,-0.2))
        lin([(head_x-4,18),(head_x+4,18)],shadow)
    else:
        ell((head_x-8,3,head_x+8,15),hair)
        poly([(head_x-7,4),(head_x+7,4),(head_x+5,12),(head_x-7,12)],_shade(hair,0.12))
        lin([(head_x-6,6),(head_x+5,5)],_shade(color,0.2))
    if direction==2:
        poly([(head_x-6,12),(head_x+6,12),(head_x+5,20),(head_x-5,20)],_shade(hair,-0.2))
    elif direction==0:
        for x in (-3,3):rect((head_x+x,16,head_x+x+1,17),shadow)
    elif direction==1:rect((head_x-5,16,head_x-4,17),shadow)
    else:rect((head_x+4,16,head_x+5,17),shadow)
    # Chest badge: a tiny unique accent silhouette.
    if crest in ('star','flower','mirror','ring'):
        ell((13,26,19,31),_shade(metal,0.18),shadow)
    elif crest=='flame':poly([(16,23),(19,30),(16,29),(14,32),(13,28)],metal)
    elif crest=='gear':ell((12,25,20,33),_shade(metal,-0.1));ell((15,28,17,30),shadow)
    else:lin([(13,27),(16,30),(19,27)],metal,2)
    # Career equipment, scaled to frame and not identical among roles.
    fx=27 if direction!=1 else 5
    if gear in ('lantern','staff','scepter'):
        lin([(fx,15),(fx,39)],_shade(metal,-0.4),2)
        if gear=='lantern':
            rect((fx-4,17,fx+4,25),metal)
            rect((fx-2,19,fx+2,23),_shade(metal,0.65))
            lin([(fx-3,16),(fx+3,16)],_shade(metal,-0.2))
        elif gear=='staff':
            ell((fx-4,10,fx+4,19),_shade(metal,0.1),shadow)
            lin([(fx-3,11),(fx+3,18)],_shade(metal,0.5))
        else:
            ell((fx-5,9,fx+5,19),_shade(metal,0.12),shadow)
            lin([(fx-5,13),(fx+5,13)],_shade(metal,0.5))
    elif gear=='shield':
        poly([(fx-5,24),(fx+5,24),(fx+4,34),(fx,39),(fx-4,34)],metal,shadow)
        lin([(fx,26),(fx,36)],_shade(metal,0.45))
    elif gear=='bow':
        d.arc(tuple(int(v*s) for v in (fx-5,13,fx+6,37)),60,300,fill=_rgba(metal),width=2*s)
        lin([(fx,14),(fx,36)],_shade(metal,0.45))
    elif gear=='hammer':
        lin([(fx-2,19),(fx+2,37)],_shade(metal,-0.4),2)
        rect((fx-6,16,fx+5,22),_shade(metal,0.15))
    elif gear=='lyre':
        d.arc(tuple(int(v*s) for v in (fx-5,20,fx+5,37)),0,350,fill=_rgba(metal),width=2*s)
        for xx in (-2,0,2):lin([(fx+xx,24),(fx+xx,34)],_shade(metal,0.54))
    elif gear in ('blade','sword'):
        poly([(fx-2,35),(fx-1,15),(fx+1,12),(fx+3,35)],_shade(metal,0.44))
        lin([(fx-4,34),(fx+5,34)],shadow,2)
    elif gear in ('book','scroll'):
        rect((fx-5,25,fx+4,35),metal)
        lin([(fx,26),(fx,34)],shadow)
    elif gear=='anchor':
        lin([(fx,17),(fx,38)],metal,2)
        d.arc(tuple(int(v*s) for v in (fx-6,30,fx+6,41)),0,180,fill=_rgba(metal),width=2*s)
    # rim and tiny stitchwork
    lin([(10,23),(9,32)],_shade(metal,0.35),1)
    lin([(21,23),(23,32)],_shade(color,0.4),1)
    return im.resize((32,48),Image.Resampling.LANCZOS)

def character_sheet(cid):
    atlas=Image.new('RGBA',(96,192),(0,0,0,0))
    for row in range(4):
        for col in range(3):
            im=draw_character_tile(CAST_ROLES[cid],cid,row,col)
            atlas.paste(im,(col*32,row*48))
    return atlas

def creature_parameters(asset, region, category='monster', variant=0):
    name=asset['name']; id=safe_id(asset['id'])
    kind=classify(name)
    P=color_layers(region)
    RNG=random.Random(seed(id,'creature',variant))
    hue=RNG.uniform(0.18,0.58)
    base=mix(P[0],P[1],hue)
    glow=mix(P[2],(255,237,195),RNG.uniform(.20,.65))
    dark=mix(P[1],(13,22,38),.68)
    # Fixed identity, motion-independent; never randomize morphology per frame.
    traits={'id':id,'name':name,'kind':kind,'region_id':region['id'],'primary':base,
            'accent':glow,'dark':dark,'horns':RNG.randint(0,3),
            'crown':RNG.choice(('crest','spines','plumes')),
            'eye_count':RNG.choice((1,2,3)), 'body_ratio':round(RNG.uniform(.82,1.25),3),
            'limbs':RNG.choice((2,4,6)), 'markings':RNG.choice(('stripe','spots','runes')),
            'complexity': 'boss' if category=='boss' else 'monster', 'variant':variant}
    return traits

def draw_creature_frame(t, phase=0, size=128):
    # A dozen independently authored morphology families. Shape seeds stay
    # stable across the four frames, animation changes posture only.
    W=H=size; out=Image.new('RGBA',(W,H),(0,0,0,0));d=ImageDraw.Draw(out,'RGBA')
    kind=t['kind'];cx=64;cy=68+(phase%2)*2
    big=t['complexity']=='boss'; ratio=t['body_ratio']*(1.13 if big else 1.0)
    base=t['primary'];accent=t['accent'];dark=t['dark'];r=random.Random(seed(t['id'],'shape',t.get('variant',0)))
    def P(points,fill,outline=dark,width=2):
        d.polygon(points,fill=_rgba(fill))
        if outline:d.line(points+[points[0]],fill=_rgba(outline),width=width,joint='curve')
    def E(box,fill,outline=dark,width=2):d.ellipse(box,fill=_rgba(fill),outline=_rgba(outline) if outline else None,width=width)
    def L(points,col,width=2):d.line(points,fill=_rgba(col),width=width,joint='curve')
    # Under-body shadow and painted rim.
    d.ellipse((22,112,106,119),fill=(14,24,39,52))
    if kind=='cephalopod':
        for j in range(7):
            start=(cx-5+j*2,75)
            end=(15+j*15,105-(j%3)*9+(phase%2)*4)
            d.arc((min(start[0],end[0]),55,max(start[0],end[0])+8,115),j*22,j*22+130,fill=_rgba(dark),width=10)
            L([start,((start[0]+end[0])//2,98),end],base,7)
        E((34,22,97,89),base)
        for j in range(5):E((48+j*9,35,54+j*9,41),_shade(base,.22),None)
    elif kind in ('crab','insect'):
        for side in (-1,1):
            for j in range(3):
                end=(cx+side*(41+j*7),80+j*11+(phase%2)*3)
                L([(cx+side*26,69+j*5),(cx+side*(37+j*3),71+j*7),end],dark,7)
                L([(cx+side*26,69+j*5),end],accent,3)
        E((31,46,97,98),base)
        if kind=='crab':
            for side in (-1,1):
                end=(cx+side*(47+(phase%2)*4),37)
                L([(cx+side*27,61),end],dark,9)
                P([(end[0]-9,28),(end[0]+7,22),(end[0]+8,43)],accent)
        else:
            for side in (-1,1):P([(cx+side*8,47),(cx+side*21,19),(cx+side*14,48)],_shade(base,.25))
    elif kind in ('serpent','fish'):
        pts=[]
        for i in range(15):
            x=17+i*7
            y=70 + 17*math.sin(i*.56+phase*.24)
            pts.append((x,round(y)))
        L(pts,dark,24);L(pts,base,19);L(pts,accent,5)
        E((80,43,117,78),base)
        if kind=='fish':
            P([(15,72),(3,43),(6,105)],_shade(base,.22))
            P([(40,65),(56,33),(72,69)],_shade(accent,.05))
        else:
            P([(42,72),(56,43),(64,67)],_shade(base,.25))
    elif kind in ('avian','moth'):
        wing=(phase%2)*9
        P([(60,67),(19,25+wing),(8,65),(49,91)],base)
        P([(68,67),(109,25+wing),(121,65),(79,91)],base)
        P([(56,75),(26,48+wing),(38,96)],accent)
        P([(72,75),(102,48+wing),(90,96)],accent)
        E((48,54,80,101),_shade(base,-.15))
        if kind=='avian':
            P([(60,50),(86,57),(66,65)],accent)
            for j in range(4): L([(30+j*4,53+wing),(48,84)],dark,2)
        else:
            for side in (-1,1):
                E((cx+side*27-6,46+wing,cx+side*27+6,58+wing),_shade(accent,.35),None)
            L([(61,55),(50,37)],dark,3);L([(67,55),(77,37)],dark,3)
    elif kind=='canine' or kind=='beast':
        P([(27,73),(39,50),(69,47),(95,58),(104,86),(84,94),(44,92)],base)
        P([(30,68),(17,43),(22,90)],_shade(base,.12))
        for x in (43,80):
            P([(x,87),(x+14,87),(x+12,111),(x+3,111)],_shade(base,-.25))
        P([(78,55),(93,31),(107,49),(104,81),(78,85)],_shade(base,.1))
        P([(88,48),(96,27),(100,49)],accent)
        P([(100,47),(112,29),(113,59)],accent)
        P([(104,70),(123,75),(111,84)],_shade(base,-.25))
    elif kind=='lizard':
        P([(32,76),(66,57),(105,65),(115,82),(75,91),(37,86)],base)
        P([(30,73),(11,49),(22,86)],_shade(base,-.08))
        for x in (47,83):
            L([(x,83),(x-8,104),(x+4,109)],dark,8)
        for x in range(42,104,12):P([(x,64),(x+5,46),(x+10,67)],accent)
        P([(91,64),(115,51),(120,72),(112,83)],_shade(base,.18))
    elif kind in ('mechanical','golem'):
        # angular readable construct with distinct clockwork/sigil in chest
        for side in (-1,1):
            x=cx+side*33
            P([(x-10,64),(x+10,64),(x+15,92),(x-15,95)],_shade(base,-.2))
            P([(x-10,92),(x+5,93),(x+7,111),(x-9,113)],dark)
        P([(35,43),(93,43),(104,83),(90,103),(38,101),(25,78)],base)
        if kind=='mechanical':
            E((51,55,77,81),accent)
            E((58,62,70,74),dark)
            for k in range(8):
                theta=k*math.pi/4;xx=64+17*math.cos(theta);yy=68+17*math.sin(theta)
                E((xx-3,yy-3,xx+3,yy+3),_shade(accent,.25))
        else:
            P([(47,52),(79,50),(93,78),(47,84)],_shade(base,-.22))
            P([(55,61),(65,51),(77,65),(66,79)],accent)
        P([(38,29),(90,29),(87,48),(43,48)],_shade(base,.12))
    elif kind=='floral':
        for i in range(10):
            theta=2*math.pi*i/10+phase*.10
            px=64+42*math.cos(theta);py=73+30*math.sin(theta)
            L([(64,96),(round(px),round(py))],_shade(base,-.2),7)
            E((px-9,py-16,px+9,py+3),accent if i%2 else base)
        P([(46,68),(80,66),(96,98),(32,99)],base)
        E((51,47,76,79),_shade(base,.2))
    elif kind=='ghost':
        # hollow center and tapered trails; translucency reserved for inner glow
        for j in range(5):
            x=29+j*16;yy=100+(j%2)*6
            P([(x,77),(x+16,76),(x+10,yy),(x+1,yy+9)],_shade(base,-.07))
        E((29,31,99,96),base)
        E((40,42,88,75),_shade(base,.35))
        P([(46,30),(57,14),(66,29),(84,19),(83,42)],_shade(accent,.2))
    elif kind=='knight':
        P([(38,52),(90,52),(96,106),(31,105)],base)
        for side in (-1,1):
            x=64+side*30
            P([(x-10,61),(x+10,60),(x+13,94),(x-12,95)],_shade(base,-.25))
        P([(44,24),(83,24),(91,49),(37,50)],_shade(base,-.18))
        P([(43,28),(63,14),(83,28)],accent)
        rect=(54,39,74,44);d.rectangle(rect,fill=_rgba(dark))
        L([(100,33),(102,108)],dark,8)
        L([(100,22),(101,84)],_shade(accent,.4),4)
        P([(24,65),(36,60),(37,95),(29,105),(19,91)],_shade(accent,-.14))
    else:
        P([(30,47),(49,19),(74,25),(99,49),(93,92),(45,101)],base)
        P([(42,45),(64,16),(78,47)],_shade(base,.2))
        E((45,49,83,85),_shade(base,.15))
    # Eye expressions; face anchor depends on archetype.
    if kind in ('mechanical','golem','ghost','knight','arcane','floral','cephalopod','insect','crab'):
        eye_y=63 if kind not in ('mechanical','golem') else 39
        for x in (55,75): E((x-4,eye_y-4,x+4,eye_y+3),accent,None)
    elif kind in ('serpent','fish','canine','beast','lizard'):
        E((103,58,108,63),accent,None)
    # Region identity engraving + character-specific marking positions.
    for idx in range(6 if big else 3):
        x=35+(seed(t['id'],'mark',idx)%55)
        y=48+(seed(t['id'],'marky',idx)%40)
        if t['markings']=='spots':E((x-2,y-2,x+3,y+2),_shade(accent,-.04),None)
        elif t['markings']=='runes':L([(x-3,y-4),(x,y+3),(x+3,y-4)],_shade(accent,.25),1)
        else:L([(x-4,y),(x+4,y+2)],_shade(accent,.24),2)
    if big:
        # boss ornament is readable at 128px; do not duplicate generic monster.
        horn=t['horns']
        for s in (-1,1):
            xx=64+s*25
            P([(xx,37),(xx+s*(8+horn*3),5),(xx-s*2,24)],_shade(accent,.36))
        for i in range(7):
            yy=23+i*11
            L([(12,yy),(16,yy-2)],_shade(accent,.28),1)
        E((59,8,69,18),_shade(accent,.7),None)
    # tiny faction/biome particles near extremities, deterministic.
    for k in range(8 if big else 3):
        x=r.randint(15,113);y=r.randint(13,104)
        if (x-64)**2+(y-68)**2>50**2:
            E((x,y,x+2,y+2),_shade(accent,.4),None)
    # universal breathing motion ensures every morphology has real frame changes.
    # Per-morphology appendages already animate separately where applicable.
    offsets=(-2,0,2,0)
    shifted=Image.new('RGBA',out.size,(0,0,0,0))
    shifted.paste(out,(0,offsets[phase]))
    if phase==3:
        # controlled blink and core emission shimmer, not simple hue re-tint.
        glow=Image.new('RGBA',out.size,(0,0,0,0));gd=ImageDraw.Draw(glow,'RGBA')
        gd.ellipse((58,60,70,72), fill=(*_shade(accent,.55),85))
        shifted=Image.alpha_composite(shifted,glow)
    # Identity morphology is stable across phases but varies between canonical
    # IDs; previously body_ratio was generated as metadata yet never applied.
    sx=t['body_ratio']
    sy=1.0 + (1.0-sx)*.22
    body_width=max(85,min(145,round(128*sx)))
    body_height=max(112,min(138,round(128*sy)))
    morphed=shifted.resize((body_width,body_height),Image.Resampling.BICUBIC)
    canvas=Image.new('RGBA',(128,128),(0,0,0,0))
    canvas.paste(morphed,((128-body_width)//2,(128-body_height)//2),morphed)
    return canvas

def creature_sheet(asset, region, category, variant=0):
    t=creature_parameters(asset, region, category, variant)
    sheet=Image.new('RGBA',(512,128),(0,0,0,0))
    for i in range(4):sheet.paste(draw_creature_frame(t,i),(i*128,0))
    return sheet,t

def region_atlas(region, water=False):
    a,b,c=color_layers(region);key=region['id']
    im=Image.new('RGBA',(256,256),(0,0,0,0)); pix=im.load()
    for row in range(8):
        for col in range(8):
            rnd=random.Random(seed(key,water,row,col))
            # source materials, each cell periodic, safe across tile seam.
            base=mix((33,90,122) if water else a,c if water else b,min(.85,row*.095))
            for y in range(32):
                for x in range(32):
                    nx=x/32;ny=y/32
                    n=(math.sin(2*math.pi*nx+row)*math.sin(2*math.pi*ny+col)+
                       .34*math.cos(4*math.pi*nx+col)*math.cos(4*math.pi*ny+row))*0.08
                    # fixed zero-noise edges, so neighboring tiles have no bright border.
                    edge=min(x,31-x,y,31-y)
                    amp=min(1,edge/3)
                    t=max(0,min(1,.5+n*amp))
                    tint=mix(base,c if water else b,t*.16)
                    v=int(round((n*amp)*32))
                    clr=tuple(min(255,max(0,z+v)) for z in tint)
                    pix[col*32+x,row*32+y]=(*clr,255)
            # center-only motifs; keep borders consistent.
            d=ImageDraw.Draw(im,'RGBA');ox=col*32;oy=row*32
            if water:
                rr=rnd.randrange(7,24);yy=rnd.randrange(7,24)
                d.arc((ox+rr-6,oy+yy-3,ox+rr+6,oy+yy+4),10,165,fill=(*_shade(b,.33),80),width=1)
            elif row in (1,2,3,4,6):
                for q in range(3):
                    xx=ox+rnd.randrange(8,25);yy=oy+rnd.randrange(8,25)
                    d.line((xx-3,yy,xx+3,yy),fill=(*_shade(c,.15),35+row*4),width=1)
    return im

def region_panorama(region, width=960,height=540):
    id=region['id'].removeprefix('region_')
    a,b,c=color_layers(region)
    upper=mix(c,(18,27,49),.52)
    bottom=mix(a,b,.53)
    im=Image.new('RGB',(width,height))
    d=ImageDraw.Draw(im)
    for y in range(height):
        t=y/max(1,height-1)
        d.line((0,y,width,y),fill=mix(upper,bottom,t))
    d=ImageDraw.Draw(im,'RGBA');r=random.Random(seed(id,'panorama'))
    light_x=width*.76;light_y=height*.25
    d.ellipse((light_x-50,light_y-50,light_x+50,light_y+50),fill=(*_shade(b,.64),80))
    for layer in range(4):
        baseline=205+layer*49
        pts=[(-20,height)]
        for x in range(-20,width+90,48):
            yy=baseline+int(25*math.sin(x*.009+layer)+r.randrange(-16,17))
            pts.append((x,yy))
        pts.append((width+20,height))
        d.polygon(pts,fill=(*mix(a,c,.2+layer*.14),255))
    floor=height*.73
    d.polygon([(0,floor),(width,floor-18),(width,height),(0,height)],fill=(*mix(a,(25,38,50),.2),255))
    motif=REGION_MOTIFS[id]
    if motif in ('lanterns','banners','furnaces','mirrors','rings'):
        for j in range(9):
            x=45+j*111;y=int(floor-r.randrange(55,95))
            wall=mix(b,(42,43,58),.32)
            d.rectangle((x,y,x+74,y+78),fill=(*wall,255),outline=(*_shade(wall,-.28),255),width=2)
            d.polygon([(x-13,y),(x+38,y-48),(x+87,y)],fill=(*_shade(c,-.3),255))
            for xx in (x+16,x+50):
                d.rectangle((xx,y+18,xx+10,y+41),fill=(*_shade(b,.37),255),outline=(32,37,47,255),width=2)
            if motif=='furnaces':
                d.rectangle((x+21,y-12,x+53,y+7),fill=(*_shade(b,.2),255))
                d.ellipse((x+28,y-22,x+45,y+2),fill=(255,161,80,170))
            if motif=='banners':d.polygon([(x+37,y-29),(x+58,y-16),(x+58,y+25),(x+37,y+10)],fill=(*_shade(b,.1),255))
            if motif=='mirrors':d.polygon([(x+7,y+9),(x+37,y-10),(x+67,y+9),(x+36,y+38)],fill=(*_shade(b,.34),140))
            if motif=='rings':d.arc((x+10,y-42,x+64,y+12),0,360,fill=(*_shade(b,.7),255),width=4)
            if motif=='lanterns':d.ellipse((x+28,y-22,x+43,y-4),fill=(255,215,127,180))
    elif motif in ('waves','sails'):
        d.polygon([(0,325),(width,310),(width,height),(0,height)],fill=(*_shade(a,-.15),255))
        for j in range(7):
            x=45+j*135;y=int(floor-r.randrange(20,55))
            d.polygon([(x,y),(x+80,y+8),(x+63,y+35),(x+15,y+34)],fill=(*_shade(b,-.3),255))
            d.line((x+42,y,x+42,y-110),fill=(*_shade(b,-.48),255),width=5)
            d.polygon([(x+44,y-106),(x+44,y-23),(x+86,y-30)],fill=(*_shade(b,.55),255))
    elif motif=='roots':
        for j in range(11):
            x=j*89+r.randint(-30,20);y=int(floor)
            d.line((x,y,x+r.randint(-20,20),y-120),fill=(*_shade(c,-.4),255),width=r.randint(6,15))
            d.ellipse((x-37,y-175,x+41,y-83),fill=(*_shade(a,-.16),255))
    d=ImageDraw.Draw(im,'RGBA')
    for i in range(70):
        x=r.randrange(width);y=r.randrange(height//2,height)
        d.ellipse((x,y,x+1,y+1),fill=(255,238,199,r.randrange(24,95)))
    return im

def qa_char(im):
    if im.size!=(96,192):raise ValueError(f'Bad cast atlas size {im.size}')
    assert im.mode=='RGBA'
    hashes=[]
    for i in range(4):
        for j in range(3):
            tile=im.crop((j*32,i*48,(j+1)*32,(i+1)*48))
            if not tile.getchannel('A').getbbox():raise ValueError('Empty cast frame')
            hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
    if len(set(hashes))<9:raise ValueError('Undifferentiated walking poses')
    return {'frames':12,'unique_frames':len(set(hashes)),'size':list(im.size)}

def qa_creature(im):
    if im.size!=(512,128):raise ValueError(f'Bad creature atlas size {im.size}')
    frames=[]
    for i in range(4):
        tile=im.crop((i*128,0,(i+1)*128,128))
        if not tile.getchannel('A').getbbox():raise ValueError('Empty creature frame')
        frames.append(hashlib.sha256(tile.tobytes()).hexdigest())
    if len(set(frames))<3:raise ValueError('Not enough distinct creature frames')
    return {'frames':4,'unique_frames':len(set(frames)),'size':list(im.size)}

def compare_images(im_a,im_b,scale=(28,28)):
    # purely rendered image similarity: no identity-profile labels or bonuses.
    a=im_a.convert('RGBA').resize(scale,Image.Resampling.BILINEAR)
    b=im_b.convert('RGBA').resize(scale,Image.Resampling.BILINEAR)
    A=np.asarray(a,dtype=np.float32)/255;B=np.asarray(b,dtype=np.float32)/255
    maskA=A[:,:,3];maskB=B[:,:,3]
    sil=float(np.mean(np.abs(maskA-maskB)))
    weight=np.maximum(maskA,maskB)
    rgbdiff=float(np.sum(np.mean(np.abs(A[:,:,:3]-B[:,:,:3]),axis=2)*weight)/max(1e-8,float(np.sum(weight))))
    return {'silhouette':round(sil,4),'appearance':round(rgbdiff,4),
            'distance':round(.72*sil+.28*rgbdiff,4)}

def appearance_audit(items, cutoff=0.045):
    # all images aligned to 4-direction front idle or creature idle.
    infos={}
    for id,(img,kind) in items.items():
        infos[id] = img.crop((32,0,64,48)) if kind=='characters' else img.crop((0,0,128,128))
    ids=sorted(infos)
    pairs=[];closest={id:(1,'') for id in ids}
    for i,a in enumerate(ids):
        for b in ids[i+1:]:
            result=compare_images(infos[a],infos[b])
            d=result['distance']
            if d<closest[a][0]:closest[a]=(d,b)
            if d<closest[b][0]:closest[b]=(d,a)
            if d<cutoff:pairs.append({'ids':[a,b],**result})
    out={'items':len(ids),'distance':'visual_alpha_shape_and_RGB_distance_only',
         'threshold':cutoff,'minimum_distance':round(min(v[0] for v in closest.values()),4) if closest else None,
         'warning_pairs':sorted(pairs,key=lambda x:x['distance'])[:500],
         'nearest':{id:{'distance':round(closest[id][0],4),'other':closest[id][1]} for id in ids},
         'status':'成功' if not pairs else '需人工确认'}
    return out

def visual_embedding(image):
    im=image.convert('RGBA').resize((24,24),Image.Resampling.BILINEAR)
    return np.asarray(im,dtype=np.float32)/255.0


def optimize_creature(asset, region, category, earlier):
    """Optimize identity based on rendered appearance, not the metadata label.

    Earlier is a cache of compact 24x24 RGBA embeddings, so the search costs
    linear vectorized NumPy operations rather than repeated PIL resampling.
    """
    if not earlier:
        img,t = creature_sheet(asset,region,category,0)
        t['optimized_distance'] = None
        return img,t,visual_embedding(img.crop((0,0,128,128)))
    prior=np.stack(earlier,axis=0)
    chosen=None
    for variant in range(4):
        image,t = creature_sheet(asset,region,category,variant)
        v=visual_embedding(image.crop((0,0,128,128)))
        sil=np.mean(np.abs(prior[:,:,:,3]-v[:,:,3]),axis=(1,2))
        weight=np.maximum(prior[:,:,:,3],v[:,:,3])
        rgb=np.mean(np.abs(prior[:,:,:,:3]-v[:,:,:3]),axis=3)
        color=np.sum(rgb*weight,axis=(1,2))/(np.sum(weight,axis=(1,2))+1e-7)
        mindist=float(np.min(.72*sil+.28*color))
        if chosen is None or mindist>chosen[0]:
            chosen=(mindist,image,t,v)
    chosen[2]['optimized_distance'] = round(chosen[0],4)
    return chosen[1],chosen[2],chosen[3]

def record_asset(manifest,out,path,kind,asset_id,qa=None,attributes=None):
    with Image.open(path) as image:
        image.verify()
    manifest['assets'].append({'id':asset_id,'group':kind,
        'path':path.relative_to(out).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'bytes':path.stat().st_size,'qa':qa or {},'identity':attributes or {},
        'status':'generated_procedural_candidate_not_approved'})

def gallery(out, data):
    # Contact sheet has actual output images, not a generated advertisement.
    W,H=1500,1650
    im=Image.new('RGB',(W,H),(14,25,39));d=ImageDraw.Draw(im)
    d.text((34,20),'STARLIT CHRONICLE / HD-2D STUDIO V8',fill=(241,222,180))
    d.text((34,47),'Actual locally rendered candidates | NO model API call | NOT commercial-approved',fill=(179,200,212))
    # Eight backgrounds 4x2
    for i,reg in enumerate(data['regions']):
        x=24+i%4*370;y=90+i//4*230
        path=out/'regions'/f'{reg["id"]}_panorama.png'
        with Image.open(path) as src:
            thumb=src.resize((355,195),Image.Resampling.LANCZOS)
        im.paste(thumb,(x,y))
        d.text((x,y+200),reg['name']+' / '+REGION_MOTIFS[reg['id'].removeprefix('region_')],fill=(223,211,184))
    d.text((25,555),'CAST / 12 unique 4-direction, 3-pose runtime sheets',fill=(237,219,185))
    for i,char in enumerate(data['characters']):
        x=24+i%6*244;y=590+i//6*310
        d.rounded_rectangle((x-2,y-2,x+224,y+291),10,fill=(23,38,57))
        atlas=Image.open(out/'characters'/f'{char["id"]}.png').convert('RGBA')
        atlas=atlas.resize((160,260),Image.Resampling.NEAREST)
        checker=Image.new('RGB',atlas.size,(41,51,69));checker.paste(atlas,(0,0),atlas)
        im.paste(checker,(x+16,y+8))
        d.text((x+8,y+272),char['name']+' '+char['id'].removeprefix('char_'),fill=(237,219,185))
    d.text((25,1245),'BOSSES / semantic identity variants, actual 4-frame output',fill=(237,219,185))
    samples=['boss_ch002','boss_ch017','boss_ch029','boss_ch043','boss_ch047','boss_ch071']
    for i,id in enumerate(samples):
        x=20+i%3*492;y=1290+i//3*170
        with Image.open(out/'bosses'/f'{id}.png') as s:
            tile=s.convert('RGBA').crop((0,0,128,128)).resize((160,160),Image.Resampling.NEAREST)
        bg=Image.new('RGB',tile.size,(32,42,58));bg.paste(tile,(0,0),tile)
        im.paste(bg,(x,y))
        entry=next((b for b in data['bosses'] if b['id']==id),None)
        d.text((x+170,y+30),entry['name'] if entry else id,fill=(228,214,186))
        d.text((x+170,y+63),id,fill=(165,190,210))
    p=out/'v8_actual_generated_preview.png';save_png(im,p)
    return p

def load_registry(root):
    path=root/'data/assets/av_registry.json'
    if not path.exists():raise FileNotFoundError('Main2 official registry missing: '+str(path))
    data=json.loads(path.read_text(encoding='utf-8-sig'))
    for category in GROUPS:
        rows=data.get(category)
        if not isinstance(rows,list) or not rows:raise ValueError(f'No entries for {category}')
        ids=[safe_id(x['id']) for x in rows]
        if len(ids)!=len(set(ids)):raise ValueError(f'Duplicate canonical IDs in {category}')
    return data

def produce(root,out,scope,limit=0):
    data=load_registry(root)
    out=out.resolve();root=root.resolve()
    if out in (root,root/'assets',root/'assets/art/runtime'):
        raise ValueError('Invalid runtime output destination')
    out.mkdir(parents=True,exist_ok=True)
    manifests={'schema':'starlit.hd2d.v8.candidates','version':VERSION,
              'approval':'NOT_APPROVED','runtime_modified':False,
              'canonical_source':str(root/'data/assets/av_registry.json'),
              'assets':[],'counts':{},'visual_audit':{},'quality_status':'机器结构检查，不代表美术签收'}
    regions={row['id']:row for row in data['regions']}
    shapes={}
    seen_creatures={'monsters':[],'bosses':[]}
    active=GROUPS if scope=='all' else [scope]
    for category in active:
        rows=data[category][:limit or None]
        for row in rows:
            id=safe_id(row['id'])
            if category=='characters':
                if id not in CAST_ROLES:raise ValueError('Missing canon identity role: '+id)
                im=character_sheet(id);qa=qa_char(im);identity={'name':row['name'],'costume':CAST_ROLES[id][2],'gear':CAST_ROLES[id][1]}
                path=out/'characters'/f'{id}.png';save_png(im,path);record_asset(manifests,out,path,category,id,qa,identity)
                normal_path=out/'characters'/f'{id}_normal.png';save_png(height_normal(im),normal_path)
                record_asset(manifests,out,normal_path,'normals',id,{'size':[96,192]})
                shapes[id]=(im,'characters')
            elif category in ('monsters','bosses'):
                region_id=row.get('region_id') if category=='monsters' else list(regions)[(int(re.findall(r'\d+',id)[0])-1)//9 % len(regions)]
                region=regions.get(region_id,list(regions.values())[0])
                im,identity,embedding=optimize_creature(row,region,'boss' if category=='bosses' else 'monster', seen_creatures[category])
                qa=qa_creature(im)
                path=out/category/f'{id}.png';save_png(im,path)
                record_asset(manifests,out,path,category,id,qa,identity)
                shapes[id]=(im,category)
                seen_creatures[category].append(embedding)
            else:
                # Two canonical 256x256 atlases + one panorama per region.
                for name,im in [('ground',region_atlas(row)),('water',region_atlas(row,True)),('panorama',region_panorama(row))]:
                    path=out/'regions'/f'{id}_{name}.png';save_png(im,path)
                    record_asset(manifests,out,path,category,id+'_'+name,{'size':list(im.size)},
                                 {'name':row['name'],'motif':REGION_MOTIFS[id.removeprefix('region_')]})
        manifests['counts'][category]=len(rows)
    # Pairwise audit between same asset classes only, NEVER across unrelated domains.
    for category in ('characters','monsters','bosses'):
        curr={k:v for k,v in shapes.items() if v[1]==category}
        if curr:manifests['visual_audit'][category]=appearance_audit(curr)
    if scope=='all' and limit==0:
        for key,expected in CANONICAL.items():
            if manifests['counts'][key]!=len(data[key]):raise ValueError('Unexpected coverage')
    if all((out/'regions'/f'{x["id"]}_panorama.png').exists() for x in data['regions']) and all((out/'characters'/f'{x["id"]}.png').exists() for x in data['characters']):
        if all((out/'bosses'/f'{id}.png').is_file() for id in ('boss_ch002','boss_ch017','boss_ch029','boss_ch043','boss_ch047','boss_ch071')):
            p=gallery(out,data);record_asset(manifests,out,p,'preview','v8_actual_generated_preview')
    manifest=out/'candidate_manifest.json'
    manifest.write_text(json.dumps(manifests,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return manifests

def identity_briefs(root,out):
    """One-to-one model briefs referencing actual rendered identities.

    The existing global_art_ai_provider_v3 can re-render these exact IDs with
    --reference-root pointing to this V8 output; only the explicit --render
    switch calls a paid model. The briefs are useful for QA and art direction.
    """
    data=load_registry(root)
    index=[]
    for group in ('characters','monsters','bosses'):
        for entry in data[group]:
            id=safe_id(entry['id'])
            path=out/group/(id+'.png')
            if not path.is_file():continue
            if group=='characters':
                role=CAST_ROLES[id]
                spec={'silhouette':role[2],'item':role[1],'motif':role[3],
                      'dominant':role[4],'accent':role[5],'ink':role[6]}
                requirement='Four directional walking rows, three distinct poses per row. Maintain identical costume, equipment and anatomy.'
            else:
                regions={r['id']:r for r in data['regions']}
                target=entry.get('region_id','region_coast')
                region=regions.get(target,list(regions.values())[0])
                spec=creature_parameters(entry,region,'boss' if group=='bosses' else 'monster')
                requirement='Four sequential 128-square poses, same unique creature, no copied generic silhouette.'
            prompt=('Original highly polished hand-painted 2D JRPG game art for '+entry['name']+' ('+id+'). '
                 'Respect canonical identity and functional equipment. Rich authored anatomy, refined material texture, '
                 'readable silhouettes at final sprite size, painterly light and coherent animation. '
                 'Use provided image as exact character design reference, reinterpret it with professional finishing. '
                 +requirement+' Real RGBA background; avoid text, 3D, photo or poster typography.')
            index.append({'id':id,'name':entry['name'],'group':group,
                          'reference':path.relative_to(out).as_posix(),
                          'reference_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                          'design_contract':spec,'prompt':prompt,
                          'status':'brief_not_rendered_by_model'})
    target=out/'model_identity_briefs.jsonl'
    target.write_text(''.join(json.dumps(row,ensure_ascii=False)+'\n' for row in index),encoding='utf-8')
    return {'model_jobs':len(index),'output':str(target),'api_called':False}


def delegate_model(root,out,scope,limit,quality,render):
    provider=root/'tools/global_art_ai_provider_v3.py'
    if not provider.is_file():raise ValueError('Official Main2 high-quality renderer missing: '+str(provider))
    if render and not os.environ.get('OPENAI_API_KEY'):
        raise ValueError('OPENAI_API_KEY required to call image model; nothing was rendered')
    cmd=[sys.executable,str(provider),'--project',str(root),
         '--scope',scope,'--limit',str(max(0,limit)),
         '--quality',quality,'--reference-root',str(out),
         '--render' if render else '--jobs-only']
    proc=subprocess.run(cmd,cwd=root,check=False)
    if proc.returncode:raise RuntimeError('Canonical model provider returned '+str(proc.returncode))
    return {'status':'成功','api_called':render,'provider':'global_art_ai_provider_v3',
            'reference_root':str(out),'scope':scope}

def verify(root,out):
    meta=json.loads((out/'candidate_manifest.json').read_text(encoding='utf-8'))
    if meta['schema']!='starlit.hd2d.v8.candidates' or meta['runtime_modified'] is not False:
        raise ValueError('Invalid candidate manifest')
    for item in meta['assets']:
        p=(out/item['path']).resolve()
        if not p.is_relative_to(out.resolve()):raise ValueError('Unsafe path')
        if not p.is_file():raise FileNotFoundError(p)
        if hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:raise ValueError('Checksum mismatch '+str(p))
        with Image.open(p) as im:
            im.load()
            if item['group']=='characters':qa_char(im)
            elif item['group'] in ('monsters','bosses'):qa_creature(im)
    return {'status':'成功','verified_assets':len(meta['assets']),'runtime_modified':False}

def main(argv=None):
    p=argparse.ArgumentParser(description='Canonical-ID identity-aware HD-2D art production')
    p.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--output',type=Path)
    p.add_argument('--scope',choices=('all',)+GROUPS,default='all')
    p.add_argument('--limit',type=int,default=0)
    p.add_argument('--verify',action='store_true')
    p.add_argument('--model-briefs',action='store_true',help='Create canonical identity prompts using already produced candidate images')
    p.add_argument('--model-render',action='store_true',help='EXPLICIT paid call via existing Main2 global model art provider')
    p.add_argument('--model-scope',choices=('characters','monsters','bosses'),default='characters')
    p.add_argument('--model-limit',type=int,default=8)
    p.add_argument('--model-quality',choices=('low','medium','high','xhigh','max','auto'),default='xhigh')
    a=p.parse_args(argv)
    root=a.project.resolve();out=(a.output or root/'build/starlit_hd2d_studio_v8').resolve()
    try:
        if a.verify:result=verify(root,out)
        elif a.model_render:
            result=delegate_model(root,out,a.model_scope,a.model_limit,a.model_quality,True)
        elif a.model_briefs:
            result=identity_briefs(root,out)
        else:
            manifest=produce(root,out,a.scope,max(0,a.limit))
            result={'status':'成功','counts':manifest['counts'],'files':len(manifest['assets']),
                    'art_approved':False,'runtime_modified':False,
                    'warnings':{k:len(v['warning_pairs']) for k,v in manifest['visual_audit'].items()}}
        print(json.dumps(result,ensure_ascii=False,indent=2))
        return 0
    except (ValueError,FileNotFoundError,RuntimeError) as e:
        print('V8 ERROR:',e,file=sys.stderr)
        return 2

if __name__=='__main__':sys.exit(main())