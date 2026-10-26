#!/usr/bin/env python3
"""Offline deterministic data/economy envelope checks for A-line, no Godot claims."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

curve = load("data/gameplay/combat_progression.json")["chapters"]
bosses = load("data/gameplay/boss_mechanics.json")["entries"]
profiles = load("data/gameplay/vocation_profiles.json")["jobs"]
skills = load("data/content/skills.json")["entries"]
assert len(curve) == 72 and [c["chapter"] for c in curve] == list(range(1, 73))
assert len(bosses) == 66 and len({b["boss_id"] for b in bosses}) == 66
assert len(profiles) == 20 and len({p["passive"] for p in profiles.values()}) == 20
assert len(skills) == 63
assert all(s["target"] not in ("single_enemy", "all_enemies") for s in skills if s["effect"]["kind"] == "heal")
seen = set()
for category in ("items","armor","weapons"):
    for item in load(f"data/content/{category}.json")["entries"]:
        price = int(item.get("buy_price", item.get("price",0)))
        resale = int(item.get("sell_price", price // 2))
        assert price <= 0 or resale <= price, (category,item["id"],"buy/sell arbitrage")
        assert item["id"] not in seen, ("duplicate item",item["id"])
        seen.add(item["id"])
for row in load("data/content/monsters.json")["entries"]:
    for drop in row.get("loot",[]):
        assert 0 <= float(drop["chance"]) <= 1, ("invalid drop rate",row["id"])
previous = None
samples = []
for row in curve:
    chapter = row["chapter"]
    if previous:
        for key in ("recommended_level","player_hp","player_mp","player_attack","boss_hp",
                    "boss_attack","boss_xp","boss_gold","equipment_price"):
            assert row[key] >= previous[key], (chapter,key,"nonmonotonic")
    for key in ("monster_hp","monster_attack","normal_xp","normal_gold","boss_hp",
                "boss_attack","boss_defense","boss_xp","boss_gold","equipment_price"):
        assert 0 < row[key] < 2000000, (chapter,key,"unsafe value")
    assert 0 <= row["rare_drop_chance"] <= 1
    for difficulty,scale in (("休闲",0.72),("标准",1.0),("挑战",1.38)):
        # Deterministic envelope only; actual skill, speed and target AI require Godot.
        party = 2 if chapter <= 6 else 3
        per_actor = max(3,row["player_attack"]+8-row["boss_defense"])
        estimated_turns = math.ceil(row["boss_hp"]/max(1,party*per_actor))
        incoming = max(1,round((row["boss_attack"]-row["player_defense"])*scale))
        effective_hp = row["player_hp"]*party
        survival_rounds = math.ceil(effective_hp/max(1,incoming))
        assert 1 <= estimated_turns <= 20, (chapter,difficulty,"time-to-defeat envelope",estimated_turns)
        assert 4 <= survival_rounds <= 25, (chapter,difficulty,"unsafe/unthreatening envelope",survival_rounds)
        samples.append((chapter,difficulty,estimated_turns,survival_rounds))
    previous = row
print(f"DATA PASS: chapters={len(curve)}, Bosses={len(bosses)}, vocations={len(profiles)}, "
      f"skill_ids={len(skills)}, economy catalogs checked; envelopes={len(samples)}.")
print("GODOT PENDING: true battle outcomes, status targeting, scripted nonlethal victories and damage balance.")
