extends RefCounted
## 只读叙事数据加载器。与原型 Game/State 解耦，避免破坏旧存档。
## Content manifest paths are fixed and safe for offline mobile builds.

const ACT_COUNT: int = 12
const ProductionIndexScript = preload("res://scripts/systems/CampaignProductionIndex.gd")
const STORY_ROOT: String = "res://story/"
var chapters: Dictionary = {}
var act_meta: Array[Dictionary] = []
var prologue: Dictionary = {}
var side_quests: Dictionary = {}
var jobs: Dictionary = {}
var interface_copy: Dictionary = {}
var npc_barks: Dictionary = {}
var endings: Dictionary = {}
var errors: Array[String] = []
var production_index

func load_all() -> bool:
    chapters.clear()
    act_meta.clear()
    errors.clear()
    for act in range(1, ACT_COUNT + 1):
        var name: String = "act_%02d.json" % act
        var act_data: Dictionary = _read_json(STORY_ROOT + "campaign/" + name)
        if act_data.is_empty():
            continue
        act_meta.append({
            "act": int(act_data.get("act", act)),
            "title": str(act_data.get("title", ""))
        })
        var entries: Array = act_data.get("chapters", [])
        for variant_entry in entries:
            if not (variant_entry is Dictionary):
                errors.append(name + " includes a non-dictionary chapter")
                continue
            var entry: Dictionary = variant_entry
            var chapter_id: String = str(entry.get("id", ""))
            if chapter_id.is_empty() or chapters.has(chapter_id):
                errors.append("Invalid or duplicated chapter ID: " + chapter_id)
                continue
            chapters[chapter_id] = entry
    prologue = _read_json(STORY_ROOT + "campaign/prologue.json")
    side_quests = _read_json(STORY_ROOT + "data/side_quests.json")
    jobs = _read_json(STORY_ROOT + "data/jobs.json")
    interface_copy = _read_json(STORY_ROOT + "data/ui_zh_CN.json")
    npc_barks = _read_json(STORY_ROOT + "data/npc_barks.json")
    endings = _read_json(STORY_ROOT + "data/endings.json")
    # Attach canon-accurate immediate consequences; never modify existing IDs,
    # encounters, rewards or world/ending flags.
    var authored_pack: Dictionary = _read_json(STORY_ROOT + "data/choice_response_lock26.json")
    var replies: Dictionary = authored_pack.get("replies", {})
    if replies.size() != 72:
        errors.append("Expected 72 authored chapter choice responses")
    for chapter_id in chapters:
        var chapter: Dictionary = chapters[chapter_id]
        for entry in chapter.get("scenes", []):
            if not (entry is Dictionary):
                continue
            var scene: Dictionary = entry
            var sid: String = str(scene.get("id", ""))
            if not sid.ends_with(".crisis"):
                continue
            var authored: Dictionary = replies.get(sid, {})
            var opts: Array = scene.get("choice", {}).get("options", [])
            if authored.is_empty() or opts.size() != 2:
                errors.append("Missing two crisis choices/replies for " + sid)
                continue
            for i in range(2):
                var route: String = "a" if i == 0 else "b"
                var response: Array = authored.get(route, [])
                if response.size() != 2 or not (opts[i] is Dictionary):
                    errors.append("Invalid authored reply " + sid + "/" + route)
                    continue
                var chosen: Dictionary = opts[i]
                chosen["branch_dialogue"] = response.duplicate(true)
    if chapters.size() != 72:
        errors.append("Expected 72 chapters, got %d" % chapters.size())
    production_index = ProductionIndexScript.new()
    if not production_index.load_all():
        for issue in production_index.errors:
            errors.append("Production contract: " + str(issue))
    return errors.is_empty()

func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        errors.append("Missing story file: " + path)
        return {}
    var text: String = FileAccess.get_file_as_string(path)
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        errors.append("Invalid JSON object: " + path)
        return {}
    return parsed

func production_contract(chapter_id: String, flags: Dictionary = {}) -> Dictionary:
    if production_index == null:
        return {}
    return production_index.chapter_contract(chapter_id, flags)

func production_quest(quest_id: String) -> Dictionary:
    if production_index == null:
        return {}
    return production_index.quest_contract(quest_id)

func production_summary() -> Dictionary:
    if production_index == null:
        return {}
    return production_index.summary()

func get_chapter(chapter_id: String) -> Dictionary:
    var result: Variant = chapters.get(chapter_id, {})
    return result if result is Dictionary else {}

func get_scene(chapter_id: String, scene_id: String) -> Dictionary:
    var chapter: Dictionary = get_chapter(chapter_id)
    var scenes: Array = chapter.get("scenes", [])
    for item in scenes:
        if item is Dictionary:
            var entry: Dictionary = item
            if str(entry.get("id", "")) == scene_id:
                return entry
    return {}

func get_prologue_scene(scene_id: String) -> Dictionary:
    var scenes: Array = prologue.get("scenes", [])
    for item in scenes:
        if item is Dictionary:
            var entry: Dictionary = item
            if str(entry.get("id", "")) == scene_id:
                return entry
    return {}

func requirements_met(required: Array, flags: Dictionary) -> bool:
    for item in required:
        var key: String = str(item)
        if not bool(flags.get(key, false)):
            return false
    return true

func can_enter_chapter(chapter_id: String, flags: Dictionary) -> bool:
    var chapter: Dictionary = get_chapter(chapter_id)
    if chapter.is_empty():
        return false
    var required: Array = chapter.get("required_flags", [])
    return requirements_met(required, flags)

func can_enter_scene(chapter_id: String, scene_id: String, flags: Dictionary) -> bool:
    var scene: Dictionary = get_scene(chapter_id, scene_id)
    if scene.is_empty():
        return false
    var trigger: Dictionary = scene.get("trigger", {})
    var needed: Array = trigger.get("requires_flags", [])
    return requirements_met(needed, flags)

func get_next_chapter_id(current_id: String) -> String:
    var current: Dictionary = get_chapter(current_id)
    if current.is_empty():
        return ""
    var chapter_number: int = int(current.get("number", 0))
    if chapter_number >= 72:
        return ""
    return "ch%03d" % (chapter_number + 1)

func get_quest(quest_id: String) -> Dictionary:
    var quest_list: Array = side_quests.get("quests", [])
    for item in quest_list:
        if item is Dictionary:
            var entry: Dictionary = item
            if str(entry.get("id", "")) == quest_id:
                return entry
    return {}

func can_unlock_ending(ending_id: String, flags: Dictionary) -> bool:
    var list: Array = endings.get("endings", [])
    for item in list:
        if item is Dictionary:
            var entry: Dictionary = item
            if str(entry.get("id", "")) == ending_id:
                var required: Array = entry.get("requirements", [])
                return requirements_met(required, flags)
    return false

func get_dialogue(scene: Dictionary) -> Array:
    return scene.get("dialogue", [])

func get_errors_text() -> String:
    var combined: String = ""
    for error in errors:
        combined += error + "\n"
    return combined.strip_edges()
