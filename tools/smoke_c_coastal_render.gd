extends SceneTree
## Dedicated C-line live renderer smoke: real map generation and C-only rendering.
## Does not grant rewards, write files, alter progression or fake screenshot output.
const Geography = preload("res://scripts/world_geography.gd")
const CoastScene = preload("res://scripts/world_coastal_scene.gd")
const CoastPainter = preload("res://scripts/c_coastal_painter.gd")
const Structure = preload("res://scripts/world_structure.gd")
var errors: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,msg: String) -> void:
    if not ok:
        errors.append(msg)

func _run() -> void:
    var geo:=Geography.new()
    for map_id in ["map_coast_01","map_coast_02"]:
        var layout: Dictionary=geo.layout(map_id,1)
        var blocked_before: Dictionary=layout.get("blocked",{}).duplicate(true)
        var water_before: Dictionary=layout.get("water_mask",{}).duplicate(true)
        var stage:=Node2D.new()
        stage.y_sort_enabled=true
        root.add_child(stage)
        var scene:=CoastScene.new()
        stage.add_child(scene)
        scene.configure(map_id,layout,stage)
        check(scene.illustrated_dressing!=null,map_id+": painter missing")
        if scene.illustrated_dressing!=null:
            var painter: Node2D=scene.illustrated_dressing
            check(painter.accent_layer is TileMapLayer,map_id+": real TileMapLayer missing")
            check(painter.accent_count>25,map_id+": no illustrated ground cells")
            if map_id == "map_coast_01":
                check(painter.road_layer is TileMapLayer, "Morning Dew independent road atlas layer missing")
                check(painter.road_count > 25, "Morning Dew road material not applied to enough cells")
                if painter.road_layer != null:
                    check(painter.road_layer.get_used_cells().size() == painter.road_count, "Road atlas count mismatch")
                    for road_cell in painter.road_layer.get_used_cells():
                        check(not blocked_before.has(road_cell), "Road detail painted on blocked cell")
                        check(not water_before.has(road_cell), "Road detail painted on water")
                        check(layout.get("tiles",{}).get(road_cell,Vector2i(-1,-1)).y == 3, "Road detail painted off the existing road")
            else:
                check(painter.road_layer == null, "Morning Dew road atlas leaked into harbor")
            check(painter.placements.size()>=2,map_id+": authored set pieces not visible")
            check(painter.active_lights.size()>=1,map_id+": street lantern light missing")
            for sprite in painter.placements.values():
                var cell: Vector2i=sprite.get_meta("art_foot",Vector2i(-1,-1))
                check(not blocked_before.has(cell),map_id+": set piece in wall")
                check(not water_before.has(cell),map_id+": set piece in water")
                check(sprite.z_index==3,map_id+": wrong Y-sort stratum")
            scene.set_clock(1340)
            for light in painter.active_lights:
                check(light.energy>0.0,map_id+": night light did not activate")
            scene.set_clock(720)
            for light in painter.active_lights:
                check(is_zero_approx(light.energy),map_id+": daylight light still lit")
            scene.set_visual_quality(0)
            for light in painter.active_lights:
                check(not light.visible,map_id+": low-quality lighting not disabled")
            scene.set_visual_quality(2)
        check(layout.get("blocked",{})==blocked_before,map_id+": C art mutated collision")
        check(layout.get("water_mask",{})==water_before,map_id+": C art mutated water mask")
        check(scene.reflections.size()<=32,map_id+": reflection limit exceeded")
        if not scene.reflections.is_empty():
            check(scene.reflections[0].material is ShaderMaterial,map_id+": shimmer shader not bound")
        stage.queue_free()
    var building:=Structure.new()
    root.add_child(building)
    building.setup("inn","晨露村旅馆",Vector2i(8,6),"coastal","map_coast_01",1200,Vector2i(0,3))
    check(building.entrance_local==Vector2(0,96),"Facade and canonical door not aligned")
    building.set_clock(1200)
    check(building.door_lamp!=null,"Building frontage light missing")
    building.queue_free()
    if errors.is_empty():
        print("PASS C coastal render: 2 authored atlases, real TileMap, Y-sorted props, light clock, capped shader water, no collision writes")
        quit(0)
    for issue in errors:
        push_error(issue)
    quit(1)
