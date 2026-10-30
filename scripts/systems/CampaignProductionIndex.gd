extends RefCounted
## Read-only chapter/quest production contracts. This never advances a quest,
## recruits actors, pays rewards or claims a gameplay test passed.
const ROOT: String = "res://story/"
const SOURCE_QUESTS: Array[String] = ["side_quests","companion_quests","regional_quests_v2"]
const PHASES: Array[String] = ["opening","investigate","crisis","resolve"]
var chapters: Dictionary = {}
var quests: Dictionary = {}
var bosses: Dictionary = {}
var mechanics: Dictionary = {}
var play_patterns: Dictionary = {}
var default_pattern: Dictionary = {}
var errors: Array[String] = []

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        errors.append("Missing: "+path)
        return {}
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (data is Dictionary):
        errors.append("Malformed: "+path)
        return {}
    return data

func load_all() -> bool:
    chapters.clear()
    quests.clear()
    bosses.clear()
    mechanics.clear()
    play_patterns.clear()
    errors.clear()
    for act in range(1,13):
        var path: String = ROOT+"campaign/act_%02d.json" % act
        var act_source: Dictionary = _read(path)
        var act_chapters: Array = act_source.get("chapters",[])
        if int(act_source.get("act",-1)) != act or act_chapters.size()!=6:
            errors.append("Act identity or six-chapter block mismatch: "+str(act))
        for index in range(act_chapters.size()):
            var item: Variant = act_chapters[index]
            if not (item is Dictionary):
                continue
            var entry: Dictionary = item
            var cid: String = str(entry.get("id",""))
            var chapter_no: int = int(entry.get("number",0))
            if cid != "ch%03d" % chapter_no or chapter_no < 1 or chapter_no > 72 or chapters.has(cid):
                errors.append("Bad chapter ID: "+cid)
                continue
            if int(entry.get("act",0))!=act or chapter_no!=(act-1)*6+index+1:
                errors.append("Chapter order/act authority mismatch: "+cid)
            if str(entry.get("chapter_complete_flag",""))!="story."+cid+".done":
                errors.append("Chapter completion flag mismatch: "+cid)
            var scenes: Array[String] = []
            for scene in entry.get("scenes",[]):
                if not scene is Dictionary:
                    errors.append("Non-dictionary scene in "+cid)
                    continue
                var sid: String = str(scene.get("id",""))
                if sid.is_empty() or not sid.begins_with(cid+".") or sid in scenes:
                    errors.append("Bad, foreign or duplicate scene: "+cid+"/"+sid)
                    continue
                scenes.append(sid)
            for phase in PHASES:
                if (cid+"."+phase) not in scenes:
                    errors.append("Missing phase: "+cid+"."+phase)
            chapters[cid] = {
                "id":cid,"number":chapter_no,"act":act,
                "title":str(entry.get("title","")),"location":str(entry.get("location","")),
                "source":path,"scene_ids":scenes,
                "required_flags":entry.get("required_flags",[]),
                "completion_flag":str(entry.get("chapter_complete_flag","story."+cid+".done"))
            }
    for file in SOURCE_QUESTS:
        var path: String = ROOT+"data/"+file+".json"
        for item in _read(path).get("quests",[]):
            if not (item is Dictionary):
                continue
            var entry: Dictionary = item
            var qid: String = str(entry.get("id",""))
            if qid.is_empty() or quests.has(qid):
                errors.append("Bad quest ID: "+qid)
                continue
            var category: String = "lost_page" if qid.begins_with("sq_page") else (
                "life" if qid.begins_with("sq_life") else (
                "companion" if qid.begins_with("cq_") else "regional"))
            var required_chapter: String = str(entry.get("required_chapter",""))
            if not chapters.has(required_chapter):
                errors.append("Quest references unknown chapter: "+qid+" -> "+required_chapter)
            if str(entry.get("completion_flag",""))!="side."+qid+".done":
                errors.append("Quest completion identity mismatch: "+qid)
            var quest_stages: Array = entry.get("stages",[])
            if quest_stages.is_empty():
                errors.append("Quest has no playable stage contract: "+qid)
            var seen_stages: Dictionary = {}
            for stage in quest_stages:
                if not stage is Dictionary:
                    errors.append("Non-dictionary quest stage: "+qid)
                    continue
                var stage_id: String = str(stage.get("id",""))
                if stage_id.is_empty() or not stage_id.begins_with(qid+".") or seen_stages.has(stage_id):
                    errors.append("Duplicate, foreign or empty quest stage: "+qid+"/"+stage_id)
                seen_stages[stage_id] = true
            quests[qid] = {
                "id":qid,"title":str(entry.get("title","")),"category":category,
                "source":path,
                "required_chapter":str(entry.get("required_chapter","ch001")),
                "completion_flag":str(entry.get("completion_flag","side."+qid+".done")),
                "stage_count":(entry.get("stages",[]) as Array).size()
            }
    var boss_ids: Dictionary = {}
    for item in _read(ROOT+"data/bosses.json").get("bosses",[]):
        if not item is Dictionary:
            errors.append("Non-dictionary Boss catalog entry")
            continue
        var cid: String = str(item.get("chapter_id",""))
        var boss_id: String = str(item.get("id",""))
        if not chapters.has(cid) or cid.is_empty() or boss_id.is_empty():
            errors.append("Boss references missing chapter or identity: "+boss_id+"/"+cid)
            continue
        if bosses.has(cid) or boss_ids.has(boss_id):
            errors.append("Duplicate Boss chapter or runtime identity: "+boss_id+"/"+cid)
            continue
        boss_ids[boss_id] = true
        bosses[cid] = boss_id
    mechanics = _read(ROOT+"runtime/mechanics_registry.json").get("chapter_mechanics_bindings",{})
    var pattern_pack: Dictionary = _read(ROOT+"runtime/chapter_play_patterns.json")
    play_patterns = pattern_pack.get("chapters",{})
    default_pattern = pattern_pack.get("default",{})
    if play_patterns.size()!=72:
        errors.append("72 chapter play-pattern contracts are not complete")
    for chapter_id in play_patterns.keys():
        if not chapters.has(chapter_id):
            errors.append("Play pattern refers to an unknown chapter: "+str(chapter_id))
    for chapter_id in mechanics.keys():
        if not chapters.has(chapter_id):
            errors.append("Mechanics reference an unknown chapter: "+str(chapter_id))
    if chapters.size()!=72 or quests.size()!=120 or bosses.size()!=66:
        errors.append("Unexpected 72/120/66 catalog cardinality")
    return errors.is_empty()

static func epoch_for(chapter: int, flags: Dictionary = {}) -> String:
    if chapter == 21 and bool(flags.get("ch021.campfire_returned",false)):
        return "present"
    if chapter >= 19 and chapter <= 21:
        return "historical"
    if chapter >= 49:
        return "twelve_years_later"
    if chapter >= 43:
        return "black_star"
    if chapter >= 37:
        return "chronicle_corridor"
    if chapter >= 31:
        return "mirror"
    return "present"

func chapter_contract(id: String, flags: Dictionary = {}) -> Dictionary:
    if not chapters.has(id):
        return {}
    var record: Dictionary = (chapters[id] as Dictionary).duplicate(true)
    record["epoch"] = epoch_for(int(record.get("number",0)),flags)
    record["boss_id"] = str(bosses.get(id,""))
    record["play_pattern"] = (play_patterns.get(id,default_pattern) as Dictionary).duplicate(true)
    record["mechanics"] = (mechanics.get(id,{}) as Dictionary).duplicate(true)
    record["acceptance"] = "unverified"
    return record

func quest_contract(id: String) -> Dictionary:
    return (quests.get(id,{}) as Dictionary).duplicate(true)

func quests_by_chapter(chapter: int) -> Array:
    var items: Array = []
    for value in quests.values():
        var record: Dictionary = value
        var required: String = str(record.get("required_chapter","ch001"))
        if required.begins_with("ch") and required.trim_prefix("ch").is_valid_int():
            if chapter >= int(required.trim_prefix("ch")):
                items.append(record.duplicate(true))
    return items

func summary() -> Dictionary:
    var categories: Dictionary = {"life":0,"companion":0,"regional":0,"lost_page":0}
    for value in quests.values():
        var category: String = str(value.get("category",""))
        categories[category] = int(categories.get(category,0))+1
    return {"chapters":chapters.size(),"quests":quests.size(),
        "bosses":bosses.size(),"categories":categories,
        "mechanics_registered":mechanics.size(),"qa":"not_executed"}
