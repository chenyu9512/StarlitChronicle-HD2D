#!/usr/bin/env python3
"""Model-assisted high-detail asset production for Global Art Factory V3.

Only --render makes image-generation API calls; --jobs-only exports prompts
with zero API usage. Uses the same canonical IDs as global_art_factory_v3.py.
Generated art enters the exact-size candidate import folder, never runtime.
"""
from __future__ import annotations
import argparse
import base64
import io
import json
import os
import sys
from pathlib import Path

from PIL import Image
from global_art_factory_v3 import SCOPES, SIZES, read, safe, tasks

MODEL = "gpt-image-2.5-flare"
STYLE = ("Original premium hand-painted high definition 2D Japanese fantasy RPG art. "
         "Consistent elegant design language across all regions, warm luminous highlights, "
         "readable silhouettes, clean textures, coherent orthographic viewpoint, "
         "no 3D renders, no stock clipart, no letters, no watermark.")

DESIGN = {
    "terrain": "Create a clean 8-column 8-row tile sheet: row 1 terrain, row 2 roads, "
               "row 3 stones, row 4 planks, row 5 cobbles, row 6 sand, row 7 water, "
               "row 8 walls. Exactly uniform cells, seamless edges, NO combined landscape.",
    "maps": "Detailed scenic location illustration for a layered parallax background; "
            "this image MUST NOT be mistaken for collision geometry or a playable level.",
    "interiors": "Straight top-down environment material atlas for a living, functional JRPG interior. "
                 "Eight by eight uniform tile cells, no people, game-ready 2D textures.",
    "props": "One clean isolated orthographic game prop with consistent anchor at bottom center, "
             "strong functional silhouette, transparent background.",
    "characters": "Twelve-frame walking animation sprite sheet, four direction rows "
                  "(front, left, back, right), three frames per row. Identical recognizable "
                  "character design in every cell, transparent background, exact alignment.",
    "npcs": "Twelve-frame four-direction NPC walk sheet, three frames per direction, "
            "same costume and identity, transparent background, no frame drift.",
    "monsters": "Four equal horizontal frames of the same original creature's idle loop. "
                "Clear anatomy, readable silhouette, consistent identity, transparent background.",
    "bosses": "Four equal horizontal frames of the SAME named story boss with epic original "
              "visual identity and phase details. Each frame aligned on the same baseline, "
              "transparent background. No recycled generic enemy.",
    "ui": "One elegant original dark ornamental JRPG interface border, gold/brass edging "
          "with regional accent colors, clean empty interior, no textual labels.",
}

def name_index(root: Path) -> dict:
    av = read(root / "data/assets/av_registry.json")
    maps = read(root / "data/content/maps.json")
    idx = {}
    for group, key in (("characters","characters"),("npcs","npcs"),
                       ("monsters","monsters"),("bosses","bosses")):
        for item in av.get(key, []):
            idx[(group,str(item["id"]))] = str(item.get("name",item["id"]))
    for item in maps.get("entries", []):
        idx[("maps",str(item["id"]))] = str(item.get("name",item["id"]))
    for item in av.get("regions", []):
        idx[("terrain",str(item["id"]))] = str(item.get("name",item["id"]))
    return idx

def build_jobs(root: Path, selected: set[str], limit: int = 0) -> list[dict]:
    av = read(root / "data/assets/av_registry.json")
    regions = {r["id"]:r for r in av.get("regions",[])}
    names = name_index(root)
    queue = tasks(root, selected)
    if limit:
        queue=queue[:limit]
    output=[]
    for group, asset_id, meta, _ in queue:
        region = regions.get(meta.get("region_id", ""), {})
        style = region.get("style", {})
        label = names.get((group,asset_id),asset_id)
        target = SIZES[group]
        source_detail = str(meta.get("building_id","") or meta.get("kind",""))
        prompt = (STYLE + "\nART ASSET: " + label + " (" + asset_id + ").\n"
                  "REGIONAL STYLE: " + str(region.get("name",meta.get("region_id",""))) + ". "
                  "Motif: " + str(style.get("motif","")) + ". "
                  "Color palette: " + ", ".join(style.get("palette",[])) + ".\n"
                  "CATEGORY REQUIREMENTS: " + DESIGN[group] + "\n"
                  "ADDITIONAL CONTEXT: " + source_detail + ".\n"
                  "FINAL TARGET RASTER: " + str(target[0]) + " x " + str(target[1]) +
                  " pixels. Keep all distinct content inside safe margins. "
                  "Deliver original high-quality art without text.")
        output.append({"group":group,"id":asset_id,"name":label,
                       "target_size":list(target),
                       "prompt":prompt,"metadata":meta,
                       "qa":"candidate_identity_and_animation_review_required"})
    return output

def fit(image_bytes: bytes, desired: tuple[int,int], transparency: bool) -> Image.Image:
    with Image.open(io.BytesIO(image_bytes)) as source:
        source.load()
        im=source.convert("RGBA")
    # Preserve aspect ratio; never squeeze art or invent missing animation frames.
    im.thumbnail(desired,Image.Resampling.LANCZOS)
    bg=Image.new("RGBA",desired,(0,0,0,0) if transparency else (22,27,43,255))
    bg.alpha_composite(im,((desired[0]-im.width)//2,(desired[1]-im.height)//2))
    return bg

def execute(root: Path, out: Path, selected: set[str], limit=0,
            render=False, model=MODEL, force=False):
    jobs=build_jobs(root,selected,limit)
    out.mkdir(parents=True,exist_ok=True)
    (out/"render_jobs.jsonl").write_text(
        "".join(json.dumps(job,ensure_ascii=False)+"\n" for job in jobs),encoding="utf-8")
    report={"schema":"starlit.global_art_ai_candidates.v3","model":model,"jobs":len(jobs),
            "render_requested":render,"complete":0,"cached":0,"failures":[],
            "output":"exact_size_source_candidates_not_game_runtime",
            "assets":[]}
    if not render:
        (out/"render_report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2))
        return report
    if not os.environ.get("OPENAI_API_KEY"):
        raise ValueError("OPENAI_API_KEY is required for --render. --jobs-only needs no key.")
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise ValueError("Install image renderer: python -m pip install openai") from exc
    client=OpenAI()
    for job in jobs:
        dest=out/job["group"]/(safe(job["id"])+".png")
        try:
            dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.is_file() and not force:
                report["cached"]+=1
                continue
            is_transparent = job["group"] in ("props","characters","npcs","monsters","bosses")
            response=client.images.generate(
                model=model,prompt=job["prompt"],n=1,
                size="1536x1024" if job["group"]=="maps" else "1024x1024",
                background="transparent" if is_transparent else "opaque",
                output_format="png")
            if not response.data or not response.data[0].b64_json:
                raise RuntimeError("Image generation API returned no image bytes")
            blob=base64.b64decode(response.data[0].b64_json)
            result=fit(blob,tuple(job["target_size"]),is_transparent)
            temp=dest.with_suffix(".partial.png")
            result.save(temp,format="PNG",optimize=True)
            with Image.open(temp) as check:
                check.verify()
            temp.replace(dest)
            report["complete"]+=1
            report["assets"].append({"id":job["id"],"group":job["group"],
                                     "path":dest.relative_to(out).as_posix(),
                                     "status":"model_generated_candidate_not_game_ready"})
        except Exception as exc:
            report["failures"].append({"id":job["id"],"group":job["group"],
                                       "error":str(exc)[:500]})
    (out/"render_report.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return report

def main(argv=None):
    p=argparse.ArgumentParser(description="Export all visual briefs or generate high-detail AI art candidates")
    p.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument("--output",type=Path)
    p.add_argument("--scope",choices=("all",)+SCOPES,default="all")
    p.add_argument("--limit",type=int,default=0)
    p.add_argument("--model",default=MODEL)
    p.add_argument("--jobs-only",action="store_true",help="Only write canonical art brief JSONL, no API calls")
    p.add_argument("--render",action="store_true",help="Generate PNGs using configured model/API credentials")
    p.add_argument("--force",action="store_true")
    a=p.parse_args(argv)
    if not a.jobs_only and not a.render:
        p.error("Specify --jobs-only or --render to avoid accidental paid calls")
    root=a.project.resolve()
    out=(a.output or root/"build/starlit_global_art_factory_v3/model_sources").resolve()
    if out in (root,root/"assets/art",root/"assets/art/runtime"):
        p.error("Refusing to write image candidates to the live runtime")
    try:
        report=execute(root,out,set(SCOPES) if a.scope=="all" else {a.scope},
                       max(0,a.limit),a.render,a.model,a.force)
    except (ValueError,OSError,KeyError,TypeError) as exc:
        print("MODEL ART ERROR:",exc,file=sys.stderr)
        return 2
    print(json.dumps({k:report[k] for k in ("jobs","render_requested","complete","cached")},
                     ensure_ascii=False))
    return 0 if not report["failures"] else 1

if __name__=="__main__":
    raise SystemExit(main())
