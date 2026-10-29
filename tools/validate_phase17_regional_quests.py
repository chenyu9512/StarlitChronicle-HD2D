#!/usr/bin/env python3
"""Phase 17 batch 3: authored regional A/B contracts only; runtime not asserted."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1] / "story"
def load(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))

errors = []
def check(condition, message):
    if not condition:
        errors.append(message)

source = load("data/regional_quests_v2.json")
base = load("data/side_quests.json")
companions = load("data/companion_quests.json")
manifest = load("data/phase17_regional_manifest.json")
packs = [load(name.removeprefix("story/")) for name in manifest["source_files"]]
authored = [quest for pack in packs for quest in pack["quests"]]
original = source["quests"]
check(len(original) == 36 and len(base["quests"]) == 36 and len(companions["quests"]) == 48,
      "36 regional + 36 original + 48 companion quests")
check(len({q["id"] for q in original + base["quests"] + companions["quests"]}) == 120,
      "120 unique original quest IDs")
check([q["id"] for q in authored] == [q["id"] for q in original] ==
      [f"rq_{i:03}" for i in range(1, 37)], "complete ordered 36 regional quests")
check(len(packs) == 6 and all(p["status"] == "authored_branch_arcs_not_runtime_bound"
      and len(p["quests"]) == 6 for p in packs), "six authored packs")
check(manifest["status"] == "authored_only_216_optional_stages_not_runtime_registered",
      "runtime not implemented")
check(manifest["counts"] == {"quests": 36, "branches": 72,
                            "optional_scenes": 216, "new_dialogues": 648},
      "authored coverage totals")
check(len(manifest["entries"]) == 36, "manifest must list all regions")
check(manifest["source_files"] ==
      [f"story/data/phase17_regional_{start:02}_{start + 5:02}.json"
       for start in range(1, 37, 6)], "manifest source paths")
contracts = {q["id"]: q for q in manifest["entries"]}
kinds = ("followup", "community", "revisit")
ids = set()
line_count = scene_count = 0
reading = (ROOT / "screenplay/phase17_regional_all_branches.md").read_text(encoding="utf-8")
for old, q in zip(original, authored):
    qid = old["id"]
    check((q["title"], q["region"]) == (old["title"], old["region"]),
          "original story title/region drift " + qid)
    entry = contracts[qid]
    check(entry["source_file"] == manifest["source_files"][(int(qid[-3:]) - 1) // 6],
          "wrong pack link " + qid)
    check(entry["original_four_stages"] == [s["id"] for s in old["stages"]] and
          len(old["stages"]) == 4, "must preserve original stage IDs " + qid)
    check(entry["original_completion_flag"] == old["completion_flag"] and
          entry["original_rewards"] == "UNCHANGED", "original settlement drift " + qid)
    check(entry["late_revisit_chapter"] == q["late_chapter"] and
          entry["other_region"] == q["other_region"], "revisit reference drift " + qid)
    start, late = int(old["required_chapter"][-3:]), int(q["late_chapter"][-3:])
    check(start < late <= 72, "late revisit outside timeline " + qid)
    option_stage = next(s for s in old["stages"] if "choice" in s)
    opts = {opt["id"]: opt for opt in option_stage["choice"]["options"]}
    for b in ("a", "b"):
        opt, scenes, contract = opts[b], q["arms"][b], entry["branches"][b]
        check(contract["original_choice_label"] == opt["label"] and
              contract["original_choice_flags"] == opt["sets"] and
              opt["sets"] == {f"side.{qid}.approach": b},
              "source A/B option changed " + qid + b)
        check(len(scenes) == len(contract["stages"]) == 3,
              "must have three distinct scenes per branch " + qid + b)
        for i, (scene, stage) in enumerate(zip(scenes, contract["stages"])):
            kind = kinds[i]
            prefix = f"{qid}.p17.{b}.{kind}"
            check(scene["kind"] == kind and stage["id"] == prefix and
                  scene["title"] == stage["title"], "scene identity " + prefix)
            flags = {old["completion_flag"]: True, f"side.{qid}.approach": b}
            if kind == "revisit":
                flags[f"story.{q['late_chapter']}.done"] = True
            check(stage["required_flags"] == flags, "wrong trigger " + prefix)
            previous = None if i == 0 else f"{qid}.p17.{b}.{kinds[i-1]}"
            check(stage["previous_optional_stage"] == previous,
                  "scene order " + prefix)
            check(stage["after_original_stage"] == f"{qid}.resolution" and
                  stage["proposed_seen_flag"] == f"side.{qid}.p17.{b}.{kind}.seen",
                  "stage and proposed seen state " + prefix)
            check(stage["once_only"] is True and stage["can_delay"] is True and
                  stage["required_for_original_quest"] is False and
                  stage["repeat_original_reward"] is False and
                  stage["runtime_registered"] is False,
                  "must not change save/reward/runtime " + prefix)
            check(bool(stage["player_action"]), "missing concrete player action " + prefix)
            check(len(scene["dialogue"]) == 3 and
                  stage["source_dialogue_ids"] == [line["id"] for line in scene["dialogue"]],
                  "3 dialogue references " + prefix)
            scene_count += 1
            for j, line in enumerate(scene["dialogue"], 1):
                lid = f"{prefix}.l0{j}"
                check(line["id"] == lid and lid not in ids and
                      bool(line.get("speaker", "").strip()) and
                      bool(line.get("text", "").strip()), "bad dialogue " + lid)
                ids.add(lid)
                check(line["text"] in reading, "reading script missing " + lid)
                line_count += 1
        check(contract["long_term_revisit"] ==
              {"speaker": scenes[2]["dialogue"][0]["speaker"],
               "text": scenes[2]["dialogue"][0]["text"]},
              "long-term difference reference " + qid + b)
    check(q["arms"]["a"][2]["dialogue"] != q["arms"]["b"][2]["dialogue"],
          "A/B must not share ending " + qid)
check((scene_count, line_count, len(ids)) == (216, 648, 648),
      "complete event/line counts")
check(manifest["gate_contract"]["ending_c"].startswith("no new hidden flags"),
      "no hidden ending C condition")
endings = load("data/endings.json")
ending_c = next(e for e in endings["endings"] if e["id"] == "C")
check({"story.ch072.done", "ch071.battle_won", "world.all_twelve_pages",
       "world.distributed_network", "world.seven_lanterns"} <= set(ending_c["requirements"]),
      "ending C prerequisites must remain unchanged")
check(next(q for q in authored if q["id"] == "rq_020")["late_chapter"] == "ch054",
      "Noyi must not be adult in chapter 39")
check(next(q for q in authored if q["id"] == "rq_036")["late_chapter"] == "ch072",
      "final dissent remains distinct from ending A/B/C")

print(f"Phase17Regional quests=36 branches=72 scenes={scene_count} lines={line_count} errors={len(errors)}")
if errors:
    print("FAIL:", *errors, sep="\n - ")
    raise SystemExit(1)
print("PASS: static source, A/B, save, timing and ending checks; NOT Godot runtime.")
