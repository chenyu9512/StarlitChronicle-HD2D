extends RefCounted
## B-line read-only world response to all 72 authored chapter decisions.
## Reuses the already saved flags and existing canonical responses, without
## changing rewards, quest IDs, chapter state, combat outcomes or terrain.
const CAMPAIGN = "res://story/campaign/"
const QUESTS = "res://data/content/quests.json"
const RESPONSES = "res://story/data/choice_response_lock26.json"
var all_events: Array[Dictionary] = []
var by_map: Dictionary = {}
var errors: Array[String] = []

static func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

func _init() -> void:
    var locations: Dictionary = {}
    for quest in _read(QUESTS).get("entries",[]):
        if quest is Dictionary and str(quest.get("kind",""))=="main":
            locations[str(quest.get("story_chapter_id",""))]=str(quest.get("map_id",""))
    var responses: Dictionary = _read(RESPONSES).get("replies",{})
    for act_number in range(1,13):
        var act: Dictionary = _read(CAMPAIGN+"act_%02d.json" % act_number)
        for item in act.get("chapters",[]):
            if not (item is Dictionary):
                continue
            var chapter: Dictionary = item
            var chapter_id: String = str(chapter.get("id",""))
            var map_id: String = str(locations.get(chapter_id,""))
            var crisis: Dictionary = {}
            for raw_scene in chapter.get("scenes",[]):
                if raw_scene is Dictionary and raw_scene.has("choice"):
                    crisis=raw_scene
                    break
            if map_id.is_empty() or crisis.is_empty():
                errors.append("Missing mapped chapter choice "+chapter_id)
                continue
            var opts: Array = (crisis.get("choice",{}) as Dictionary).get("options",[])
            var authored: Dictionary = responses.get(str(crisis.get("id","")),{})
            if opts.size()!=2 or authored.is_empty():
                errors.append("Missing choice pair "+chapter_id)
                continue
            var routes: Array[Dictionary] = []
            for i in range(2):
                var option: Dictionary = opts[i]
                var lines: Array = authored.get("a" if i==0 else "b",[])
                var text_line: String = ""
                if not lines.is_empty():
                    text_line=str(lines[lines.size()-1].get("text",""))
                var stored: Variant = (option.get("sets",{}) as Dictionary).get(chapter_id+".approach",null)
                if stored==null or text_line.is_empty():
                    errors.append("Missing stored consequence "+chapter_id)
                    continue
                routes.append({"id":str(option.get("id","")),"value":stored,
                    "label":str(option.get("label","")),"observation":text_line})
            if routes.size()!=2:
                continue
            var record: Dictionary = {"chapter_id":chapter_id,"number":int(chapter.get("number",0)),
                "map_id":map_id,"choice_flag":chapter_id+".approach",
                "completed_flag":"story."+chapter_id+".done",
                "event_id":"b.choice."+chapter_id,"routes":routes}
            all_events.append(record)
            var bucket: Array = by_map.get(map_id,[])
            bucket.append(record)
            by_map[map_id]=bucket
    if all_events.size()!=72:
        errors.append("Expected 72 choices, received "+str(all_events.size()))

static func _resolve(record: Dictionary,flags: Dictionary) -> Dictionary:
    if not bool(flags.get(str(record.get("completed_flag","")),false)):
        return {}
    var selected: Variant = flags.get(str(record.get("choice_flag","")),null)
    for route in record.get("routes",[]):
        if selected==route.get("value",null):
            return {"event_id":str(record.get("event_id",""))+"."+str(route.get("id","")),
                "chapter_id":str(record.get("chapter_id","")),
                "chapter":int(record.get("number",0)),
                "label":str(route.get("label","")),
                "observation":str(route.get("observation","")),
                "route":str(route.get("id",""))}
    return {}

func latest_world_echo(map_id: String,flags: Dictionary) -> Dictionary:
    var last: Dictionary = {}
    for record in by_map.get(map_id,[]):
        var result: Dictionary = _resolve(record,flags)
        if not result.is_empty() and int(result["chapter"])>=int(last.get("chapter",-1)):
            last=result
    return last

func latest_prior_choice(chapter: int,flags: Dictionary) -> Dictionary:
    var last: Dictionary = {}
    for record in all_events:
        if int(record.get("number",0))>=chapter:
            continue
        var result: Dictionary = _resolve(record,flags)
        if not result.is_empty() and int(result["chapter"])>=int(last.get("chapter",-1)):
            last=result
    return last
