extends RefCounted
## 可选小戏和选项即时回应。始终用正典ID且不覆盖主线奖励。
var by_chapter: Dictionary = {}
var reactions: Dictionary = {}
var state

func _init() -> void:
    for file in ["phase08_act01_town_scenes","phase08_act01_evidence_scenes","phase09_act02_optional_scenes","phase10_act03_optional_scenes"]:
        for scene in _load(file).get("scenes",[]):
            if scene is Dictionary:
                var chapter_id: String = str(scene.get("chapter_id",""))
                if not by_chapter.has(chapter_id):
                    by_chapter[chapter_id] = []
                (by_chapter[chapter_id] as Array).append(scene)
    for file in ["phase08_act01_choice_reactions","phase09_act02_choice_reactions","phase10_act03_choice_reactions"]:
        for scene in _load(file).get("followups",[]):
            if scene is Dictionary:
                var chapter_id: String = str(scene.get("chapter_id",""))
                if not reactions.has(chapter_id):
                    reactions[chapter_id] = []
                (reactions[chapter_id] as Array).append(scene)

func _load(file: String) -> Dictionary:
    var path: String = "res://story/data/%s.json" % file
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

func bind(progress) -> void:
    state = progress
    if not (state.rpg.get("optional_events") is Dictionary):
        state.rpg["optional_events"] = {}

func _chapter_id(chapter: int) -> String:
    return "ch%03d" % chapter

func _met(flags: Array) -> bool:
    for flag in flags:
        if not bool(state.flags.get(str(flag),false)):
            return false
    return true

func offered(chapter: int, slot: String, scene_index: int) -> Dictionary:
    if state == null:
        return {}
    var expected: int = 1 if slot == "town" else 2
    if scene_index != expected:
        return {}
    for event in by_chapter.get(_chapter_id(chapter),[]):
        var id: String = str(event.get("id",""))
        if not id.ends_with("."+slot):
            continue
        if bool(state.rpg["optional_events"].get(id,false)):
            continue
        if not _met(event.get("required_flags",[])):
            continue
        return event
    return {}

func mark_seen(event: Dictionary) -> bool:
    var id: String = str(event.get("id",""))
    if id.is_empty() or state == null:
        return false
    if bool(state.rpg["optional_events"].get(id,false)):
        return false
    state.rpg["optional_events"][id] = true
    return true

func reaction(chapter: int, choice: Dictionary, flags: Dictionary) -> Dictionary:
    if state == null:
        return {}
    var option: String = str(choice.get("id",""))
    for event in reactions.get(_chapter_id(chapter),[]):
        if str(event.get("choice_option_id","")) != option:
            continue
        var id: String = str(event.get("id",""))
        if bool(state.rpg["optional_events"].get(id,false)):
            continue
        var conditions: Dictionary = event.get("condition",{})
        var matches: bool = true
        for key in conditions:
            if flags.get(str(key)) != conditions[key]:
                matches = false
                break
        if matches:
            return event
    return {}

func count() -> Dictionary:
    var scenes: int = 0
    var followups: int = 0
    for rows in by_chapter.values():
        scenes += (rows as Array).size()
    for rows in reactions.values():
        followups += (rows as Array).size()
    return {"optional_scenes":scenes,"choice_reactions":followups}
