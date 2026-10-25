#!/usr/bin/env python3
"""Create visible, repeatable four-frame idle breathing/bobbing sheets from B01 masters.

B01 enemy idle exports initially repeated an identical PNG four times. This migration
preserves every monster's first frame, palette, identity and atlas geometry, while
adding three deliberately subtle silhouette poses. It can be rerun safely.
"""
from __future__ import annotations

import base64
import json
from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/art"
FRAME = 128
FRAME_COUNT = 4


def move(original: Image.Image, dx: int, dy: int) -> Image.Image:
    result = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    result.paste(original, (dx, dy))
    return result


def breathe(original: Image.Image, wide: int, tall: int, offset_y: int) -> Image.Image:
    result = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    frame = original.resize((wide, tall), Image.Resampling.NEAREST)
    result.paste(frame, ((FRAME - wide) // 2, offset_y))
    return result


def frames_from_source(original: Image.Image) -> list[Image.Image]:
    return [
        original.copy(),
        move(original, 0, -2),
        breathe(original, 126, 123, 3),
        move(original, 1, 1),
    ]


def verify(sheet: Image.Image) -> None:
    assert sheet.size == (512, 128)
    frames = [sheet.crop((n * FRAME, 0, (n + 1) * FRAME, FRAME)) for n in range(FRAME_COUNT)]
    for frame in frames:
        assert frame.getchannel("A").getbbox() is not None, "empty animation frame"
    for n in range(1, FRAME_COUNT):
        # RGBA ImageChops.getbbox can overlook RGB-only variations when alpha diff=0.
        rgb_changed = ImageChops.difference(frames[n - 1].convert("RGB"), frames[n].convert("RGB")).getbbox()
        alpha_changed = ImageChops.difference(frames[n - 1].getchannel("A"), frames[n].getchannel("A")).getbbox()
        assert rgb_changed or alpha_changed, f"duplicate frames {n-1} and {n}"


def run() -> None:
    records = json.loads((ART / "art_manifest.json").read_text(encoding="utf-8"))["assets"]
    updated = []
    for record in records:
        if record.get("kind") != "idle_4frames" or record.get("refinement_version") != "coast-v2":
            continue
        svg = ROOT / record["path"]
        png = svg.with_suffix(".png")
        with Image.open(png) as input_image:
            original = input_image.convert("RGBA")
        assert original.size == (512, 128), str(png)
        first = original.crop((0, 0, FRAME, FRAME))
        assert first.getchannel("A").getbbox(), str(png)
        frames = frames_from_source(first)
        strip = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            strip.paste(frame, (index * FRAME, 0))
        verify(strip)
        strip.save(png, format="PNG", optimize=True)
        encoded = base64.b64encode(png.read_bytes()).decode("ascii")
        title = escape("星灯纪行 · B01 四帧呼吸动画 · " + png.parent.name)
        svg.write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="128" viewBox="0 0 512 128">'
            f'<title>{title}</title><image x="0" y="0" width="512" height="128" '
            f'preserveAspectRatio="none" image-rendering="pixelated" '
            f'href="data:image/png;base64,{encoded}"/></svg>\n',
            encoding="utf-8",
        )
        updated.append(png.relative_to(ROOT).as_posix())
    assert len(updated) == 9, f"Expected nine coastal enemy idles, found {len(updated)}"
    print("PASS: 9 coastal monsters × 4 non-identical RGBA idle frames; unchanged first frames")
    for item in updated:
        print("  " + item)


if __name__ == "__main__":
    run()
