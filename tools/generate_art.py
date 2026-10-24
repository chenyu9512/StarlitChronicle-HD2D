#!/usr/bin/env python3
"""Regenerates all original CC0-style in-project pixel assets using Pillow.
No AI images, downloaded art, copyrighted Dragon Quest assets, or paid APIs.
Generated sprites were created specifically for Starlit Chronicle.
"""
from pathlib import Path
import json, random, math
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
for sub in ['data','assets/maps','assets/props','assets/characters','assets/enemies','assets/fx']:
 (ROOT/sub).mkdir(parents=True,exist_ok=True)
R=random.Random(90210)
T=32; W=44; H=28

def rgba(s): return (*s,255)

def pixel(img,x,y,color,w=1,h=1):
 ImageDraw.Draw(img).rectangle((x,y,x+w-1,y+h-1), fill=color)

def draw_tile(d,x,y,t,night,seed):
 r=random.Random(seed)
 if night:
  colors={'d':(45,49,66),'s':(61,62,78),'W':(30,32,46),'p':(78,73,80),'w':(21,48,75)}
 else:
  colors={'.':(81,144,103),',':(80,145,99),'p':(184,153,107),'w':(47,111,139),'W':(42,76,76)}
 base=colors.get(t,(82,148,101))
 d.rectangle((x,y,x+31,y+31), fill=base)
 if t in ['s','d','W']:
  for k in range(7):
   px=x+r.randint(0,30); py=y+r.randint(0,30)
   shade=r.choice([(100,96,114),(39,43,59),(80,81,96),(65,62,76)])
   d.rectangle((px,py,px+r.randint(1,4),py+r.randint(0,1)),fill=shade)
  if t=='s':
   d.line([(x+0,y+16),(x+31,y+16)],fill=(40,41,58),width=1)
   d.line([(x+16,y),(x+16,y+16)], fill=(40,41,58),width=1)
   d.line([(x+8,y+17),(x+8,y+31)], fill=(42,43,60),width=1)
 elif t=='p':
  for k in range(22):
   px=x+r.randint(0,31); py=y+r.randint(0,31)
   d.point((px,py), fill=r.choice([(221,190,131),(136,117,90),(166,139,101)]))
  if r.random()<.4: d.arc((x+5,y+6,x+22,y+23),30,100,fill=(135,114,92),width=1)
 elif t=='w':
  for k in range(3):
   yy=y+r.randint(2,29); xx=x+r.randint(2,15)
   d.line((xx,yy,xx+r.randint(6,13),yy),fill=(111,180,190),width=2)
 elif t in ['.',',']:
  for k in range(13):
   px=x+r.randint(0,31); py=y+r.randint(0,31)
   shade=r.choice([(65,122,85),(117,165,105),(101,156,97),(70,131,86)])
   d.point((px,py),fill=shade)
  if t==',':
   for k in range(r.randint(1,3)):
    px=x+r.randint(4,27); py=y+r.randint(4,28)
    d.rectangle((px,py,px+1,py+1),fill=r.choice([(251,208,142),(249,230,190),(238,160,178)]))

def make_tiles(night=False):
 rows=[]
 for y in range(H):
  line=[]
  for x in range(W):
   if night:
    tile='s'
    if x in (0,1,W-2,W-1) or y in (0,1,H-2,H-1): tile='W'
    if x in range(10,17) and y in (6,7,8,9) and x not in (12,13): tile='W'
    if x in range(25,32) and y in (19,20,21) and x not in (28,29): tile='W'
    if (x+y)%17==0 and tile=='s': tile='d'
   else:
    tile=',' if R.random()<.16 else '.'
    if x in (0,W-1) or y in (0,H-1): tile='W'
    elif abs(y-14)<=1 or abs(x-12)<=1 or (x>=36 and 11<=y<=17): tile='p'
    if 32 <= x <= 36 and 20 <= y <= 24: tile='w'
   line.append(tile)
  rows.append(''.join(line))
 return rows

village_props=[
 {'id':'elder','kind':'elder','x':12,'y':11,'interact':'elder'},
 {'id':'merchant','kind':'merchant','x':19,'y':14,'interact':'merchant'},
 {'id':'ruins_gate','kind':'portal','x':40,'y':14,'interact':'portal_to_ruins'},
 {'id':'village_well','kind':'well','x':15,'y':21,'interact':'well','solid':[1,1]},
 {'id':'stone','kind':'monument','x':29,'y':17,'interact':'monument','solid':[1,1]},
 {'id':'home1','kind':'house','x':5,'y':10,'solid':[3,2]},
 {'id':'home2','kind':'house','x':25,'y':9,'solid':[3,2]},
 {'id':'treeA','kind':'tree','x':4,'y':20,'solid':[1,1]},
 {'id':'treeB','kind':'tree','x':8,'y':22,'solid':[1,1]},
 {'id':'treeC','kind':'tree','x':22,'y':20,'solid':[1,1]},
 {'id':'treeD','kind':'tree','x':30,'y':23,'solid':[1,1]},
 {'id':'treeE','kind':'tree','x':37,'y':9,'solid':[1,1]},
 {'id':'treeF','kind':'tree','x':35,'y':5,'solid':[1,1]},
 {'id':'treeG','kind':'tree','x':17,'y':6,'solid':[1,1]},
 {'id':'flower1','kind':'flowers','x':22,'y':9},
 {'id':'flower2','kind':'flowers','x':20,'y':22},
 {'id':'flower3','kind':'flowers','x':29,'y':19},
 {'id':'lamp1','kind':'lamp','x':16,'y':11},
 {'id':'lamp2','kind':'lamp','x':33,'y':12},
 {'id':'lamp3','kind':'lamp','x':11,'y':20},
]
ruins_props=[
 {'id':'ruins_exit','kind':'portal','x':2,'y':14,'interact':'portal_to_village'},
 {'id':'ruins_chest','kind':'chest','x':26,'y':17,'interact':'chest','solid':[1,1]},
 {'id':'boss','kind':'altar','x':39,'y':12,'interact':'boss','solid':[1,1]},
 {'id':'tablet','kind':'monument','x':19,'y':11,'interact':'monument','solid':[1,1]},
 {'id':'crystal_1','kind':'crystal','x':10,'y':18,'solid':[1,1]},
 {'id':'crystal_2','kind':'crystal','x':27,'y':7,'solid':[1,1]},
 {'id':'crystal_3','kind':'crystal','x':35,'y':21,'solid':[1,1]},
 {'id':'lamp4','kind':'lamp','x':7,'y':10},
 {'id':'lamp5','kind':'lamp','x':23,'y':15},
 {'id':'lamp6','kind':'lamp','x':35,'y':12},
]
for name,night,props in [('village',False,village_props),('ruins',True,ruins_props)]:
 rows=make_tiles(night)
 # make sure spawn and main roads are not walled
 ground=Image.new('RGB',(W*T,H*T))
 d=ImageDraw.Draw(ground)
 for y,row in enumerate(rows):
  for x,t in enumerate(row):draw_tile(d,x*T,y*T,t,night,90210+x*97+y*113)
 ground.save(ROOT/f'assets/maps/{name}.png',optimize=True)
 (ROOT/f'data/{name}.json').write_text(json.dumps({'width':W,'height':H,'tiles':rows,'props':props},ensure_ascii=False,indent=2),encoding='utf8')

# Pixel-art props. Every sprite centers on its feet in the engine.
def spr(name,w,h,artist):
 im=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(im)
 artist(d,w,h)
 im.save(ROOT/f'assets/props/{name}.png',optimize=True)

def tree(d,w,h):
 d.ellipse((7,60,55,73),fill=(20,48,42,100))
 d.rectangle((28,37,36,71),fill=(91,65,48))
 d.rectangle((32,41,35,68),fill=(139,91,56))
 for box,c in [((10,25,53,59),(34,87,66)),((5,15,51,52),(45,110,77)),((15,6,56,44),(56,140,84)),((2,28,34,57),(60,140,90))]:
  d.ellipse(box,fill=c)
 for xx,yy in [(12,27),(24,15),(43,25),(29,38),(12,47),(36,10)]:
  d.rectangle((xx,yy,xx+6,yy+3),fill=(108,180,105))
spr('tree',64,78,tree)

def house(d,w,h):
 d.ellipse((4,73,106,84),fill=(25,37,38,75))
 d.rectangle((13,36,103,80),fill=(219,186,127))
 d.rectangle((17,40,99,76),outline=(113,82,72),width=3)
 d.polygon([(4,39),(55,5),(111,39)],fill=(122,63,81))
 d.line([(4,39),(55,5),(111,39)],fill=(220,120,118),width=6)
 d.rectangle((49,52,69,81),fill=(79,62,69))
 d.rectangle((52,55,66,80),fill=(121,91,79))
 for x in [23,80]:
  d.rectangle((x,48,x+14,62),fill=(61,117,139))
  d.line((x+7,48,x+7,62),fill=(232,202,148),width=2)
 d.rectangle((39,19,75,24),fill=(199,115,100))
spr('house',116,88,house)

def portal(d,w,h):
 d.ellipse((3,53,55,65),fill=(23,32,45,110))
 d.rectangle((9,12,49,61),fill=(53,63,80))
 d.pieslice((9,0,49,40),180,360,fill=(128,130,150))
 d.rectangle((14,20,43,61),fill=(29,46,74))
 d.pieslice((14,9,43,40),180,360,fill=(34,56,91))
 d.line((14,20,14,61),fill=(192,176,125),width=2)
 d.line((43,20,43,61),fill=(192,176,125),width=2)
 for p in [(20,32),(27,38),(36,25)]:
  d.ellipse((p[0],p[1],p[0]+3,p[1]+3),fill=(246,209,119))
spr('portal',58,66,portal)

def lamp(d,w,h):
 d.ellipse((4,60,37,67),fill=(24,38,42,110))
 d.rectangle((18,15,23,63),fill=(89,67,73))
 d.rectangle((12,13,29,33),fill=(228,173,81))
 d.rectangle((16,17,25,29),fill=(255,236,143))
 d.line((10,14,32,14),fill=(111,79,62),width=5)
 d.polygon([(10,14),(21,5),(32,14)],fill=(122,81,73))
spr('lamp',42,69,lamp)

def crystal(d,w,h):
 d.ellipse((7,48,48,61),fill=(20,35,59,110))
 d.polygon([(17,14),(29,2),(43,18),(38,53),(24,57),(12,46)],fill=(44,157,197))
 d.polygon([(17,14),(29,2),(24,55),(12,46)],fill=(88,205,225))
 d.polygon([(29,2),(43,18),(38,53),(24,55)],fill=(47,116,187))
 d.line((29,7,28,37),fill=(215,247,246),width=3)
spr('crystal',56,62,crystal)

def altar(d,w,h):
 d.ellipse((3,63,96,79),fill=(13,20,42,120))
 d.rectangle((15,47,86,70),fill=(70,63,92))
 d.polygon([(28,47),(50,18),(72,47)],fill=(136,129,179))
 d.polygon([(50,3),(60,20),(50,43),(40,20)],fill=(238,173,116))
 d.polygon([(50,8),(50,39),(43,21)],fill=(255,227,162))
 for x in [22,75]:d.rectangle((x,52,x+5,65),fill=(184,159,127))
spr('altar',100,80,altar)

def elder(d,w,h):
 d.ellipse((9,53,38,61),fill=(20,38,44,115))
 d.polygon([(18,17),(36,17),(42,54),(10,54)],fill=(72,88,121))
 d.rectangle((17,22,35,33),fill=(221,188,147))
 d.ellipse((18,5,36,24),fill=(240,208,170))
 d.arc((16,4,38,24),180,350,fill=(201,209,225),width=5)
 d.polygon([(21,24),(34,24),(30,39),(24,39)],fill=(222,220,208))
 d.line((43,16,43,56),fill=(145,106,83),width=3)
 d.ellipse((39,8,48,18),fill=(255,206,114))
spr('elder',52,62,elder)

def merchant(d,w,h):
 d.ellipse((7,51,40,60),fill=(20,35,40,115))
 d.polygon([(14,24),(34,24),(44,55),(6,55)],fill=(121,86,68))
 d.ellipse((16,8,35,29),fill=(230,175,132))
 d.polygon([(10,12),(24,2),(43,13)],fill=(51,90,97))
 d.rectangle((4,34,20,44),fill=(167,121,81))
 d.rectangle((6,34,19,37),fill=(217,169,112))
spr('merchant',49,61,merchant)

def well(d,w,h):
 d.ellipse((4,38,65,65),fill=(36,50,62,130))
 d.ellipse((8,26,60,57),fill=(139,144,143))
 d.ellipse((16,33,52,47),fill=(46,117,160))
 d.arc((8,25,60,57),0,180,fill=(214,211,184),width=6)
 d.line((17,35,17,4),fill=(116,86,72),width=4)
 d.line((53,35,53,4),fill=(116,86,72),width=4)
 d.polygon([(10,9),(35,-1),(60,9)],fill=(131,74,83))
spr('well',68,66,well)

def monument(d,w,h):
 d.ellipse((4,53,51,63),fill=(23,35,40,110))
 d.polygon([(9,55),(13,12),(23,3),(44,8),(48,54)],fill=(130,137,150))
 d.line((23,17,35,17),fill=(195,181,125),width=2)
 d.line((27,25,27,44),fill=(195,181,125),width=2)
 d.line((19,33,37,33),fill=(195,181,125),width=2)
spr('monument',56,66,monument)

def chest(d,w,h):
 d.ellipse((2,36,51,47),fill=(25,37,42,100))
 d.rectangle((6,14,47,40),fill=(108,63,54))
 d.pieslice((6,5,47,31),180,360,fill=(165,93,52))
 d.line((8,24,45,24),fill=(239,181,85),width=4)
 d.rectangle((23,18,30,34),fill=(222,184,89))
 d.rectangle((25,22,28,29),fill=(91,69,63))
spr('chest',54,47,chest)

def chest_open(d,w,h):
 d.ellipse((2,36,51,47),fill=(25,37,42,100))
 d.rectangle((6,24,47,41),fill=(108,63,54))
 d.polygon([(6,22),(8,7),(42,1),(47,14)],fill=(164,95,60))
 d.rectangle((23,25,30,33),fill=(226,170,79))
spr('chest_open',54,47,chest_open)

def flowers(d,w,h):
 for cx,cy,c in [(6,13,(255,227,174)),(15,4,(255,176,183)),(23,16,(229,219,178)),(12,23,(202,189,244))]:
  d.line((cx,cy+4,cx+1,cy+10),fill=(52,117,70),width=2)
  d.ellipse((cx-3,cy-3,cx+3,cy+3),fill=c)
  d.rectangle((cx,cy,cx+1,cy+1),fill=(243,169,67))
spr('flowers',32,32,flowers)

# 3 frames (left step, idle, right step) x 4 compass directions.
def character_sheet(name,palette,has_cape=False):
 sheet=Image.new('RGBA',(32*3,48*4),(0,0,0,0))
 for row in range(4):
  for col in range(3):
   s=Image.new('RGBA',(32,48),(0,0,0,0)); d=ImageDraw.Draw(s)
   yoff=-1 if col==1 else 0
   d.ellipse((8,40,24,45),fill=(19,23,40,90))
   d.rectangle((10,34+yoff,14,43+yoff),fill=(55,52,75))
   d.rectangle((18,34+yoff,22,43+yoff),fill=(55,52,75))
   if col==0: d.rectangle((10,35,14,44),fill=(89,80,109))
   if col==2: d.rectangle((18,35,22,44),fill=(89,80,109))
   if has_cape:d.polygon([(8,16),(24,16),(28,39),(4,39)],fill=palette['cape'])
   d.polygon([(10,19+yoff),(23,19+yoff),(25,36+yoff),(8,36+yoff)],fill=palette['shirt'])
   d.rectangle((8,22+yoff,12,35+yoff),fill=palette['arm'])
   d.rectangle((22,22+yoff,26,35+yoff),fill=palette['arm'])
   d.rectangle((14,30+yoff,20,33+yoff),fill=palette['accent'])
   d.ellipse((9,3+yoff,23,22+yoff),fill=palette['face'])
   d.pieslice((7,0+yoff,26,20+yoff),180,360,fill=palette['hair'])
   d.rectangle((9,5+yoff,24,11+yoff),fill=palette['hair'])
   if row==2: # back
    d.rectangle((11,11+yoff,22,20+yoff),fill=palette['hair'])
   elif row==0:
    d.point((14,14+yoff),fill=(33,39,54)); d.point((20,14+yoff),fill=(33,39,54))
   elif row==1: d.point((21,14+yoff),fill=(33,39,54))
   else: d.point((12,14+yoff),fill=(33,39,54))
   d.line((12,22+yoff,22,22+yoff),fill=(248,218,174),width=2)
   sheet.alpha_composite(s,(col*32,row*48))
 sheet.save(ROOT/f'assets/characters/{name}.png',optimize=True)
character_sheet('hero',{'cape':(76,83,143),'shirt':(64,115,160),'accent':(233,183,89),'arm':(218,173,134),'hair':(84,66,58),'face':(236,190,152)},True)
character_sheet('companion',{'cape':(177,96,143),'shirt':(137,91,156),'accent':(228,194,117),'arm':(226,188,151),'hair':(187,151,103),'face':(250,205,168)},True)

# Original enemies on transparent canvases.
def enemy(name,drawer):
 im=Image.new('RGBA',(128,128),(0,0,0,0));d=ImageDraw.Draw(im);drawer(d)
 im.save(ROOT/f'assets/enemies/{name}.png',optimize=True)

def slime(d):
 d.ellipse((25,100,111,119),fill=(10,20,40,90))
 d.polygon([(21,95),(29,62),(44,49),(59,18),(78,50),(103,66),(111,94),(93,109),(40,109)],fill=(53,171,175))
 d.polygon([(33,72),(48,54),(59,32),(70,52),(84,70)],fill=(103,211,196))
 d.ellipse((49,75,58,85),fill=(22,39,56));d.ellipse((77,75,86,85),fill=(22,39,56))
 d.arc((58,83,79,95),0,150,fill=(24,53,69),width=3)
enemy('slime',slime)

def bat(d):
 d.ellipse((22,103,105,113),fill=(9,19,37,95))
 d.polygon([(61,73),(28,39),(17,24),(8,49),(14,86),(45,95)],fill=(87,72,123))
 d.polygon([(63,73),(96,39),(108,24),(121,49),(116,86),(81,95)],fill=(87,72,123))
 d.ellipse((49,51,82,101),fill=(123,89,151))
 d.polygon([(51,60),(49,37),(61,47)],fill=(101,70,131))
 d.polygon([(80,60),(83,37),(68,47)],fill=(101,70,131))
 d.ellipse((57,70,63,77),fill=(238,166,91));d.ellipse((70,70,76,77),fill=(238,166,91))
enemy('bat',bat)

def golem(d):
 d.ellipse((14,108,118,121),fill=(10,20,43,120))
 d.polygon([(34,31),(55,19),(86,31),(100,66),(87,104),(33,104),(20,65)],fill=(104,111,131))
 d.polygon([(27,49),(37,40),(42,75),(26,91)],fill=(144,150,163))
 d.polygon([(84,40),(102,49),(106,92),(86,78)],fill=(144,150,163))
 d.rectangle((50,55,60,61),fill=(241,188,114));d.rectangle((72,55,82,61),fill=(241,188,114))
 d.line((57,82,76,81),fill=(63,70,93),width=4)
enemy('golem',golem)

def boss(d):
 d.ellipse((10,108,120,126),fill=(12,18,37,130))
 d.polygon([(31,37),(23,12),(47,27),(62,4),(78,27),(104,12),(95,44),(107,95),(79,116),(44,116),(19,94)],fill=(78,82,134))
 d.polygon([(38,40),(62,18),(88,40),(77,91),(49,91)],fill=(116,112,165))
 d.polygon([(53,57),(64,34),(76,57),(64,93)],fill=(246,179,107))
 d.polygon([(64,39),(64,85),(56,56)],fill=(255,227,154))
 d.rectangle((28,48,43,58),fill=(242,189,111));d.rectangle((87,48,102,58),fill=(242,189,111))
 d.line((13,63,4,90),fill=(169,170,199),width=8)
 d.line((112,63,123,92),fill=(169,170,199),width=8)
enemy('boss',boss)

# Radial glow simulated as alpha sprite: no high-end renderer required.
glow=Image.new('RGBA',(160,160),(0,0,0,0))
pix=glow.load()
for y in range(160):
 for x in range(160):
  radius=math.hypot(x-79.5,y-79.5)/78
  alpha=int((max(0.0,1.0-radius)**2.3)*180)
  pix[x,y]=(255,250,234,alpha)
glow.save(ROOT/'assets/fx/glow.png',optimize=True)

# Battle backdrop: distant skyline, stone walkway, light shafts, glimmers.
bg=Image.new('RGB',(1152,648));d=ImageDraw.Draw(bg)
for y in range(648):
 t=y/648
 d.line((0,y,1152,y),fill=(int(17+43*t),int(22+33*t),int(42+37*t)))
for x in range(0,1152,16):
 height=int(250+90*math.sin(x*0.022)+R.randrange(80))
 d.polygon([(x,height),(x+6,height-18),(x+26,height),(x+26,465),(x,465)],fill=(31,39,63))
for xx in [140,390,790,1030]:
 d.polygon([(xx-28,240),(xx+28,240),(xx+44,460),(xx-44,460)],fill=(60,62,88))
 d.rectangle((xx-55,222,xx+55,244),fill=(79,80,107))
for i in range(45):
 x=R.randrange(1152);y=R.randrange(15,390)
 d.rectangle((x,y,x+2,y+2),fill=R.choice([(233,203,141),(126,176,223),(213,223,245)]))
d.polygon([(0,469),(1152,469),(1152,648),(0,648)],fill=(48,50,73))
for y in range(482,648,30):
 d.line((0,y,1152,y),fill=(92,90,110),width=2)
for x in range(0,1152,80):
 d.line((x,475,x-40,648),fill=(70,68,92),width=2)
bg.save(ROOT/'assets/maps/battle_ruins.png',optimize=True)

icon=Image.new('RGBA',(256,256),(32,43,78,255));d=ImageDraw.Draw(icon)
d.ellipse((30,30,225,225),outline=(228,183,112),width=9)
d.polygon([(128,28),(156,112),(231,128),(156,146),(128,229),(99,146),(25,128),(99,112)],fill=(255,213,128))
d.polygon([(128,42),(128,207),(104,137)],fill=(255,245,195))
icon.save(ROOT/'icon.png',optimize=True)
print('Generated original assets + two 44x28 world maps')
