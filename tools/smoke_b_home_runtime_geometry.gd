extends SceneTree
## B indoor authoritative geometry gate: consumers may only see active V4
## investigation cells, never unreachable ghost props dropped by the real loader.
const Home = preload("res://scripts/world_home_interactions.gd")
const V4 = preload("res://scripts/world_interior_v4.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failures.append(reason)

func _run() -> void:
    var home=Home.new()
    var loader=V4.new()
    var files: PackedStringArray=DirAccess.get_files_at("res://data/levels/v4/interiors")
    var inspected: int=0
    var regular_rooms: int=0
    var regular_props: int=0
    for file_name in files:
        if not file_name.ends_with(".json"):
            continue
        var path: String="res://data/levels/v4/interiors/"+file_name
        var payload: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
        if not payload is Dictionary:
            check(false,"Unreadable V4 room "+file_name)
            continue
        var record: Dictionary=payload
        var map_id: String=str(record.get("map_id",""))
        var building_id: String=str(record.get("building_id",""))
        var physical: Dictionary=loader.load_level(map_id,building_id,str(record.get("name","")))
        check(not physical.is_empty(),"Unbuildable V4 interior "+file_name)
        if physical.is_empty():
            continue
        var active: Dictionary={}
        for obj in physical.get("investigations",[]):
            active[str(obj.get("id",""))]=obj.get("cell",Vector2i(-1,-1))
        var candidates: Array=home.objects(map_id,building_id)
        for item in candidates:
            var id: String=str(item.get("id",""))
            var grid: Array=item.get("cell",[])
            check(active.has(id),"Home offered nonphysical decoration "+file_name+"/"+id)
            if grid.size()==2 and active.has(id):
                check(active[id]==Vector2i(int(grid[0]),int(grid[1])),
                    "Home physical cell did not match live terrain "+file_name+"/"+id)
        if not building_id.begins_with("quest__"):
            regular_rooms+=1
            regular_props+=candidates.size()
        inspected+=1
    check(inspected==153,"All 153 actual V4 indoor assets must load")
    check(regular_rooms==68 and regular_props==168,
        "68 public buildings must expose 168 physically reachable inspectable objects")
    check(home.issues.is_empty(),"Furniture source contains invalid/ghost markers: "+str(home.issues))
    if failures.is_empty():
        print("PASS B indoor: 153 physical rooms, no phantom hotspots, 68 buildings / 168 inspectables")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
