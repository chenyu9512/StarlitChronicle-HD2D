"""Starlit Chronicle HD-2D: detailed, deterministic 2D procedural candidates.

V4.1 refinement of the V4 renderer. It does not infer canonical character
identity and never edits gameplay/collision/runtime assets. Geometry is drawn at
2x/3x internal resolution then downsampled; runtime atlas contracts stay fixed.
"""
from __future__ import annotations

import math
import random
from PIL import Image, ImageDraw, ImageFilter
from art_style_v6 import (_seed, _shade, _mix, _palette, normal_map,
                          write_auxiliary_svgs, terrain_cell as _v6_tile)


class Ink:
    """Antialiased vector-like geometry on an integer scaled RGBA canvas."""
    def __init__(self, image, scale=3):
        self.image = image
        self.s = scale
        self.d = ImageDraw.Draw(image, 'RGBA')

    def coords(self, points):
        return [(round(x*self.s),round(y*self.s)) for x,y in points]

    def poly(self, points, fill, outline=None, width=1):
        p=self.coords(points)
        self.d.polygon(p, fill=fill)
        if outline is not None:
            self.d.line(p+[p[0]],fill=outline,width=max(1,round(width*self.s)),joint='curve')

    def line(self, points, fill, width=1, joint='curve'):
        self.d.line(self.coords(points),fill=fill,width=max(1,round(width*self.s)),joint=joint)

    def ellipse(self, box, fill, outline=None, width=1):
        self.d.ellipse(tuple(round(q*self.s) for q in box),fill=fill,outline=outline,width=max(1,round(width*self.s)))

    def rect(self, box, fill, outline=None, width=1):
        self.d.rectangle(tuple(round(q*self.s) for q in box),fill=fill,outline=outline,width=max(1,round(width*self.s)))

    def arc(self, box, start, end, fill, width=1):
        self.d.arc(tuple(round(q*self.s) for q in box),start,end,fill=fill,width=max(1,round(width*self.s)))


def _rgb(c, alpha=255):
    return (*c[:3],alpha)


def _reduce(im, size):
    return im.resize(size,Image.Resampling.LANCZOS)


def terrain_cell(draw,x,y,base,kind,seed):
    """Detail pass uses only inset coordinates; all tile border pixels remain equal.

    No full-cell light gradient, so repeating a single 32px tile does not create
    vertical bands or checkerboard seams.
    """
    _v6_tile(draw,x,y,base,kind,seed)
    r=random.Random(seed ^ 0x7A11C0D)
    def p(): return x+r.randrange(4,28),y+r.randrange(4,28)
    if kind=='grass':
        for i in range(10):
            px,py=p(); shade=_shade(base,r.choice((-.24,-.14,.18,.29)))
            draw.line((px,py+2,px+1,py-2),fill=shade,width=1)
            draw.point((px-1,py),fill=_shade(base,.23))
        if r.randrange(5)==0:
            xx,yy=p();draw.ellipse((xx-2,yy-2,xx+2,yy+1),fill=_shade(base,.57))
            draw.point((xx,yy-2),fill=_shade(base,.8))
    elif kind=='sand':
        for i in range(15):
            xx,yy=p();draw.point((xx,yy),fill=_shade(base,r.choice((.31,-.22,.16))))
            if i%5==0:draw.arc((xx-3,yy-2,xx+5,yy+2),30,165,fill=_shade(base,.17))
    elif kind=='road':
        for i in range(5):
            xx,yy=p(); pts=((xx-2,yy),(xx,yy-2),(xx+4,yy),(xx+2,yy+2))
            draw.polygon(pts, fill=_shade(base,-.17))
            draw.line((xx-1,yy-1,xx+2,yy-1),fill=_shade(base,.24),width=1)
    elif kind=='water':
        for i in range(6):
            xx,yy=p()
            draw.arc((xx-3,yy-1,xx+5,yy+2),5,160,fill=_shade(base,.25))
            if i%3==0: draw.point((xx+3,yy+1), fill=_shade(base,.47))
    elif kind=='wood':
        for yy in (9,17,25):
            xx=x+r.randrange(6,21)
            draw.arc((xx, y+yy-3,xx+8,y+yy+3),185,340,fill=_shade(base,-.19))
            draw.point((xx+5,y+yy-1), fill=_shade(base,.23))
    elif kind in ('stone','wall','cobbles'):
        for i in range(8):
            xx,yy=p(); col=_shade(base,r.uniform(-.25,.30))
            draw.line((xx,yy,xx+r.randrange(2,6),yy),fill=col,width=1)
            if i%3==0:draw.point((xx+1,yy+1),fill=_shade(base,-.3))
    # Enforce an identical 2px sampling border for every atlas variant.
    draw.rectangle((x,y,x+31,y+31),outline=base,width=2)


def character_sheet(asset_id,region):
    """Canonical 3x4 walker. Class silhouette, skin, face and palette stay
    consistent across four directions while gait and cloth really animate.
    """
    a,b,c=_palette(region)
    seed=_seed(asset_id,'refined-character')
    r=random.Random(seed)
    id_low=asset_id.lower()
    roles=('wanderer','healer','ranger','knight','engineer','bard','duelist','scribe')
    aliases={
        'wayfarer':'wanderer','tidecaller':'healer','leiso':'knight','lanyin':'healer',
        'shuoxian':'ranger','tifa':'engineer','noe':'scribe','visha':'duelist',
        'xuanli':'duelist','ize':'bard'
    }
    role=next((v for k,v in aliases.items() if k in id_low),roles[seed%len(roles)])
    cloth=_shade(a,r.uniform(-.28,-.06))
    coat=_mix(c,a,.20)
    metal=_shade(b,.42)
    dark=_shade(c,-.63)
    skin=((231,182,139),(182,126,91),(244,209,173))[_seed(asset_id,'skin')%3]
    hair=_shade(c,-.44)
    highlight=_shade(a,.65)
    glow=((255,208,117) if role in ('wanderer','healer') else (152,225,218))
    scale=3
    master=Image.new('RGBA',(96*scale,192*scale))
    d=Ink(master,scale)
    for direction in range(4):
        for frame in range(3):
            x,y=frame*32,direction*48
            stride=(-2,0,2)[frame]
            bob=(1,0,1)[frame]
            face=direction==0; back=direction==2
            side=direction in (1,3)
            # Contact shadow never influences sprite collision or tile footprint.
            d.ellipse((x+8,y+43,x+25,y+46),(11,20,32,77))
            d.poly([(x+12,y+23),(x+20,y+23),(x+25+stride*.32,y+40),
                    (x+7+stride*.28,y+40)],_rgb(_shade(coat,-.22)))
            for i in range(5):
                d.line([(x+11+i*2,y+30),(x+10+i*2+stride*.2,y+39)],_rgb(_shade(coat,(-.24,.12,.26,-.13,.22)[i])),.6)
            # Separate articulated feet, fixed hem and knees.
            for fx,delta in ((11,stride),(21,-stride)):
                d.line([(x+fx,y+33),(x+fx+delta,y+42)],_rgb(dark),3.2)
                d.rect((x+fx+delta-2,y+41,x+fx+delta+2,y+43.4),_rgb(_shade(dark,-.19)))
                d.line([(x+fx+delta-1,y+41),(x+fx+delta+1,y+41)],_rgb(metal),.7)
            # Fitted tunic with directional light, seams, trim and belt.
            d.poly([(x+11,y+21+bob),(x+20,y+21+bob),
                    (x+23,y+32),(x+9,y+32)],_rgb(cloth))
            d.poly([(x+11,y+22+bob),(x+14,y+22+bob),(x+13,y+31),(x+10,y+31)],_rgb(_shade(cloth,.32)))
            d.line([(x+21,y+23),(x+22,y+31)],_rgb(_shade(cloth,-.35)),1.2)
            d.rect((x+10,y+30.6,x+23,y+33),_rgb(_shade(coat,-.36)))
            d.rect((x+15,y+31,x+18,y+33),_rgb(metal))
            d.rect((x+16,y+31.5,x+17,y+32.5),_rgb(dark))
            for fx,swing in ((9,stride//2),(23,-stride//2)):
                d.line([(x+fx,y+23+bob),(x+fx+swing,y+33)],_rgb(cloth),3.1)
                d.line([(x+fx-1,y+24),(x+fx+swing-1,y+29)],_rgb(_shade(cloth,.37)),.8)
                d.ellipse((x+fx+swing-1.5,y+32,x+fx+swing+1.5,y+35),_rgb(skin))
            # Head volume and variable hair outline; different face per direction.
            d.ellipse((x+10,y+8+bob,x+22,y+23+bob),_rgb(skin))
            d.arc((x+11,y+12+bob,x+21,y+23+bob),5,155,_rgb(_shade(skin,.25)),.8)
            if back:
                d.poly([(x+10,y+17),(x+10,y+9),(x+14,y+5),
                        (x+20,y+6),(x+23,y+11),(x+21,y+21),(x+11,y+21)],_rgb(hair))
                d.line([(x+12,y+19),(x+20,y+19)],_rgb(_shade(hair,.24)),.8)
            else:
                d.poly([(x+9,y+15),(x+10,y+8),(x+14,y+5),
                        (x+21,y+7),(x+23,y+15),(x+18,y+11),(x+14,y+11)],_rgb(hair))
                d.line([(x+10,y+10),(x+15,y+6),(x+20,y+8)],_rgb(_shade(hair,.35)),.85)
                if face:
                    for ex in (13.4,19.6):d.ellipse((x+ex,y+16.3+bob,x+ex+.9,y+17.6+bob),_rgb(dark))
                    d.line([(x+15.3,y+20.4+bob),(x+18,y+20.4+bob)],_rgb(_shade(skin,-.38)),.7)
                else:
                    ex=(11 if direction==1 else 21)
                    d.ellipse((x+ex,y+16.5+bob,x+ex+1,y+17.5+bob),_rgb(dark))
            # Class-specific large readable motifs. Keep clear of 32px cell sides.
            if role=='wanderer':
                d.poly([(x+14,y+24),(x+18,y+24),(x+16,y+29)],_rgb(glow))
                d.line([(x+24,y+29),(x+25,y+36)],_rgb(metal),1.3)
                d.ellipse((x+22.5,y+31,x+27,y+35),_rgb(glow,245),_rgb(_shade(glow,-.20)),.7)
                d.line([(x+23,y+31),(x+26,y+31)],_rgb(highlight),.6)
            elif role=='healer':
                d.poly([(x+12,y+22),(x+20,y+22),(x+19,y+25),(x+13,y+25)],_rgb(_shade(b,.54)))
                d.line([(x+24,y+18),(x+25,y+38)],_rgb(metal),1.2)
                d.ellipse((x+22,y+16,x+27,y+20),_rgb((113,227,195)))
                d.line([(x+21,y+28),(x+26,y+30)],_rgb(glow),1)
            elif role=='ranger':
                d.line([(x+25,y+18),(x+27,y+33)],_rgb(_shade(b,-.46)),1)
                d.arc((x+21,y+20,x+30,y+36),85,265,_rgb(_shade(b,.47)),1.2)
                d.line([(x+23,y+20),(x+25,y+35)],_rgb(glow),.5)
            elif role=='knight':
                d.poly([(x+8,y+24),(x+10,y+20),(x+16,y+24),(x+12,y+28)],_rgb(metal))
                d.poly([(x+19,y+23),(x+23,y+21),(x+26,y+27)],_rgb(_shade(metal,-.16)))
                d.line([(x+16,y+25),(x+16,y+30)],_rgb(glow),1)
            elif role=='engineer':
                d.rect((x+20,y+28,x+27,y+35),_rgb(_shade(b,-.3)),_rgb(metal),.9)
                d.ellipse((x+13,y+9,x+17,y+12),_rgb((100,220,229),220),_rgb(metal),.7)
                d.ellipse((x+18,y+9,x+22,y+12),_rgb((100,220,229),220),_rgb(metal),.7)
                d.line([(x+12,y+23),(x+22,y+29)],_rgb(glow),1)
            elif role=='bard':
                d.poly([(x+12,y+21),(x+22,y+21),(x+19,y+25),(x+12,y+26)],_rgb(glow))
                d.ellipse((x+22,y+28,x+27,y+36),_rgb(_shade(b,.18)),_rgb(dark),.8)
                for j in range(3):d.line([(x+23+j,y+29),(x+23+j,y+35)],_rgb(highlight),.4)
            elif role=='duelist':
                d.line([(x+24,y+20),(x+27,y+39)],_rgb(_shade(metal,.32)),1)
                d.line([(x+26,y+23),(x+23,y+25)],_rgb(glow),1)
                d.line([(x+10,y+26),(x+20,y+30)],_rgb(_shade(b,.3)),1)
            else: # scribe
                d.rect((x+22,y+27,x+27,y+35),_rgb(_shade(b,.35)),_rgb(dark),.7)
                for j in range(3):d.line([(x+23,y+29+j*2),(x+26,y+29+j*2)],_rgb(_shade(c,-.3)),.4)
            # A single insignia ties the outfit to the game's star-lamp motif.
            if not back:
                d.ellipse((x+15.4,y+26.4,x+17,y+28),_rgb(_shade(b,.77)))
    return _reduce(master,(96,192))


def draw_prop(region,kind):
    """Detailed silhouette-aware vegetation, masonry, roof, and usable props."""
    a,b,c=_palette(region)
    r=random.Random(_seed(region['id'],kind,'refined-prop'))
    scale=3
    layer=Image.new('RGBA',(96*scale,128*scale));d=Ink(layer,scale)
    d.ellipse((13,111,88,121),(19,31,41,38))
    if kind=='tree':
        # Several branches lead to lobed clusters; not overlapping uniform disks.
        d.poly([(44,117),(43,88),(35,71),(36,63),(46,72),(50,55),(56,74),
                (65,61),(67,69),(55,90),(53,116)],_rgb(_shade(b,-.55)))
        for pts in [[(47,106),(47,66),(40,55)],[(51,92),(61,70),(70,58)],[(47,82),(35,69),(25,59)]]:
            d.line(pts,_rgb(_shade(b,-.24)),2.2)
        d.line([(45,90),(45,112)],_rgb(_shade(b,.27)),1.4)
        species=_seed(region['id'],'species')%3
        blobs=[(30,56,15),(49,37,21),(68,53,18),(40,70,15),(64,72,14),(48,56,20)]
        for ix,(cx,cy,rad) in enumerate(blobs):
            shade=_shade(a,(-.29,-.18,-.38,-.20,-.34,-.04)[ix])
            contour=[]
            for j in range(28):
                t=2*math.pi*j/28
                distort=1+.13*math.sin(j*2.1+ix)+r.uniform(-.09,.09)
                contour.append((cx+rad*math.cos(t)*distort,cy+rad*.72*math.sin(t)*distort))
            d.poly(contour,_rgb(shade))
            count=43 if species else 30
            for j in range(count):
                t=r.random()*2*math.pi; rr=math.sqrt(r.random())
                xx=cx+math.cos(t)*rad*.8*rr; yy=cy+math.sin(t)*rad*.55*rr
                foliage=_shade(a,r.uniform(-.32,.42)+(0.13 if yy<cy else -.08))
                if species==2: # Thin salt leaves, coasts and riverbanks.
                    d.line([(xx-1,yy+.7),(xx+2.2,yy-1.1)],_rgb(foliage),.9)
                elif species==1: # Broad textured leaves.
                    d.ellipse((xx-1.6,yy-1,xx+2.2,yy+.75),_rgb(foliage))
                else: # Needle clusters.
                    d.poly([(xx-2,yy+1.4),(xx,yy-2),(xx+2,yy+1.3)],_rgb(foliage))
        for i in range(9):
            xx=r.uniform(20,74);yy=r.uniform(31,77)
            d.line([(xx,yy),(xx+3,yy-2)],_rgb(_shade(a,.64)),.55)
    elif kind in ('cottage','shop','shrine'):
        stone=_shade(b,-.34);plaster=_shade(b,.16);roof=_shade(c,-.19)
        d.poly([(10,46),(46,9),(88,46),(86,109),(10,109)],_rgb(stone))
        d.rect((13,49,83,104),_rgb(plaster),_rgb(_shade(c,-.4)),1.1)
        d.rect((12,99,84,109),_rgb(_shade(stone,-.15)))
        # Horizontal plaster masonry with irregular joints.
        for line in range(5):
            yy=54+line*10
            d.line([(15,yy),(81,yy)],_rgb(_shade(plaster,-.18)),.7)
            for xx in range(18+(line%2)*9,79,19):
                d.line([(xx,yy),(xx,yy+7)],_rgb(_shade(plaster,-.15)),.65)
        for xx in (15,81):
            d.line([(xx,53),(xx,104)],_rgb(_shade(plaster,.28)),1.5)
        # Depth overhang, dark soffit, 3 bands of staggered roof tiles.
        d.poly([(4,44),(48,7),(92,44),(85,52),(48,18),(11,53)],_rgb(_shade(roof,-.15)))
        d.poly([(10,44),(48,11),(87,44),(83,47),(48,18),(14,47)],_rgb(_shade(roof,.12)))
        d.line([(8,43),(48,9),(88,43)],_rgb(_shade(roof,.48)),1.3)
        for row in range(4):
            yy=24+row*7
            half=(yy-9)*1.08
            for j,xx in enumerate(range(int(48-half),int(48+half),8)):
                d.line([(xx+(row%2)*3,yy),(xx+5+(row%2)*3,yy)],_rgb(_shade(roof,.23 if j%2 else -.26)),.7)
                d.line([(xx+2,yy+1),(xx+3,yy+3)],_rgb(_shade(roof,-.20)),.5)
        # Structural timber, crisp windows with recessed arch/light reflection.
        for xx in (20,68):
            d.rect((xx-3,59,xx+12,80),_rgb(_shade(stone,-.19)),_rgb(_shade(plaster,.3)),.65)
            d.rect((xx,62,xx+9,77),_rgb(_shade(a,-.37)),_rgb(_shade(stone,-.45)),1.0)
            d.poly([(xx+1,64),(xx+5,63),(xx+5,76),(xx+1,76)],_rgb(_shade(a,.65),188))
            d.line([(xx+5,62),(xx+5,78)],_rgb(_shade(b,-.29)),1)
            d.line([(xx,70),(xx+9,70)],_rgb(_shade(b,-.29)),.8)
            d.rect((xx-2,78,xx+11,80),_rgb(_shade(b,.38)))
        # Double frame and actual stepped threshold make door recognizable.
        d.rect((34,75,61,106),_rgb(_shade(stone,-.37)),_rgb(_shade(b,.45)),1.4)
        d.rect((38,78,58,104),_rgb(_shade(c,-.63)))
        d.poly([(40,79),(50,79),(48,104),(40,104)],_rgb(_shade(b,-.51)))
        d.ellipse((54,90,55.3,92),_rgb(_shade(b,.82)))
        d.poly([(30,106),(65,106),(70,111),(26,111)],_rgb(_shade(stone,.16)))
        d.line([(31,107),(63,107)],_rgb(_shade(b,.44)),.6)
        if kind=='shop':
            # Striped awning and swinging brass sign.
            d.poly([(11,51),(86,51),(81,62),(17,62)],_rgb(_shade(a,-.27)))
            for xx in range(17,83,12):
                d.poly([(xx,52),(xx+6,52),(xx+5,62),(xx-2,62)],_rgb(_shade(b,.45)))
            d.line([(79,51),(90,51),(90,73)],_rgb(_shade(stone,-.29)),.9)
            d.ellipse((83,63,95,75),_rgb(_shade(b,.61)),_rgb(_shade(stone,-.3)),1)
        elif kind=='shrine':
            d.poly([(48,13),(55,26),(48,41),(41,26)],_rgb(_shade(b,.75)))
            d.line([(48,15),(48,40)],_rgb(_shade(c,-.28)),1.2)
            for yy in (87,94): d.line([(17,yy),(30,yy)],_rgb(_shade(c,-.44)),.8)
        else:
            d.line([(26,56),(29,65)],_rgb(_shade(a,-.22)),1)
            for j in range(4):
                d.ellipse((17+j*2,100-j%2,19+j*2,102-j%2),_rgb(_shade(a,-.21)))
    elif kind=='well':
        d.ellipse((17,74,83,111),_rgb(_shade(c,-.4)))
        for i in range(5):
            yy=79+i*5; d.arc((20,yy,80,yy+29),0,180,_rgb(_shade(b,.35 if i%2 else -.2)),1.3)
        d.ellipse((27,79,74,101),_rgb(_shade(a,-.42)),_rgb(_shade(b,.45)),1.5)
        d.arc((33,83,70,97),200,330,_rgb(_shade(a,.72)),1.1)
        for xx in (21,72):
            d.rect((xx,34,xx+6,88),_rgb(_shade(b,-.42)),_rgb(_shade(b,.27)),.7)
            d.line([(xx+2,39),(xx+2,83)],_rgb(_shade(b,.28)),.7)
        d.poly([(11,38),(48,13),(88,37),(80,43),(48,21),(19,43)],_rgb(_shade(c,-.22)))
        d.line([(18,37),(48,15),(81,36)],_rgb(_shade(c,.53)),1.4)
        d.line([(49,35),(49,65)],_rgb(_shade(b,-.52)),1)
        d.ellipse((44,58,54,66),_rgb(_shade(b,-.38)),_rgb(_shade(b,.38)),.7)
    elif kind=='lantern':
        d.rect((45,48,52,117),_rgb(_shade(c,-.61)),_rgb(_shade(b,.29)),.7)
        d.rect((42,113,56,119),_rgb(_shade(c,-.35)))
        d.poly([(30,49),(36,22),(63,22),(68,49),(60,56),(37,56)],_rgb(_shade(c,-.22)))
        d.ellipse((34,22,64,57),_rgb(_shade(b,.88),188))
        d.poly([(49,25),(57,43),(49,53),(41,43)],_rgb((255,236,159)))
        for xx in (36,62):d.line([(xx,25),(xx,51)],_rgb(_shade(c,-.38)),1.1)
        d.line([(36,23),(63,23)],_rgb(_shade(b,.66)),1.4)
        d.ellipse((44,15,54,26),_rgb(_shade(c,-.34)))
    elif kind=='crate':
        d.rect((17,61,82,111),_rgb(_shade(b,-.25)),_rgb(_shade(c,-.54)),2)
        for yy in (64,75,86,97,108):
            d.line([(20,yy),(79,yy)],_rgb(_shade(b,.30)),1)
            d.line([(20,yy+2),(79,yy+2)],_rgb(_shade(b,-.28)),.5)
        for pts in ([ (21,65),(77,105) ],[(77,65),(21,105)]):
            d.line(pts,_rgb(_shade(c,-.39)),3.2)
            d.line([(x-1,y-1) for x,y in pts],_rgb(_shade(b,.22)),.7)
        for xx in (21,77):
            for yy in (65,106):d.ellipse((xx-1,yy-1,xx+2,yy+2),_rgb(_shade(b,.81)))
    else: # banner
        d.rect((44,13,51,119),_rgb(_shade(b,-.46)))
        d.line([(47,17),(86,28)],_rgb(_shade(b,.30)),2)
        d.poly([(48,22),(82,31),(78,88),(65,78),(47,83)],_rgb(_shade(a,-.21)))
        for xx in (52,59,69,77):d.line([(xx,30),(xx-1,75)],_rgb(_shade(a,.24)),.7)
        d.poly([(64,40),(73,54),(64,66),(56,54)],_rgb(_shade(b,.67)))
        d.ellipse((61,51,66,56),_rgb(_shade(c,-.3)))
    return _reduce(layer,(96,128))


def enemy_sheet(asset_id,region,boss=False):
    """Four poses rendered as separate 3x antialiased cells; coherent anatomy.

    Chapter 2 and 3 boss IDs have distinct parasite/sentinel silhouettes rather
    than picking one arbitrary generic creature from a hash.
    """
    a,b,c=_palette(region)
    seed=_seed(asset_id,'refined-enemy')
    r=random.Random(seed)
    kind=(0 if 'ch002' in asset_id else 1 if 'ch003' in asset_id else 2+seed%5)
    scale=3; W=128; H=128
    out=Image.new('RGBA',(512,128))
    eye=_shade(b,.89);glow=_shade(a,.73);armor=_shade(c,-.27)
    for frame in range(4):
        master=Image.new('RGBA',(W*scale,H*scale));d=Ink(master,scale)
        sway=(-3,0,4,1)[frame];lift=(1,0,-1,0)[frame]
        # Sprite's shadow is optically grounded, not opaque.
        d.ellipse((17,110,111,122),(14,26,38,51))
        if kind==0: # Fog-tide parasite — jelly mass, vascular tendrils, coral hooks.
            # Individually jointed legs and distinct alternating attack poses.
            for j in range(9):
                xx=26+j*9; reach=9+(j%3)*8
                tx=xx+math.sin(j*1.8+frame*.64)*reach
                d.line([(xx,85),(xx-4,98+lift*2),(tx,113-j%3*2)],
                       _rgb(_shade(c,-.4),239),3.5 if j%2==0 else 2.1)
                d.line([(xx-1,88),(xx-3,99),(tx,112-j%3*2)],_rgb(glow,215),.9)
                d.ellipse((tx-2,109-j%3*2,tx+2,114-j%3*2),_rgb(_shade(b,.65),220))
            for j in range(4):
                xx=29+j*21
                d.poly([(xx,65),(xx-7,39+sway),(xx+4,45+sway),(xx+9,69)],
                       _rgb(_shade(c,-.32)))
            body=[(21,86),(18,70+sway),(27,49+sway),(40,34+sway),
                  (58,26+sway),(77,31+sway),(95,47+sway),(109,69+sway),
                  (104,90),(86,101),(43,101)]
            d.poly(body,_rgb(_shade(c,-.42),242),_rgb(_shade(c,.29)),1.2)
            d.poly([(25,78),(32,54+sway),(46,40+sway),(64,35+sway),
                    (86,48+sway),(99,69+sway),(94,86),(79,94),(43,94)],
                   _rgb(_mix(a,c,.36),235))
            # Three translucent folds give depth to the membrane.
            for j in range(3):
                d.arc((28+j*8,35+sway+j*7,101-j*5,91-j*4),200,335,_rgb(_shade(a,.65),173),1.5)
            for j in range(22):
                px=r.randint(35,89);py=r.randint(49,84)
                d.ellipse((px,py,px+r.uniform(.9,3.1),py+r.uniform(1,3)),
                          _rgb(_shade(a,r.uniform(.24,.78)),r.randrange(95,220)))
            # Off-center asymmetric bioluminescent eye clusters, not a smiley.
            for x,y,rr in ((45,70,5.7),(63,66,4.4),(73,77,3.4)):
                d.ellipse((x-rr-2,y-rr-2,x+rr+2,y+rr+2),_rgb(glow,76))
                d.ellipse((x-rr,y-rr,x+rr,y+rr),_rgb(eye))
                d.ellipse((x-rr/3,y-rr/3,x+rr/3,y+rr/3),_rgb(_shade(c,-.75)))
                d.ellipse((x-rr/2,y-rr/2,x-rr/4,y-rr/4),_rgb((255,248,207)))
            d.line([(38,88),(48,95),(70,96),(88,84)],_rgb(_shade(c,-.64)),2.1)
            for j in range(6):
                xx=39+j*9
                d.poly([(xx,94),(xx+3,99),(xx+6,94)],_rgb(_shade(b,.62)))
        elif kind==1: # Tide-mark sentinel: coral armour, asymmetric halberd.
            d.line([(96,24+lift),(98,109)],_rgb(_shade(b,-.46)),4.5)
            d.line([(95,33+lift),(96,103)],_rgb(_shade(b,.43)),1.1)
            d.poly([(92,27),(101,14+lift),(108,29),(99,46)],_rgb(_shade(b,.64)))
            d.poly([(30,107),(37,43+sway),(55,28+sway),(74,31+sway),
                    (90,47+sway),(98,108)],_rgb(armor),_rgb(_shade(c,.36)),1.4)
            d.poly([(38,83),(43,53+sway),(60,39+sway),(80,54+sway),
                    (86,84),(75,102),(44,103)],_rgb(_shade(a,-.18)))
            for j in range(5):
                yy=49+j*11
                d.poly([(43+j%2*2,yy),(60,yy-5),(81-j%2*2,yy),
                        (77,yy+8),(49,yy+8)],_rgb(_shade(c,-.28+j*.1)),_rgb(_shade(b,.23)),.85)
            d.poly([(44,43+sway),(54,21+sway),(60,38+sway),(70,17+sway),
                    (84,43+sway)],_rgb(_shade(c,.12)))
            for j in range(7):
                xx=43+j*6;yy=59+(j%3)*8
                d.poly([(xx,yy),(xx+4,yy-5),(xx+7,yy+1)],_rgb(_shade(b,.44),226))
            d.ellipse((51,51+sway,64,62+sway),_rgb(eye),_rgb(_shade(c,-.54)),1)
            d.ellipse((69,51+sway,82,62+sway),_rgb(eye),_rgb(_shade(c,-.54)),1)
            for xx in (55,73):d.rect((xx,54+sway,xx+4,60+sway),_rgb(_shade(c,-.77)))
            d.line([(52,91),(73,91)],_rgb(_shade(c,-.65)),1.7)
            for j in range(5):
                d.line([(30+j*13,92),(35+j*13,102)],_rgb(_shade(a,.31)),1)
        else:
            category=kind-2
            if category==0: # Riveted beetle with articulated legs.
                for side in (-1,1):
                    for j in range(3):
                        xx=64+side*(23+j*8)
                        d.line([(64+side*18,68+j*10),(xx,90+j*3),
                                (xx+side*15,108+j%2*3)],_rgb(_shade(c,-.34)),4)
                d.ellipse((26,36+sway,101,101),_rgb(_shade(c,-.4)),_rgb(_shade(b,.3)),1.2)
                d.poly([(29,66),(44,36+sway),(64,27+sway),(88,41+sway),
                        (99,73),(79,99),(47,99)],_rgb(_shade(a,-.12)))
                d.line([(64,36+sway),(63,94)],_rgb(_shade(c,-.6)),3)
                for xx in (42,86):
                    d.ellipse((xx-5,58,xx+5,67),_rgb(eye))
                for j in range(8):
                    xx=38+j*7;yy=53+j%3*12
                    d.ellipse((xx,yy,xx+3,yy+5),_rgb(_shade(b,.4),214))
            elif category==1: # Faceted mineral wyrm.
                d.poly([(21,97),(33,57+sway),(58,23+sway),(88,31+sway),
                        (109,76),(88,106),(51,105)],_rgb(_shade(c,-.47)))
                for j in range(10):
                    xx=30+j*7
                    d.poly([(xx,69),(xx+5,28+sway-(j%3)*7),
                            (xx+12,75),(xx+5,96)],_rgb(_shade(a,j%3*.20-.18)),_rgb(_shade(c,.37)),.8)
                d.ellipse((54,79,68,89),_rgb(eye))
                d.line([(59,31+sway),(54,73)],_rgb(_shade(b,.8)),1.2)
            elif category==2: # Rune-forged sentinel engine.
                d.rect((38,37+sway,91,101),_rgb(_shade(c,-.36)),_rgb(_shade(b,.38)),2.2)
                d.poly([(40,34+sway),(64,13+sway),(90,34+sway)],_rgb(_shade(c,-.14)))
                for xx in (30,100):
                    d.line([(xx,50),(xx,97)],_rgb(_shade(c,-.48)),6)
                    d.ellipse((xx-7,94,xx+7,107),_rgb(_shade(b,-.38)))
                d.ellipse((45,49,84,87),_rgb(_shade(a,.12)),_rgb(_shade(b,.62)),3)
                d.ellipse((54,58,74,78),_rgb(eye,236))
                for j in range(12):
                    theta=j*math.tau/12
                    d.line([(65+22*math.cos(theta),68+22*math.sin(theta)),
                            (65+26*math.cos(theta),68+26*math.sin(theta))],_rgb(_shade(b,.67)),1)
            elif category==3: # Scaled serpentine creature.
                for j in range(7):
                    xx=29+j*11; yy=80+math.sin(j+frame*.5)*12
                    d.ellipse((xx-15,yy-16,xx+15,yy+14),_rgb(_shade(a,-.4+j*.06)))
                    d.arc((xx-10,yy-13,xx+11,yy+9),190,320,_rgb(_shade(a,.5)),1.4)
                d.ellipse((68,37+sway,108,79+sway),_rgb(_shade(c,-.23)))
                for xx in (81,97):d.ellipse((xx-3,51+sway,xx+4,59+sway),_rgb(eye))
                d.line([(99,70+sway),(117,65+sway)],_rgb(_shade(b,.27)),2)
            else: # Spectral moth, readable wings and star-shaped thorax.
                d.poly([(63,70),(25,22+sway),(12,65),(30,100),(63,93)],_rgb(_shade(c,-.16),231))
                d.poly([(66,70),(103,19+sway),(119,70),(97,102),(65,93)],_rgb(_shade(a,-.26),231))
                for xx in (33,96):
                    d.ellipse((xx-13,49,xx+13,76),_rgb(_shade(b,.18),180))
                    d.ellipse((xx-5,58,xx+5,67),_rgb(_shade(c,.49),195))
                d.ellipse((50,47+sway,81,99+sway),_rgb(_shade(c,-.45)))
                for xx in (58,73):d.ellipse((xx-3,61,xx+3,67),_rgb(eye))
                d.line([(60,49+sway),(51,35+sway)],_rgb(_shade(b,.72)),1.3)
                d.line([(72,49+sway),(82,34+sway)],_rgb(_shade(b,.72)),1.3)
        if boss:
            # A constrained star-ring is a motif, not the creature's main shape.
            d.arc((12,18,117,117),197,343,_rgb(_shade(b,.5),154),.9)
            for xx,yy in ((28,32),(99,30),(64,16)):
                d.ellipse((xx-1,yy-1,xx+1,yy+1),_rgb(_shade(b,.85),196))
        cell=_reduce(master,(W,H))
        out.paste(cell,(frame*W,0))
    return out


def landscape(entry,region):
    """Multi-plane illustration with coastline, architecture, roads, vegetation and light.

    Decorative backdrop only. Never used to derive game collision or a walkable
    layout; it must not be treated as a real level map.
    """
    a,b,c=_palette(region)
    r=random.Random(_seed(entry['id'],'refined-landscape'))
    w,h=1152,648
    im=Image.new('RGB',(w,h));d=ImageDraw.Draw(im,'RGB')
    horizon=337 if 'coast' in region['id'] else 310
    for yy in range(h):
        t=yy/max(1,h-1)
        sky=_mix(_shade(c,.64),_shade(a,.19),min(1,t*1.16))
        if yy>horizon:sky=_mix(_shade(a,-.15),_shade(c,-.37),min(1,(yy-horizon)/(h-horizon)))
        d.line((0,yy,w,yy),fill=sky)
    # Layered clouds are wide horizontal brushstrokes with mild transparency.
    halo=Image.new('RGBA',(w,h));g=ImageDraw.Draw(halo,'RGBA')
    sun=(r.randrange(735,943),r.randrange(102,160))
    for rr,opacity in ((160,7),(110,11),(70,26),(46,79)):
        g.ellipse((sun[0]-rr,sun[1]-rr,sun[0]+rr,sun[1]+rr),fill=_rgb(_shade(b,.80),opacity))
    g.ellipse((sun[0]-31,sun[1]-31,sun[0]+31,sun[1]+31),fill=_rgb(_shade(b,.89),235))
    for i in range(26):
        x=r.randrange(-160,w);y=r.randrange(65,280)
        width=r.randrange(70,260)
        for j in range(3):
            g.ellipse((x+j*30,y+j*4,x+width+j*28,y+14+j*5),fill=(244,235,211,r.randrange(7,20)))
    im=Image.alpha_composite(im.convert('RGBA'),halo)
    d=ImageDraw.Draw(im,'RGBA')
    # Six faceted mountain planes; texture follows the shape instead of noise.
    for layer in range(6):
        baseline=228+layer*48
        tone=_shade(_mix(a,c,min(.98,layer*.145)), -.04-layer*.055)
        edge=[(-20,baseline)]
        wavelength=84-layer*6
        for x in range(0,w+80,wavelength):
            height=20+layer*8
            yy=baseline+math.sin(x*.008+layer*.4)*height+r.randint(-26,23)
            edge.append((x,yy))
        edge.append((w+20,baseline))
        d.polygon(edge+[(w+20,h),(-20,h)],fill=_rgb(tone))
        d.line(edge,fill=_rgb(_shade(tone,.3),100),width=2)
        for i in range(42):
            xx=r.randrange(w);yy=r.randrange(max(5,baseline-40),min(h,baseline+22))
            dl=r.randrange(7,28)
            d.line((xx,yy,xx+dl,yy-r.randrange(0,5)),fill=_rgb(_shade(tone,.41),r.randrange(35,90)),width=1)
    sea='coast' in region['id'] or 'isles' in region['id']
    if sea:
        sea_tone=_shade(c,-.10)
        d.polygon([(0,397),(240,395),(405,402),(610,390),(800,405),(1152,395),(1152,648),(0,648)],fill=_rgb(sea_tone))
        for i in range(480):
            yy=r.randrange(402,642);xx=r.randrange(w)
            width=2+int((yy-390)/10*r.random())
            d.line((xx,yy,xx+width,yy),fill=_rgb(_shade(a,r.uniform(.12,.75)),r.randrange(33,135)))
        # Foamy shore extends along a diagonal, not a rectangular shore strip.
        beach=[(0,581),(195,560),(363,531),(502,534),(662,554),(814,569),(1003,550),(1152,563)]
        d.polygon(beach+[(w,h),(0,h)],fill=_rgb(_shade(b,.24)))
        d.line(beach,fill=_rgb(_shade(b,.78),226),width=4)
        for i in range(90):
            xx=r.randrange(w);yy=r.randrange(562,648)
            d.line((xx,yy,xx+r.randrange(3,12),yy),fill=_rgb(_shade(b,r.uniform(-.24,.34)),r.randrange(40,130)))
    # Village is arranged on linked terraces with coherent base level.
    is_town=entry.get('type') in ('town','landmark')
    if is_town:
        # Earthen terrace above the waterline: buildings must not float on sea.
        terrace=_mix(_shade(b,-.22),_shade(c,-.20),.24)
        d.polygon([(0,520),(186,472),(394,483),(595,458),(762,471),
                   (960,453),(1152,477),(1152,595),(0,575)],fill=_rgb(terrace))
        d.line([(0,520),(186,472),(394,483),(595,458),(762,471),
                (960,453),(1152,477)],fill=_rgb(_shade(b,.44)),width=6)
        for tx in range(0,w,42):
            ty=524+math.sin(tx*.017)*9
            d.line((tx,ty,tx+22,ty),fill=_rgb(_shade(terrace,-.22)),width=2)
        road=[(533,463),(602,463),(662,648),(381,648)]
        d.polygon(road,fill=_rgb(_shade(b,-.15),231))
        d.line([(539,466),(394,646)],fill=_rgb(_shade(b,.33)),width=3)
        d.line([(597,466),(652,646)],fill=_rgb(_shade(b,-.37)),width=3)
        for j in range(60):
            yy=r.randrange(476,648);xx=r.randrange(max(0,int(536-(yy-460)*.8)),min(w,int(601+(yy-460)*.3)))
            d.line((xx,yy,xx+r.randrange(3,11),yy),fill=_rgb(_shade(b,r.uniform(-.27,.32)),130),width=1)
        houses=[(62,468,63),(153,492,86),(286,483,73),(402,465,70),
                (727,470,60),(832,475,83),(964,464,70),(1065,492,61)]
        for idx,(xx,yy,size) in enumerate(houses):
            size=int(size*(.85+.19*r.random()))
            wall=_shade(b,r.uniform(-.09,.26));roof=_shade(c,r.uniform(-.36,-.13))
            d.polygon([(xx,yy-size*.55),(xx+size,yy-size*.55),(xx+size,yy),(xx,yy)],fill=_rgb(wall))
            d.polygon([(xx-7,yy-size*.56),(xx+size*.5,yy-size*.96),
                       (xx+size+8,yy-size*.56),(xx+size+3,yy-size*.50),
                       (xx+size*.5,yy-size*.85),(xx-2,yy-size*.50)],fill=_rgb(roof))
            d.line((xx-3,yy-size*.55,xx+size*.5,yy-size*.92,xx+size+4,yy-size*.55),fill=_rgb(_shade(roof,.42)),width=2)
            for j in range(3):
                ytile=int(yy-size*.79+j*size*.08)
                half=(ytile-(yy-size*.96))*1.4
                for tx in range(int(xx+size*.5-half),int(xx+size*.5+half),9):
                    d.line((tx,ytile,tx+4,ytile),fill=_rgb(_shade(roof,.21 if j%2 else -.19)),width=1)
            for wx in (xx+9,xx+size-19):
                d.rectangle((wx,yy-size*.38,wx+10,yy-size*.2),fill=_rgb(_shade(c,-.48)))
                d.rectangle((wx+2,yy-size*.35,wx+8,yy-size*.25),fill=_rgb(_shade(a,.66)))
                d.line((wx+5,yy-size*.38,wx+5,yy-size*.2),fill=_rgb(_shade(b,-.30)),width=1)
            d.rectangle((xx+size*.43,yy-size*.32,xx+size*.62,yy),fill=_rgb(_shade(c,-.48)))
            d.line((xx+size*.62,yy-size*.32,xx+size*.62,yy),fill=_rgb(_shade(b,.33)),width=2)
            # Chimney, posts and soft grounding make sense as architecture.
            d.rectangle((xx+size*.76,yy-size*.85,xx+size*.84,yy-size*.59),fill=_rgb(_shade(b,-.27)))
            for j in range(14):
                bx=int(xx+r.randrange(max(1,size)))
                by=int(yy-size*.54+r.randrange(max(1,int(size*.5))))
                d.line((bx,by,bx+2,by),fill=_rgb(_shade(wall,-.26),115))
        # Tree and rock clusters anchor structures instead of floating symbols.
        for idx in range(63):
            xx=r.randrange(w);yy=r.randrange(487,598)
            if 386<xx<670:continue
            radius=r.randrange(4,12)
            col=_shade(a,r.uniform(-.34,-.10))
            d.ellipse((xx-radius,yy-2*radius,xx+radius,yy),fill=_rgb(col))
            d.line((xx-radius*.6,yy-radius*1.1,xx+radius*.28,yy-radius*1.8),fill=_rgb(_shade(col,.43)),width=2)
    else:
        for i in range(160):
            xx=r.randrange(w);yy=r.randrange(471,625)
            rad=r.randrange(3,16)
            col=_shade(a,r.uniform(-.43,-.07))
            d.ellipse((xx-rad,yy-rad*2,xx+rad,yy+rad*.4),fill=_rgb(col))
            d.arc((xx-rad+2,yy-rad*2+2,xx+rad-2,yy+rad*.3),192,310,fill=_rgb(_shade(col,.4)),width=1)
    # Foreground vignette translucent foliage (not occluding map controls).
    fg=Image.new('RGBA',(w,h));fd=ImageDraw.Draw(fg,'RGBA')
    for side in (0,1):
        for j in range(40):
            xx=r.randrange(0,130) if side==0 else r.randrange(1022,1152)
            yy=r.randrange(490,648);rr=r.randrange(9,28)
            fd.ellipse((xx-rr,yy-rr,xx+rr,yy+rr),fill=_rgb(_shade(a,-.3),r.randrange(15,57)))
    im=Image.alpha_composite(im,fg)
    return im.convert('RGB')