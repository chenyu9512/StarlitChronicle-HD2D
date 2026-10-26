"""Fail-closed regression tests for proposed shared script patch (no game changes)."""
import unittest
try:
    from .propose_story_runtime_fix import patch, HELPER
except ImportError:
    from propose_story_runtime_fix import patch, HELPER

FIXTURE = '''extends Node
const STORY_SAVE_PATH: String = "user://starlit_story_v1.json"
func _finish_scene() -> void:
    reward_granted.emit({})

func start_side_quest(quest_id: String) -> bool:
    if not side_quest_progress.has(quest_id):
        side_quest_progress[quest_id] = 0
        save_story()
    return true

func advance_side_quest(quest_id: String, stage_id: String) -> bool:
    side_quest_progress[quest_id] = stage_index + 1
    save_story()
    return true

func complete_side_quest(quest_id: String) -> bool:
    reward_granted.emit({})
    return true

func save_story() -> bool:
    var data: Dictionary = {}
    var file: FileAccess = FileAccess.open(STORY_SAVE_PATH, FileAccess.WRITE)
    if file == null:
        story_error.emit("剧情存档失败：" + str(FileAccess.get_open_error()))
        return false
    file.store_string(JSON.stringify(data, "  "))
    file.close()
    return true

func load_story() -> bool:
    if not loaded or not FileAccess.file_exists(STORY_SAVE_PATH):
        return false
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_SAVE_PATH))
    return true
'''


class StoryPatchTests(unittest.TestCase):
    def test_patch_defers_payout_until_save_and_rolls_back(self):
        changed = patch(FIXTURE)
        self.assertIn(HELPER, changed)
        self.assertIn("AtomicStorySave.write_verified", changed)
        self.assertIn("AtomicStorySave.read_verified", changed)
        self.assertIn("flags = old_flags", changed)
        self.assertIn("side_quest_progress.erase(quest_id)", changed)
        self.assertLess(changed.index("if not save_story():\n        flags = old_flags"),
                        changed.index("reward_granted.emit(reward)"))
        self.assertNotIn('FileAccess.open(STORY_SAVE_PATH, FileAccess.WRITE)', changed)

    def test_double_patch_refused(self):
        with self.assertRaisesRegex(ValueError, "Already patched"):
            patch(patch(FIXTURE))

    def test_changed_source_refused(self):
        with self.assertRaisesRegex(ValueError, "save_story changed"):
            patch(FIXTURE.replace('file.store_string(JSON.stringify(data, "  "))',
                                  'file.store_string(JSON.stringify(data))'))

    def test_missing_scene_refused(self):
        with self.assertRaisesRegex(ValueError, "Function _finish_scene changed"):
            patch(FIXTURE.replace("func _finish_scene() -> void:", "func renamed() -> void:"))


if __name__ == "__main__":
    unittest.main()
