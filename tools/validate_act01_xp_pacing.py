#!/usr/bin/env python3
"""First-act XP economy: synchronize runtime payout sources with player levels."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


act = load("story/campaign/act_01.json")["chapters"]
side = load("data/first_act_side_quests.json")["quests"]
catalog = {row["id"]: row for row in load("data/content/quests.json")["entries"]}
curve = load("data/gameplay/combat_progression.json")["chapters"]
registry = (ROOT / "scripts/encounter_registry.gd").read_text(encoding="utf-8")
assert len(act) == len(side) == 6
assert len(curve) == 72
assert 'chapter <= 6 and progression_target.has("boss_xp")' in registry
assert 'result["xp"] = maxi(0,int(progression_target["boss_xp"]))' in registry

level = 1
bank = 0
observations = []


def earn(amount):
    global level, bank
    assert isinstance(amount, int) and 0 < amount < 1000, amount
    bank += amount
    while bank >= 38 + 17 * level:
        bank -= 38 + 17 * level
        level += 1


for index, chapter in enumerate(act):
    chapter_no = index + 1
    assert side[index]["chapter"] == chapter_no
    grant_scene = next(x for x in chapter["scenes"]
                       if x["id"] == f"ch{chapter_no:03d}.resolve")
    grants = [e for e in grant_scene["effects"] if e.get("type") == "grant"]
    assert len(grants) == 1
    main_xp = grants[0]["xp"]
    side_xp = side[index]["reward"]["xp"]
    boss_xp = curve[index]["boss_xp"]
    assert catalog[f"quest_main_{chapter_no:03d}"]["rewards"]["xp"] == main_xp
    assert side[index]["reward"]["potions"] >= 1
    earn(side_xp)
    if chapter_no > 1:
        recommended = curve[index]["recommended_level"]
        assert abs(level - recommended) <= 2, (
            "off-target Act I starter hero", chapter_no, level, recommended
        )
        observations.append((chapter_no, level, recommended))
        earn(boss_xp)
    earn(main_xp)

assert level <= 10, ("XP curve too inflated at next-act entry", level)
print("PASS first-act XP sources, reward descriptions, planned battle levels:", observations)
