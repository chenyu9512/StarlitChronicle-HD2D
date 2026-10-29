extends RefCounted
## 72章场景调查与NPC状态，按编剧分支stage07 ID绑定而不复制台词。
const ChoiceEchoes = preload("res://scripts/story_choice_echoes.gd")
var choice_echoes = ChoiceEchoes.new()
var objects_by_chapter: Dictionary = {}
var npc_by_chapter: Dictionary = {}
var midpoint_by_chapter: Dictionary = {}

func _init() -> void:
    for suffix in ["1_24","25_48","49_72"]:
        for chapter in _read("res://story/data/stage07_chapter_objects_%s.json" % suffix).get("chapters", []):
            objects_by_chapter[str(chapter.get("chapter_id", ""))] = chapter
        for chapter in _read("res://story/data/stage07_chapter_npc_states_%s.json" % suffix).get("chapters", []):
            npc_by_chapter[str(chapter.get("id", ""))] = chapter
    for suffix in ["01_24","25_48","49_72"]:
        for scene in _read("res://story/data/stage07_midpoint_%s.json" % suffix).get("scenes", []):
            midpoint_by_chapter[str(scene.get("chapter", ""))] = scene

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return decoded if decoded is Dictionary else {}

func _key(chapter: int) -> String:
    return "ch%03d" % chapter

func objects(chapter: int) -> Array:
    return (objects_by_chapter.get(_key(chapter), {}) as Dictionary).get("objects", [])

func inspection(chapter: int, index: int, flags: Dictionary) -> Dictionary:
    var entries: Array = objects(chapter)
    if index < 0 or index >= entries.size():
        return {}
    var item: Dictionary = entries[index]
    var flag: String = str(item.get("investigation_flag", ""))
    if flag.is_empty() or bool(flags.get(flag, false)):
        return {}
    for requirement in item.get("requires_flags", []):
        if not bool(flags.get(str(requirement),false)):
            return {}
    return item

func inspection_lines(item: Dictionary) -> Array:
    var lines: Array = [{"speaker":"旁白","text":str(item.get("name", "遗失之物")) + "：" + str(item.get("description",""))}]
    for entry in item.get("after_inspect", []):
        if entry is Dictionary:
            lines.append(entry)
    return lines

func latest_prior_choice(chapter: int,flags: Dictionary) -> Dictionary:
    return choice_echoes.latest_prior_choice(chapter,flags)

func npc_state(chapter: int, scene_index: int, flags: Dictionary) -> Dictionary:
    var pack: Dictionary = npc_by_chapter.get(_key(chapter),{})
    var states: Dictionary = pack.get("npc_states",{})
    var phase: String = "before"
    if bool(flags.get("story.ch%03d.done" % chapter,false)):
        phase = "completed"
    elif scene_index >= 1:
        phase = "investigating"
    var original: Dictionary = states.get(phase,{})
    if original.is_empty():
        return {}
    var echo: Dictionary = latest_prior_choice(chapter,flags)
    if echo.is_empty():
        return original
    var updated: Dictionary = original.duplicate(true)
    updated["text"] = str(original.get("text",""))+"\n旅途传来的后续消息："+str(echo.get("observation",""))
    updated["world_echo_event_id"] = str(echo.get("event_id",""))
    return updated

func midpoint(chapter: int, flags: Dictionary) -> Dictionary:
    if chapter < 1 or bool(flags.get("explore.ch%03d.midpoint" % chapter,false)):
        return {}
    var entries: Array = objects(chapter)
    if entries.size() < 2:
        return {}
    for item in entries:
        if not bool(flags.get(str(item.get("investigation_flag","")),false)):
            return {}
    return midpoint_by_chapter.get(_key(chapter),{})

func counts() -> Dictionary:
    return {"objects":objects_by_chapter.size(),"npcs":npc_by_chapter.size(),"midpoints":midpoint_by_chapter.size()}
