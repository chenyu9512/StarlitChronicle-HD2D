extends RefCounted
## B-line Act-I offline chapter wayfinding. This is a READ-ONLY adviser, not a
## replacement for D's chapter routing, world save, gate or reward authority.
## No fog, no global atlas and no teleport/fast travel is added.
const SOURCE: String = "res://data/levels/act01_scene_locations_v1.json"
const ATLAS: String = "res://data/levels/world_atlas_v2.json"
const QUESTS: String = "res://data/content/quests.json"

var chapters: Dictionary = {}
var sectors: Dictionary = {}
var chapter_gates: Dictionary = {}
var issues: Array[String] = []


static func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}


func _init() -> void:
    var authored: Dictionary=_read(SOURCE)
    var atlas: Dictionary=_read(ATLAS)
    var quests: Dictionary=_read(QUESTS)
    if str(authored.get("schema",""))!="starlit.b.act01.scene_location_contract.v1":
        issues.append("Missing original Act-I scene route contract")
        return
    for raw in atlas.get("zones",[]):
        if raw is Dictionary:
            var record: Dictionary=raw
            sectors[str(record.get("id",""))]=record
    for raw in quests.get("entries",[]):
        if not raw is Dictionary or str(raw.get("kind",""))!="main":
            continue
        var q: Dictionary=raw
        var map_id: String=str(q.get("map_id",""))
        var chapter: int=int(q.get("chapter",0))
        if not chapter_gates.has(map_id):
            chapter_gates[map_id]=chapter
        else:
            chapter_gates[map_id]=mini(chapter,int(chapter_gates[map_id]))
    for raw in authored.get("chapters",[]):
        if not raw is Dictionary:
            issues.append("Non-object Act-I route")
            continue
        var record: Dictionary=raw
        var chapter: int=int(record.get("chapter",-1))
        var journey: Array=record.get("route_map_ids",[])
        var desired: String=str(record.get("required_map_id",""))
        if chapter<1 or chapter>6 or chapters.has(chapter) or journey.is_empty():
            issues.append("Broken or duplicate Act-I chapter route "+str(chapter))
            continue
        if str(journey[journey.size()-1])!=desired:
            issues.append("Chapter %d route does not end in its real story location" % chapter)
            continue
        for index in range(journey.size()):
            var map_id: String=str(journey[index])
            if not sectors.has(map_id):
                issues.append("Unknown authored map "+map_id)
                continue
            if index>0:
                var previous: String=str(journey[index-1])
                if map_id not in (sectors.get(previous,{}) as Dictionary).get("neighbors",[]):
                    issues.append("Act-I chapter %d jumps over a missing exit: %s to %s" % [chapter,previous,map_id])
        chapters[chapter]=record.duplicate(true)
    if chapters.size()!=6:
        issues.append("All six original Act-I chapters need physical routes")


func route(chapter: int) -> Array[String]:
    var record: Dictionary=chapters.get(chapter,{})
    var result: Array[String]=[]
    for id in record.get("route_map_ids",[]):
        result.append(str(id))
    return result


func preview(chapter: int,current_map: String,state) -> Dictionary:
    # No mutator, no WorldRegistry.bind() and no calls to State.save().
    if state==null or not issues.is_empty() or not chapters.has(chapter):
        return {"valid":false,"reason":"invalid_chapter_or_catalog"}
    # The authoritative save chapter, not an arbitrary UI argument, owns
    # gate eligibility. Never offer a future chapter's route early.
    if int(state.chapter)!=chapter:
        return {"valid":false,"reason":"chapter_mismatch"}
    var info: Dictionary=chapters[chapter]
    var stages: Array[String]=route(chapter)
    var position: int=stages.find(current_map)
    var destination: String=str(info.get("required_map_id",""))
    var building: String=str(info.get("required_building_id",""))
    var outcome: Dictionary={
        "valid":true,"chapter":chapter,"current_map_id":current_map,
        "target_map_id":destination,"target_building_id":building,
        "story_location":str(info.get("story_location","")),
        "route_map_ids":stages.duplicate(),"arrived_at_map":position==stages.size()-1,
        "next_map_id":"","can_take_next_leg":false,"blocked_reason":"",
        "requires_save":false
    }
    if position<0:
        outcome["blocked_reason"]="outside_authored_route"
        outcome["guidance"]=str(info.get("route_guidance",
            "沿已发现的道路前往"+str(outcome["story_location"])))
        return outcome
    if position==stages.size()-1:
        outcome["guidance"]=str(info.get("arrived_guidance",
            "已到达"+str(outcome["story_location"])+"，请沿实际道路接近调查对象。"))
        return outcome
    var next_map: String=stages[position+1]
    outcome["next_map_id"]=next_map
    var rpg: Dictionary=state.rpg if state.rpg is Dictionary else {}
    var world: Dictionary=rpg.get("world",{}) if rpg.get("world",{}) is Dictionary else {}
    var discovered: Array=world.get("discovered",[]) if world.get("discovered",[]) is Array else []
    var first_chapter: int=int(chapter_gates.get(next_map,999))
    var permitted: bool=first_chapter<=chapter and next_map in discovered
    outcome["can_take_next_leg"]=permitted
    if not permitted:
        outcome["blocked_reason"]="chapter_gate" if first_chapter>chapter else "not_discovered"
        outcome["guidance"]=str(info.get("locked_guidance",
            "通往"+str(outcome["story_location"])+"的道路尚未开放。"))
    else:
        outcome["guidance"]=str(info.get("route_guidance",
            "沿实际道路前往"+str(outcome["story_location"]))) + "\n下一站：" + str(sectors[next_map].get("name",next_map))
    return outcome
