#!/usr/bin/env python3
"""Build every empty official Main2 art slot from project-generated imagery.

Reads the live 109-slot canonical registry, generates original per-slot images,
checks pixels/hashes, installs into a separate runtime group and fills the
canonical/UI/monster/region bindings. No files from deleted third-party packs
are opened, restored or required. Procedural results are not visual approval.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import random
import re
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

REL = Path("assets/art/runtime/generated_gaps_v10")
REG = Path("data/assets/c_art_runtime_registry_v1.json")
MAN = REL / "manifest.json"
PALETTE = {"leaf":(94,142,97),"wood":(143,96,68),"sand":(197,175,124),
           "sea":(61,127,156),"rock":(112,119,126),"paper":(223,208,172),
           "iron":(85,98,111),"light":(251,212,123),"fabric":(145,99,119)}
FAMILIES = ("scene","prop","landmark","terrain","monster","boss","material",
            "interior","background","ui","battle")

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def safe(key):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,110}",key):
        raise ValueError("Unsafe official slot: "+key)
    return key.replace(".","__").replace("-","_")

def palette(name):
    key=name.lower()
    if any(x in key for x in ("water","tide","sea","pool","brine","harbor","boat","fish","dock")):
        return PALETTE["sea"]
    if any(x in key for x in ("wood","table","bench","barrel","cask","shelf","counter","plank","chest","crate","boat","rack")):
        return PALETTE["wood"]
    if any(x in key for x in ("rock","cliff","crystal","stone","forge","anvil","ruin","cobble")):
        return PALETTE["rock"]
    if any(x in key for x in ("beach","sand","dune","ground","road")):
        return PALETTE["sand"]
    return PALETTE["leaf"]

def tinted(c,t):
    base=(246,235,201) if t>0 else (26,35,44)
    return tuple(max(0,min(255,round(v*(1-abs(t))+b*abs(t)))) for v,b in zip(c,base))

def size_for(slot,cat):
    if cat in ("material","terrain_surface") or slot.endswith("wood_atlas"):
        return (256,256)
    if cat=="scene_background":
        return (1152,648)
    if cat in ("battle_monster","battle_candidate","battle_animation"):
        return (512,128) if cat!="battle_animation" else (512,768)
    if cat=="ui_icon" or slot.startswith("ui.extra."):
        return (64,64)
    return (96,128)

def texture_image(slot,dim):
    base=palette(slot);img=Image.new("RGBA",dim,(*base,255));d=ImageDraw.Draw(img)
    seed=int(hashlib.sha256(slot.encode()).hexdigest()[:8],16);r=random.Random(seed)
    w,h=dim
    if (w,h)==(256,256):
        # 8x8 atlas, texture variants share the same exact edge color.
        for row in range(8):
            for col in range(8):
                x,y=col*32,row*32
                shade=tinted(base,((row%3)-1)*0.055)
                d.rectangle((x,y,x+31,y+31),fill=(*shade,255))
                for n in range(15):
                    px=x+r.randrange(3,28);py=y+r.randrange(3,28)
                    c=tinted(shade,r.choice((-.22,-.10,.12,.22)))
                    d.line((px,py,px+r.randrange(1,4),py),fill=(*c,255),width=1)
        return img
    if w>500 and h>500:
        # Authored procedural motion-like sheet, six poses by four columns;
        # effects do not borrow legacy exported pixels.
        img=Image.new("RGBA",dim,(0,0,0,0));d=ImageDraw.Draw(img)
        for row in range(6):
            for col in range(4):
                ox=col*128;oy=row*128
                d.arc((ox+19+col,oy+12,ox+109,oy+112),20,260,fill=(*tinted(base,.44),210),width=4)
                d.ellipse((ox+39+col*2,oy+30,ox+89+col*2,oy+91),fill=(*base,205))
        return img
    if w>500:
        # Landscape with different coast/shore silhouettes by canonical key.
        for y in range(h):
            t=y/max(1,h-1);c=tuple(int(x*(1-t)+z*t) for x,z in zip(tinted(base,.65),base))
            d.line((0,y,w,y),fill=(*c,255))
        horizon=round(h*.58)
        for x in range(0,w,14):
            hill=round(21*math.sin(x/99.0+seed%23)+12*math.sin(x/29.0+seed%11))
            d.polygon([(x,horizon+hill),(x+18,horizon+hill+9),(x+18,h),(x,h)],
                      fill=(*tinted(base,-.22),250))
        return img
    return img

def object_image(slot,cat,dim,root):
    seed=int(hashlib.sha256(slot.encode()).hexdigest()[:16],16);r=random.Random(seed)
    w,h=dim
    if cat in ("terrain_surface","material","scene_background","battle_animation") or slot.endswith("wood_atlas"):
        return texture_image(slot,dim)
    if cat in ("battle_monster","battle_candidate"):
        # Reuse only original PROJECT-GENERATED matching identity pixels where
        # available; no third-party archive enters this pipeline.
        identity=slot.split(".")[-1]
        if cat=="battle_candidate":
            identity="boss_ch%03d"%int(re.search(r"\d+",identity).group())
        original=root/"assets/art/runtime/global_factory_v3"/("monsters" if cat=="battle_monster" else "bosses")/(identity+".png")
        if original.is_file():
            with Image.open(original) as src:
                src.load();out=src.convert("RGBA")
            if out.size==dim:return out
            return out.resize(dim,Image.Resampling.LANCZOS)
        # If the registry does not contain this identity, produce an independent
        # provisional creature, never borrow another boss's identity.
        img=Image.new("RGBA",dim,(0,0,0,0));d=ImageDraw.Draw(img)
        c=palette(slot);a=256;cx=256;cy=65
        d.ellipse((cx-a//3,cy-42,cx+a//3,cy+42),fill=(*c,255),outline=(*tinted(c,-.6),255),width=4)
        for side in (-1,1):
            d.polygon([(cx+side*47,cy-18),(cx+side*102,cy-41),(cx+side*75,cy+9)],fill=(*tinted(c,-.25),255))
            d.ellipse((cx+side*20-5,cy-12,cx+side*20+5,cy-2),fill=(243,228,161,255))
        return img
    im=Image.new("RGBA",dim,(0,0,0,0));d=ImageDraw.Draw(im,"RGBA")
    ink=(31,40,48,255);wood=PALETTE["wood"];iron=PALETTE["iron"];sea=PALETTE["sea"]
    c=palette(slot);k=slot.lower()
    if w==64:
        d.rounded_rectangle((5,5,59,59),radius=12,fill=(27,42,54,245),outline=(*tinted(c,.45),255),width=3)
        if any(x in k for x in ("axe","forge","fight")):
            d.line((18,46,43,20),fill=(*PALETTE["sand"],255),width=5)
            d.polygon([(32,15),(51,23),(41,34),(28,25)],fill=(*iron,255))
        elif "home" in k:
            d.polygon([(11,29),(32,11),(53,29)],fill=(*PALETTE["sand"],255))
            d.rectangle((17,30,47,49),fill=(*wood,255));d.rectangle((29,36,37,49),fill=ink)
        else:
            d.rounded_rectangle((18,17,47,48),radius=4,fill=(*PALETTE["paper"],255),outline=ink,width=2)
            for y in (23,30,37):d.line((24,y,40,y),fill=(*sea,255),width=2)
    elif any(x in k for x in ("tree","oak","pine","mangrove","shrub")):
        d.rectangle((43,56,54,119),fill=(*wood,255),outline=ink,width=2)
        for x,y,rr in ((28,66,23),(66,65,24),(47,42,30),(52,22,19)):
            d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=(*tinted(c,(x%5)*.045),255),outline=ink,width=2)
        if "mangrove" in k:
            for x in (37,57):d.line((48,96,x,123),fill=(*wood,255),width=4)
    elif any(x in k for x in ("house","cottage","shop","stall","shrine","lighthouse","bridge","crane","arch")):
        d.rectangle((12,47,84,115),fill=(*PALETTE["sand"],255),outline=ink,width=3)
        d.polygon([(6,53),(48,15),(90,53)],fill=(*tinted(wood,-.1),255),outline=ink)
        d.rectangle((37,78,58,115),fill=ink)
        for x in (20,68):d.rectangle((x,64,x+12,80),fill=(*tinted(sea,.4),255),outline=ink,width=2)
        if "lighthouse" in k or "beacon" in k:
            d.rectangle((39,4,60,74),fill=(*PALETTE["paper"],255),outline=ink)
            d.ellipse((39,1,60,20),fill=(*PALETTE["light"],255))
        elif "crane" in k:
            d.line((12,42,80,21),fill=(*wood,255),width=5)
            d.line((69,25,69,71),fill=ink,width=2)
    elif any(x in k for x in ("water","pool","crystal","sea","boat","wreck","barge")):
        d.ellipse((8,79,88,119),fill=(*sea,170),outline=(*tinted(sea,.45),255),width=3)
        for v in range(3):d.arc((15,76+v*9,80,102+v*9),0,170,fill=(219,239,230,170),width=2)
        if any(x in k for x in ("boat","barge","wreck")):
            d.polygon([(12,77),(84,77),(72,100),(26,100)],fill=(*wood,255),outline=ink)
            d.polygon([(48,20),(48,74),(75,64)],fill=(*PALETTE["paper"],255))
        if "crystal" in k:
            d.polygon([(48,15),(67,51),(51,93),(30,62)],fill=(139,208,234,255),outline=ink)
    elif any(x in k for x in ("table","bench","counter","stool","shelf","cabinet","rack","altar","cot","bed","medical","tray","ledger")):
        if "shelf" in k or "cabinet" in k:
            d.rectangle((16,16,80,113),fill=(*wood,255),outline=ink,width=3)
            for y in (41,70,95):
                d.line((20,y,76,y),fill=(*tinted(wood,.37),255),width=5)
                for x in (24,43,62):
                    d.rectangle((x,y-16,x+11,y-5),fill=(*tinted(sea,.35),255))
        elif "cot" in k or "bed" in k:
            d.rectangle((10,45,86,108),fill=(*wood,255),outline=ink,width=3)
            d.rectangle((15,49,81,99),fill=(*tinted(sea,.4),255))
            d.rounded_rectangle((20,51,73,73),radius=6,fill=(*PALETTE["paper"],255))
        else:
            d.rectangle((13,53,84,93),fill=(*wood,255),outline=ink,width=3)
            d.rectangle((18,90,26,115),fill=(*tinted(wood,-.34),255))
            d.rectangle((70,90,78,115),fill=(*tinted(wood,-.34),255))
            d.rectangle((10,49,86,61),fill=(*tinted(wood,.25),255))
            if any(x in k for x in ("ledger","medical","tray")):
                d.rectangle((29,35,68,51),fill=(*PALETTE["paper"],255),outline=ink,width=2)
    else:
        # Distinct silhouettes for ropes, barrels, banners, lanterns, crates,
        # signs, chests and all remaining named scenery.
        d.rounded_rectangle((22,40,74,111),radius=9,fill=(*c,255),outline=ink,width=3)
        d.line((25,53,71,53),fill=(*tinted(c,.4),255),width=4)
        d.line((25,92,71,92),fill=(*tinted(c,-.3),255),width=4)
        if any(x in k for x in ("lantern","lamp","light")):
            d.ellipse((27,26,70,80),fill=(*PALETTE["light"],210),outline=ink,width=3)
        if "banner" in k:
            d.polygon([(25,21),(73,24),(71,80),(48,69),(24,83)],fill=(*PALETTE["fabric"],255),outline=ink)
    # Individual stamped signature is visible without requiring a text font.
    digest=hashlib.sha256(slot.encode()).digest()
    for i in range(5):
        if digest[i]&1:
            xx=28+7*i
            d.ellipse((xx,111,xx+3,114),fill=(*tinted(c,.46),235))
    return im

def produce(root):
    root=root.resolve()
    registry_path=root/REG
    registry=read(registry_path)
    slots=registry.get("canonical_slots",{})
    if len(slots)<100:
        raise RuntimeError("Official canonical slots missing; refusing partial generation")
    gap_ids=sorted(k for k,row in slots.items() if not row.get("source"))
    if len(gap_ids)<100:
        raise RuntimeError("Missing slot count unexpectedly smaller; re-audit before generating")
    out=root/REL
    out.mkdir(parents=True,exist_ok=True)
    manifest={}
    for name in gap_ids:
        row=slots[name];cat=str(row.get("category","misc"))
        dim=size_for(name,cat)
        image=object_image(name,cat,dim,root)
        if image.size!=dim or image.getbbox() is None:
            raise RuntimeError("Invalid original generated art for "+name)
        dest=out/(safe(name)+".png")
        tmp=dest.with_suffix(".partial.png")
        image.save(tmp,format="PNG",optimize=True)
        tmp.replace(dest)
        with Image.open(dest) as checked:
            checked.verify()
        uri="res://"+dest.relative_to(root).as_posix()
        manifest[name]={"source":uri,"sha256":sha(dest),"category":cat,
                       "dimensions":list(dim),"provenance":"project_generated_original_v10",
                       "visual_qa":"未测试"}
        row["source"]=uri
        row["stage"]="generated_runtime_candidate_visual_qa_pending"
    # Also fill seven gameplay icon slots with truly generated pictograms.
    ui_paths={}
    for icon in sorted(k for k,v in registry.get("ui",{}).items() if not v):
        name="ui.extra."+icon;dim=(64,64)
        img=object_image(name,"ui_icon",dim,root)
        dest=out/(safe(name)+".png")
        img.save(dest,format="PNG",optimize=True)
        ui_paths[icon]="res://"+dest.relative_to(root).as_posix()
        manifest[name]={"source":ui_paths[icon],"sha256":sha(dest),"category":"ui_icon",
                        "dimensions":[64,64],"provenance":"project_generated_original_v10",
                        "visual_qa":"未测试"}
        registry["ui"][icon]=ui_paths[icon]
    # Link exact canonical monster ID to already regenerated unique V9 image.
    monster_bound=0
    for mon,value in registry.get("monster_id_sources",{}).items():
        if value:continue
        path=root/"assets/art/runtime/global_factory_v3/monsters"/(mon+".png")
        if not path.is_file():
            raise RuntimeError("Missing current generated monster identity: "+mon)
        registry["monster_id_sources"][mon]="res://"+path.relative_to(root).as_posix()
        monster_bound+=1
    for region,profile in registry.get("regions",{}).items():
        for kind,value in profile.get("material_preview",{}).items():
            if value:continue
            p=root/"assets/art/runtime/global_factory_v3/terrain"/(region+"_"+kind+".png")
            if not p.is_file():
                raise RuntimeError("Missing generated terrain preview: "+str(p))
            profile["material_preview"][kind]="res://"+p.relative_to(root).as_posix()
    coast=registry.get("regions",{}).get("region_coast",{}).get("scene_props",{})
    for role,canonical in {"cottage":"prop.coast.cottage","crane":"scene.coast.harbor_crane",
                           "mangrove":"scene.coast.mangrove","tidal_pool":"scene.coast.tide_pool",
                           "sign":"prop.coast.sign","well":"prop.coast.well"}.items():
        if not coast.get(role):
            coast[role]=manifest[canonical]["source"]
    registry["gap_fill_sources"]={key:row["source"] for key,row in manifest.items()}
    registry["gap_fill_manifest"]={"source":"res://"+MAN.as_posix(),
          "slots":len(gap_ids),"extra_ui_icons":len(ui_paths),
          "exact_monster_bindings":monster_bound,
          "status":"generated_and_registered_visual_qa_pending"}
    registry["sources"].update({row["source"]:{
        "sha":row["sha256"],"physically_present":True,"registered":True,
        "code_reference":"canonical_slot_generated_v10",
        "drawn_in_scene":"未测试","visual_correct":"未测试",
        "tier":"generated_runtime","provenance":row["provenance"],
    } for row in manifest.values()})
    result={"schema":"starlit.main2.gap_fill.v10","generated_count":len(manifest),
            "canonical_filled":len(gap_ids),"ui_filled":len(ui_paths),
            "monster_id_bound":monster_bound,"assets":manifest,
            "stage":"generated_candidates_not_human_visual_approval"}
    (root/MAN).write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    registry_path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return result

def verify(root):
    registry=read(root/REG);data=read(root/MAN);assets=data["assets"]
    if data["generated_count"]!=len(assets) or data["canonical_filled"]<100:
        raise ValueError("Gap coverage has silently regressed")
    for name,entry in assets.items():
        target=root/entry["source"].removeprefix("res://")
        if not target.is_file() or sha(target)!=entry["sha256"]:
            raise ValueError("Failed pixel/hash evidence for "+name)
        with Image.open(target) as image:
            image.verify()
        if name.startswith("ui.extra."):
            assert entry["source"] in registry["ui"].values(), name
        else:
            if registry["canonical_slots"][name]["source"]!=entry["source"]:
                raise ValueError("Unbound canonical art: "+name)
        if "/external/" in entry["source"] or "source_packs" in entry["source"]:
            raise ValueError("Third-party source returned: "+name)
    if any(not row.get("source") for row in registry["canonical_slots"].values()):
        raise ValueError("Canonical art gaps remain")
    if any(not value for value in registry["ui"].values()):
        raise ValueError("Gameplay UI gaps remain")
    if any(not value for value in registry["monster_id_sources"].values()):
        raise ValueError("Monster identity gaps remain")
    for reg in registry["regions"].values():
        if any(not v for v in reg["material_preview"].values()):
            raise ValueError("Region terrain preview gap remains")
    return {"status":"成功","new_png":len(assets),
            "canonical_slots":len(registry["canonical_slots"]),
            "gaps_remaining":0,"visual_qa":"未测试"}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--verify-only",action="store_true")
    opt=parser.parse_args()
    root=opt.project.resolve()
    outcome=verify(root) if opt.verify_only else produce(root)
    print(json.dumps({k:v for k,v in outcome.items() if k!="assets"},ensure_ascii=False,indent=2))

if __name__=="__main__":
    main()
