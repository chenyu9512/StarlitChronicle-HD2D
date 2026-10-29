"""Executable stdlib regression tests for D-line verifier (isolated fixture; no game bypass)."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from audit import audit, duplicate_errors


def make_fixture(root):
    def write(path, obj):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")
    chapters = []
    for n in range(1, 73):
        key = f"ch{n:03}"
        prev = "story.prologue_done" if n == 1 else f"story.ch{n-1:03}.done"
        chapters.append({"id": key, "act": (n-1)//6+1,
                         "required_flags": [prev], "chapter_complete_flag": f"story.{key}.done",
                         "scenes": [{"id": f"{key}.opening", "effects": []}]})
    for act in range(1, 13):
        write(f"story/campaign/act_{act:02}.json", {"chapters": chapters[(act-1)*6:act*6]})
    write("story/campaign/prologue.json", {"scenes": [
        {"effects": [{"type": "set_flag", "key": "story.prologue_done"}]}]})
    bosses = [f"boss.ch{n:03}" for n in range(2, 68)]
    write("story/data/bosses.json", {"bosses": [
        {"id": key, "chapter_id": "ch" + key[-3:]} for key in bosses]})
    write("data/gameplay/boss_mechanics.json", {"entries": [
        {"boss_id": key} for key in bosses]})
    keys = [f"map_{n:02}" for n in range(40)]
    write("data/levels/world_levels_v3.json", {"levels": {k: {"size": [16,16]} for k in keys}})
    write("data/content/maps.json", {"entries": [{"id": k} for k in keys]})
    write("story/data/jobs.json", {"jobs": [{"id": f"job_{n:02}"} for n in range(20)]})
    write("data/gameplay/vocation_profiles.json", {"jobs": {f"job_{n:02}": {} for n in range(20)}})
    for file, prefix, count in [("side_quests", "sq", 36), ("regional_quests_v2", "rq", 36),
                                ("companion_quests", "cq", 48)]:
        write(f"story/data/{file}.json", {"quests": [
            {"id": f"{prefix}_{n:03}", "required_chapter": "ch001",
             "stages": [{"id": f"{prefix}_{n:03}.end"}]} for n in range(count)]})
    for path in ("scripts/game_state.gd", "scripts/first_act_state.gd",
                 "scripts/story_runtime.gd"):
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text("extends Node\n", encoding="utf-8")
    return write


class StaticAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write = make_fixture(self.root)

    def test_all_318_rows_remain_unverified(self):
        result = audit(self.root)
        self.assertEqual(result["status"], "STATIC_ONLY_NO_RELEASE_CLAIM", result["errors"])
        self.assertEqual(len(result["matrix"]), 318)
        self.assertTrue(all("unverified" in x["state"] for x in result["matrix"]))

    def test_duplicate_cross_family_quest(self):
        source = "story/data/regional_quests_v2.json"
        data = json.loads((self.root / source).read_text())
        data["quests"][0]["id"] = "sq_000"
        self.write(source, data)
        self.assertIn("duplicate ID", " ".join(audit(self.root)["errors"]))

    def test_chapter_lock_breakage(self):
        source = "story/campaign/act_01.json"
        data = json.loads((self.root / source).read_text())
        data["chapters"][1]["required_flags"] = ["never.earned"]
        self.write(source, data)
        self.assertIn("unresolved chapter prerequisites", " ".join(audit(self.root)["errors"]))

    def test_missing_boss_profile(self):
        source = "data/gameplay/boss_mechanics.json"
        data = json.loads((self.root / source).read_text())
        data["entries"].pop()
        self.write(source, data)
        self.assertIn("ID mismatch", " ".join(audit(self.root)["errors"]))

    def test_corrupt_content(self):
        (self.root / "story/data/bosses.json").write_text("{garbled", encoding="utf-8")
        self.assertEqual(audit(self.root)["status"], "FAIL")

    def test_missing_preload(self):
        (self.root / "scripts/test.gd").write_text('preload("res://missing.gd")', encoding="utf-8")
        self.assertIn("missing.gd", " ".join(audit(self.root)["errors"]))

    def test_live_save_truncation_risk(self):
        (self.root / "scripts/story_runtime.gd").write_text(
            'var f = FileAccess.open(STORY_SAVE_PATH, FileAccess.WRITE)', encoding="utf-8")
        self.assertTrue(audit(self.root)["save_review"]["story_v2"]["direct_live_write"])

    def test_duplicate_util(self):
        self.assertEqual(duplicate_errors([{"id": "a"}, {"id": "a"}], "fixture"),
                         ["fixture: duplicate ID a"])


if __name__ == "__main__":
    unittest.main()
