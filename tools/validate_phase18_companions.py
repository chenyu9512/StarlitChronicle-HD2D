#!/usr/bin/env python3
"""Phase18 48-quest authored companion arcs + 48 epilogue codas: static-only contract."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1] / "story"
def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))
errors = []
def ck(assertion, message):
    if not assertion:
        errors.append(message)

src = load("data/companion_quests.json")
regional = load("data/regional_quests_v2.json")
original = load("data/side_quests.json")
manifest = load("data/phase18_companion_manifest.json")
packs = [load(f.removeprefix("story/")) for f in manifest["source_files"]]
arcs = [q for pack in packs for q in pack["quests"]]
src_quests = src["quests"]
entries = manifest["entries"]
coda_file = load("data/phase18_companion_ending_codas.json")
codas = coda_file["codas"]
endings = load("data/endings.json")["endings"]
reading = (ROOT / "screenplay/phase18_companion_all_branches.md").read_text(encoding="utf-8")
coda_reading = (ROOT / "screenplay/phase18_companion_endings.md").read_text(encoding="utf-8")
kinds = ("followup", "community", "revisit")
ck(len(src_quests) == 48 and len(regional["quests"]) == 36 and len(original["quests"]) == 36,
   "original total 36+36+48")
ck(len({q["id"] for q in src_quests + original["quests"] + regional["quests"]}) == 120,
   "original IDs remain unique")
ck(len(packs) == 8 and all(len(p["quests"]) == 6 and
   p["status"] == "authored_branch_arcs_not_runtime_bound" for p in packs),
   "8 character packs each 6")
ck(len(arcs) == len(src_quests) == len(entries) == 48, "48 quest coverage")
ck(manifest["status"] == "authored_only_not_runtime_bound" and
   manifest["counts"] == {"companions": 8, "quests": 48, "branches": 96,
                          "optional_scenes": 288, "new_dialogues": 864},
   "manifest coverage and runtime boundary")
ck(manifest["source_files"] ==
   [f"story/data/phase18_{lead}_01_06.json" for lead in
   ("lanyin", "leiso", "shouxian", "tifa", "ize", "xuanli", "nuoyi", "weisha")],
   "8 canonical pack names")
ck([q["id"] for q in arcs] == [q["id"] for q in src_quests] ==
   [q["id"] for q in entries], "original ordering and IDs")
story_ids = set()
events = lines = 0
for q, arc, entry in zip(src_quests, arcs, entries):
    qid = q["id"]
    ck(arc["title"] == q["title"] and arc["lead"] == q["lead"] and
       arc["lead_id"] == q["lead_id"] and arc["region"] == q["region"],
       "lead/title/region drift " + qid)
    ck(entry["original_four_stages"] == [s["id"] for s in q["stages"]] and
       len(q["stages"]) == 4 and q["stages"][-1]["id"] == qid + ".resolution",
       "original 4-stage chain " + qid)
    ck(entry["original_completion_flag"] == q["completion_flag"] and
       entry["original_story_reward_flag"] == q.get("story_reward_flag"),
       "original completion and bond preservation " + qid)
    ck(entry["source_file"] == f"story/data/phase18_{q['lead_id']}_01_06.json",
       "source file origin " + qid)
    first, late = int(q["required_chapter"][-3:]), int(arc["late_chapter"][-3:])
    ck(1 <= first < late <= 72 and entry["late_revisit_chapter"] == arc["late_chapter"],
       "late-story chronology " + qid)
    opts = {o["id"]: o for o in next(s for s in q["stages"] if s.get("choice"))["choice"]["options"]}
    for branch in ("a", "b"):
        choice = opts[branch]
        contract = entry["branches"][branch]
        ck(contract["original_choice_flags"] == choice["sets"] ==
           {f"side.{qid}.approach": branch} and
           contract["original_choice_label"] == choice["label"],
           "preserve original A/B choice " + qid + branch)
        scripted = arc["arms"][branch]
        plans = contract["stages"]
        ck(len(scripted) == len(plans) == 3, "three scenes " + qid + branch)
        for j, (scene, plan) in enumerate(zip(scripted, plans)):
            kind = kinds[j]
            scene_id = f"{qid}.p18.{branch}.{kind}"
            ck(scene["kind"] == kind and plan["id"] == scene_id and
               scene["title"] == plan["title"], "scene identity " + scene_id)
            expected = {q["completion_flag"]: True, f"side.{qid}.approach": branch}
            if j == 2:
                expected[f"story.{arc['late_chapter']}.done"] = True
            ck(plan["required_flags"] == expected, "scene gate " + scene_id)
            ck(plan["required_present_flags"] ==
               (["world.ending"] if j == 2 and late == 72 else []),
               "final ending selection ordering " + scene_id)
            prev = None if j == 0 else f"{qid}.p18.{branch}.{kinds[j-1]}"
            ck(plan["previous_optional_stage"] == prev and
               plan["after_original_stage"] == qid + ".resolution",
               "chain anchoring " + scene_id)
            ck(plan["proposed_seen_flag"] == f"side.{qid}.p18.{branch}.{kind}.seen" and
               plan["once_only"] is True and plan["can_delay"] is True and
               plan["companion_presence_required"] is True and
               plan["required_for_original_quest"] is False and
               plan["repeat_original_reward"] is False and
               plan["repeat_bond_reward"] is False and
               plan["runtime_registered"] is False,
               "save, bond and runtime guard " + scene_id)
            ck(bool(plan["player_action"]), "missing player action " + scene_id)
            ck(len(scene["dialogue"]) == 3 and
               plan["source_dialogue_ids"] == [d["id"] for d in scene["dialogue"]],
               "dialogue references " + scene_id)
            events += 1
            for n, line in enumerate(scene["dialogue"], 1):
                expected_id = f"{scene_id}.l0{n}"
                ck(line["id"] == expected_id and line["id"] not in story_ids and
                   bool(line.get("speaker")) and bool(line.get("text")),
                   "original dialogue ID + content " + expected_id)
                ck(line["text"] in reading, "missing from full reading " + expected_id)
                story_ids.add(line["id"])
                lines += 1
        ck(scripted[0]["dialogue"] != arc["arms"]["b" if branch == "a" else "a"][0]["dialogue"],
           "branches must differ " + qid + branch)
ck((events, lines, len(story_ids)) == (288, 864, 864), "288 scenes, 864 distinct lines")
ck(coda_file["status"] == "text_only_not_runtime_bound" and
   coda_file["counts"] == {"companions": 8, "endings": 3,
                          "branch_variations": 2, "codas": 48, "new_dialogues": 144},
   "coda count and runtime status")
ck(len(codas) == 48 and len({q["id"] for q in codas}) == 48,
   "48 unique companion codas")
coda_lines = 0
for coda in codas:
    lead, outcome, branch = coda["lead_id"], coda["ending"], coda["branch"]
    qid = f"cq_{lead}_06"
    ck(coda["source_quest"] == qid and outcome in ("A", "B", "C") and branch in ("a", "b"),
       "coda source and route " + coda["id"])
    ck(coda["after_ending_scene"] == f"ending_{outcome.lower()}_04" and
       coda["requires_flags"] ==
       {f"side.{qid}.done": True, f"side.{qid}.approach": branch, "world.ending": outcome},
       "after-ending route gate " + coda["id"])
    ck(coda["optional"] is True and coda["runtime_registered"] is False and
       coda["repeat_reward"] is False and len(coda["dialogue"]) == 3,
       "coda authored-only " + coda["id"])
    for j, line in enumerate(coda["dialogue"], 1):
        lid = f"{coda['id']}.l0{j}"
        ck(line["id"] == lid and line["id"] not in story_ids and
           bool(line["text"]) and bool(line["speaker"]) and
           line["text"] in coda_reading, "coda dialogue " + lid)
        story_ids.add(lid)
        coda_lines += 1
ck(coda_lines == 144 and len(story_ids) == 1008, "1008 total new unique lines")
c = next(e for e in endings if e["id"] == "C")
ck(set(c["requirements"]) ==
   {"story.ch072.done", "ch071.battle_won", "world.all_twelve_pages",
    "world.distributed_network", "world.seven_lanterns"},
   "no new ending C requirement")
ck("Nuoyi is a non-romantic next-generation adoptee" in manifest["gate_contract"]["romance"],
   "child/guardian vs romance protection")
for stage in ("data/stage07_companion_deepening_01.json",
              "data/stage07_companion_deepening_02.json"):
    deep = load(stage)
    ck(len(deep["quests"]) == 8, "preserve original deepening " + stage)
    for q in deep["quests"]:
        ck(len(q["scenes"]) == 2, "two pre-existing optional scenes " + q["quest_id"])

print(f"Phase18 companions=8 quests=48 routes=96 scenes={events} "
      f"lines={lines} codas={len(codas)} coda_lines={coda_lines} errors={len(errors)}")
if errors:
    print("FAIL:", *errors, sep="\n - ")
    raise SystemExit(1)
print("PASS: static source, A/B, relationship, timeline, save, coda and endings; NOT Godot runtime.")
