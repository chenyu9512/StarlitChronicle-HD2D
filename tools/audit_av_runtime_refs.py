#!/usr/bin/env python3
"""Audit literal runtime media paths in scripts/scenes; dynamic prefixes are not missing files."""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
URI = re.compile(r"res://assets/[A-Za-z0-9_./-]+")
MEDIA = {".png", ".webp", ".svg", ".ogg", ".wav", ".mp3", ".json", ".tres", ".tscn", ".ttf", ".otf"}

def run() -> dict:
    exact: dict[str, list[str]] = {}
    dynamic: dict[str, list[str]] = {}
    for folder, suffix in (("scripts", ".gd"), ("scenes", ".tscn")):
        for path in sorted((ROOT / folder).rglob("*" + suffix)):
            source = path.read_text(encoding="utf-8")
            origin = path.relative_to(ROOT).as_posix()
            for uri in set(URI.findall(source)):
                target = uri.removeprefix("res://")
                output = exact if Path(target).suffix.lower() in MEDIA else dynamic
                output.setdefault(uri, []).append(origin)
    missing = [{"path": uri, "references": sources} for uri, sources in sorted(exact.items())
               if not (ROOT / uri.removeprefix("res://")).is_file()]
    return {"schema":"starlit.av.runtime-refs.v1",
            "scope":"script and scene literal res://assets/ references (not computed paths)",
            "checked_literal_unique":len(exact),
            "unresolved_literal":missing,
            "dynamic_prefix_unique":len(dynamic),
            "dynamic_prefixes":[{"prefix":uri,"references":v} for uri,v in sorted(dynamic.items())],
            "pass_is_not_runtime_qa":True}
if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--json", action="store_true")
    args = p.parse_args()
    result = run()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("Literal references:", result["checked_literal_unique"])
        for entry in result["unresolved_literal"]:
            print("MISSING", entry["path"], entry["references"])
        print("Dynamic URI prefixes requiring runtime checks:", result["dynamic_prefix_unique"])
        print("STATIC REFERENCE AUDIT:", "FAIL" if result["unresolved_literal"] else "PASS", "/ live binding: NOT TESTED")
    raise SystemExit(1 if result["unresolved_literal"] else 0)
