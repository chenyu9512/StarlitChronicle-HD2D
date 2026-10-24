#!/usr/bin/env python3
import json,sys
from pathlib import Path
from xml.etree import ElementTree as ET
root=Path(__file__).resolve().parents[1]
assets=json.loads((root/"assets/art/art_manifest.json").read_text(encoding="utf-8"))["assets"]
assert len({x["path"] for x in assets})==len(assets)
for a in assets:
 p=root/a["path"]
 assert p.is_file(),p
 tag=ET.parse(p).getroot()
 assert [int(tag.attrib["width"]),int(tag.attrib["height"])]==a["size"],p
 if "--check-png" in sys.argv:
  from PIL import Image
  with Image.open(p.with_suffix(".png")) as im:assert list(im.size)==a["size"],p
print("PASS:",len(assets),"assets")
