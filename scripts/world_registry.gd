extends RefCounted
## 单一世界路由注册表：42个地图定义、8个地区、72章任务锚点和安全旅行。
## 没有美术场景的地图会走可识别的程序化占位路径，不伪装为已绘制的成品地图。
const WORLD_MAPS: String = "res://data/content/maps.json"
const WORLD_REGIONS: String = "res://data/content/regions.json"
const WORLD_QUESTS: String = "res://data/content/quests.json"
const INITIAL_MAP: String = "map_coast_01"
const Geography = preload("res://scripts/world_geography.gd")
var maps: Dictionary = {}
var geography = Geography.new()
var regions: Dictionary = {}
var chapter_maps: Dictionary = {}
var first_chapter: Dictionary = {}
var errors: Array[String] = []
var state

func _init() -> void:
    for entry in _read(WORLD_MAPS).get("entries", []):
        if not entry is Dictionary:
            continue
        var key: String = str(entry.get("id",""))
        maps[key] = entry
    for entry in _read(WORLD_REGIONS).get("entries", []):
        if entry is Dictionary:
            regions[str(entry.get("id",""))] = entry
    for entry in _read(WORLD_QUESTS).get("entries", []):
        if not entry is Dictionary or str(entry.get("kind","")) != "main":
            continue
        var chapter: int = int(entry.get("chapter",0))
        var map_id: String = str(entry.get("map_id",""))
        if chapter >= 1 and chapter <= 72 and maps.has(map_id):
            chapter_maps[chapter] = map_id
            if not first_chapter.has(map_id):
                first_chapter[map_id] = chapter
            else:
                first_chapter[map_id] = mini(chapter,int(first_chapter[map_id]))
    errors = validate_catalog()

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Dictionary else {}

func validate_catalog() -> Array[String]:
    var issues: Array[String] = []
    if maps.size() != 42:
        issues.append("应有42张地图规划，实际%d张" % maps.size())
    if regions.size() != 8:
        issues.append("应有8个地区，实际%d个" % regions.size())
    if chapter_maps.size() != 72:
        issues.append("72章地图锚点缺失，现有%d章" % chapter_maps.size())
    for error in geography.faults:
        issues.append(str(error))
    for id in maps.keys():
        if geography.zone(str(id)).is_empty():
            issues.append("地图在空间图集中缺失：%s" % str(id))
    for key in maps:
        var item: Dictionary = maps[key]
        if not regions.has(str(item.get("region_id",""))):
            issues.append("%s 地区ID无效" % key)
        for neighbor in item.get("neighbors",[]):
            if not maps.has(str(neighbor)):
                issues.append("%s 有不存在的出口 %s" % [key,str(neighbor)])
            elif key not in (maps[str(neighbor)].get("neighbors",[]) as Array):
                issues.append("%s → %s 出口不是双向" % [key,str(neighbor)])
    return issues

func bind(progress) -> void:
    state = progress
    if not state.rpg.get("world") is Dictionary:
        state.rpg["world"] = {}
    var world: Dictionary = state.rpg["world"]
    if not world.get("visited") is Array:
        world["visited"] = []
    if not world.get("discovered") is Array:
        world["discovered"] = []
    if not world.has("bound_chapter"):
        world["bound_chapter"] = -1
    if not world.has("travel_count"):
        world["travel_count"] = 0
    sync_chapter(int(state.chapter))

func _mark_visited(map_id: String) -> void:
    var world: Dictionary = state.rpg["world"]
    if map_id not in (world["visited"] as Array):
        (world["visited"] as Array).append(map_id)
    if map_id not in (world["discovered"] as Array):
        (world["discovered"] as Array).append(map_id)
    for neighbor in maps[map_id].get("neighbors",[]):
        if str(neighbor) not in (world["discovered"] as Array):
            (world["discovered"] as Array).append(str(neighbor))

func chapter_map(chapter: int) -> String:
    return INITIAL_MAP if chapter < 1 else str(chapter_maps.get(chapter,INITIAL_MAP))

func sync_chapter(chapter: int) -> void:
    if state == null:
        return
    var world: Dictionary = state.rpg["world"]
    var selected: String = str(world.get("current_map",""))
    if int(world.get("bound_chapter",-1)) != chapter or not maps.has(selected):
        selected = chapter_map(chapter)
        world["current_map"] = selected
        world["bound_chapter"] = chapter
    _mark_visited(selected)

func current_map() -> String:
    if state == null:
        return INITIAL_MAP
    return str(state.rpg["world"].get("current_map",INITIAL_MAP))

func map_info(map_id: String) -> Dictionary:
    return maps.get(map_id, {})

func current_info() -> Dictionary:
    return map_info(current_map())

func region_info(map_id: String) -> Dictionary:
    return regions.get(str(map_info(map_id).get("region_id","")),{})

func profile(map_id: String = "") -> Dictionary:
    var id: String = current_map() if map_id.is_empty() else map_id
    var info: Dictionary = map_info(id)
    if info.is_empty():
        return {}
    var region: String = str(info.get("region_id","region_coast"))
    var theme: Dictionary = {
        "region_coast":Color("8eb3aa"), "region_oaths":Color("b6aaa0"),
        "region_forge":Color("c39b7e"), "region_isles":Color("80c4ca"),
        "region_mirror":Color("a9abd0"), "region_oldland":Color("b5a891"),
        "region_sanctum":Color("c6b6db"), "region_city":Color("dbbf8c")
    }
    var authored: bool = str(info.get("scene_path","")).begins_with("res://scenes/")
    return {
        "id":id, "name":str(info.get("name",id)),
        "region_id":region, "region_name":str(regions.get(region,{}).get("name",region)),
        "kind":str(info.get("type","field")), "color":theme.get(region,Color.WHITE),
        "seed":id.hash(), "authored_scene":authored,
        "atlas_coordinates":geography.zone(id).get("atlas",[]),
        "biome":geography.zone(id).get("biome","coastal"),
        "settlement":geography.zone(id).get("settlement",false),
        "spatial_sector":true,
        "chapter_anchor":int(first_chapter.get(id,0)),
        "neighbors":info.get("neighbors",[])
    }

func is_available(map_id: String) -> bool:
    if state == null or not maps.has(map_id):
        return false
    if str(maps[map_id].get("type","")) == "prototype":
        return false
    var required: int = int(first_chapter.get(map_id,999))
    if required > int(state.chapter):
        return false
    return map_id in (state.rpg["world"].get("discovered",[]) as Array)

func neighbors() -> Array:
    var result: Array = []
    for neighbor in current_info().get("neighbors",[]):
        var map_id: String = str(neighbor)
        var info: Dictionary = profile(map_id)
        if info.is_empty():
            continue
        info["unlocked"] = is_available(map_id)
        info["visited"] = map_id in (state.rpg["world"].get("visited",[]) as Array)
        result.append(info)
    return result

func shortest_route(target: String) -> Array[String]:
    # Navigation aid only: each leg still uses can_travel and the saved discovery locks.
    var route: Array[String] = []
    if state == null or not is_available(target):
        return route
    var initial: String = current_map()
    if target == initial:
        route.append(initial)
        return route
    # Real map IDs must be indexed keys, not GDScript's literal "initial".
    var seen: Dictionary = {}
    seen[initial] = ""
    var queue: Array[String] = [initial]
    var offset: int = 0
    while offset < queue.size() and not seen.has(target):
        var here: String = queue[offset]
        offset += 1
        for value in maps[here].get("neighbors",[]):
            var next_id: String = str(value)
            if not seen.has(next_id) and is_available(next_id):
                seen[next_id] = here
                queue.append(next_id)
    if not seen.has(target):
        return route
    var backtrack: String = target
    while not backtrack.is_empty():
        route.push_front(backtrack)
        backtrack = str(seen.get(backtrack,""))
    return route

func can_travel(target: String) -> bool:
    if state == null or target == current_map() or not is_available(target):
        return false
    return target in (current_info().get("neighbors",[]) as Array)

func travel(target: String) -> bool:
    if not can_travel(target):
        return false
    state.rpg["world"]["current_map"] = target
    state.rpg["world"]["travel_count"] = int(state.rpg["world"].get("travel_count",0)) + 1
    _mark_visited(target)
    return true

func visited_count() -> int:
    if state == null:
        return 0
    return (state.rpg["world"].get("visited",[]) as Array).size()
