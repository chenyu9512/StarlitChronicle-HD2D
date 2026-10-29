extends SceneTree
## Verify 153 actual V4 2D interiors, unique physically imported material
## and collision-neutral furniture/wall layers.
const V4 = preload("res://scripts/world_interior_v4.gd")
const Art = preload("res://scripts/world_interior_art.gd")
var faults: Array[String]=[]
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, detail: String) -> void:
    if not ok:
        faults.append(detail)
func _run() -> void:
    var base: String="res://data/levels/v4/interiors/"
    var entries: PackedStringArray=DirAccess.get_files_at(base)
    var total: int=0
    var unique: Dictionary={}
    for file in entries:
        if not file.ends_with(".json"):
            continue
        var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(base+file))
        if not raw is Dictionary:
            faults.append("Bad JSON: "+file)
            continue
        var map_id: String=str(raw.get("map_id",""))
        var room_id: String=str(raw.get("building_id",""))
        var layout: Dictionary=V4.new().load_level(map_id,room_id,room_id)
        if layout.is_empty():
            faults.append("V4 geometry or interaction invalid: "+file)
            continue
        var collision: Dictionary=(layout.get("blocked",{}) as Dictionary).duplicate(true)
        var stage:=Node2D.new()
        stage.y_sort_enabled=true
        root.add_child(stage)
        var visual:=Art.new()
        stage.add_child(visual)
        visual.install(stage,layout,720)
        var label: String=map_id+"#"+room_id
        check(visual.generated_floor_layer!=null and visual.generated_floor_count>0,label+" has no own generated floor detailing")
        if visual.generated_floor_layer!=null:
            var src: String=str(visual.generated_floor_layer.get_meta("room_material_path",""))
            check(not src.is_empty() and not unique.has(src),label+" duplicates another room atlas")
            unique[src]=true
        check(visual.detail_layer!=null and visual.detail_layer.get_used_cells().size()>0,label+" missing wall edges")
        check(visual.prop_nodes.size()>0,label+" no rendered furniture")
        for value in visual.prop_nodes.values():
            var prop: Sprite2D=value as Sprite2D
            check(prop!=null and prop.texture!=null,label+" untextured furnishing")
        check((layout.get("blocked",{}) as Dictionary)==collision,label+" altered game collision")
        stage.free()
        total+=1
    check(total==153 and unique.size()==153,"Expected 153 distinct playable V4 rooms; found "+str(total))
    if faults.is_empty():
        print("PASS 153 actual authored V4 interiors: unique atlas, wall art, furniture; collision preserved")
        quit(0)
    else:
        for message in faults:
            push_error(message)
        quit(1)
