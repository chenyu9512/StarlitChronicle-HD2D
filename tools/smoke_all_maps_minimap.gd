extends SceneTree
## B map-display regression: full fog-free local maps and compact minimaps
## for all 40 sectors and real interiors. No story flag or cheat travel mutations.
const World = preload("res://scripts/first_act_world.gd")
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const Atlas = preload("res://scripts/map_hud.gd")
const Levels = preload("res://scripts/world_level_v3.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _run() -> void:
    var state = State.new()
    state.chapter = 1
    var router = Registry.new()
    router.bind(state)
    var world = World.new()
    root.add_child(world)
    var atlas = Atlas.new()
    root.add_child(atlas)
    atlas.bind_world(world,router)
    var levels = Levels.new()
    var completed: int = 0
    var ids: Array = router.maps.keys()
    ids.sort()
    for raw_id in ids:
        var map_id: String = str(raw_id)
        if str(router.map_info(map_id).get("type",""))=="prototype":
            continue
        state.rpg["world"]["current_map"] = map_id
        world.map_profile = router.profile(map_id)
        world.interior_building = ""
        world.interior_kind = ""
        world.build(1,2)
        var source: Dictionary = levels.level(map_id)
        var dimensions: Array = source.get("size",[])
        check(dimensions.size()==2,"No authored dimensions for "+map_id)
        if dimensions.size()!=2:
            continue
        var extent: Vector2i = Vector2i(int(dimensions[0]),int(dimensions[1]))
        check(world.WIDTH==extent.x and world.HEIGHT==extent.y,
            "Live renderer dimensions mismatch "+map_id)
        check(world.layer.get_used_cells().size()>=extent.x*extent.y,
            "TileMapLayer has missing cells on "+map_id)
        var compact: Dictionary = atlas.small_view.local_frame()
        var expanded: Dictionary = atlas.full_view.local_frame()
        check(not compact.is_empty() and not expanded.is_empty(),
            "Local map failed to initialize on "+map_id)
        if not compact.is_empty() and not expanded.is_empty():
            check(int(compact.get("width",0))==extent.x and int(compact.get("height",0))==extent.y,
                "Compact map uses legacy dimensions "+map_id)
            check(int(expanded.get("columns",0))==extent.x and int(expanded.get("rows",0))==extent.y,
                "Expanded map does not show full terrain "+map_id)
            check(int(compact["first_x"])>=0 and int(compact["first_y"])>=0,
                "Compact map has negative origin "+map_id)
            check(int(compact["first_x"])+int(compact["columns"])<=extent.x
                and int(compact["first_y"])+int(compact["rows"])<=extent.y,
                "Compact viewport overruns terrain "+map_id)
        atlas.full_view.zoom_local(2.0)
        var detail: Dictionary = atlas.full_view.local_frame()
        if not detail.is_empty():
            check(int(detail["columns"])<extent.x and int(detail["rows"])<extent.y,
                "Zoom should reveal map detail "+map_id)
        atlas.full_view.reset_local_view()
        completed += 1
    check(completed==40,"Expected all 40 live production TileMapLayers to render")

    # A real house transition updates the current-area map, without fog or
    # revealing anything in the save and without advancing story progress.
    state.rpg["world"]["current_map"]="map_coast_01"
    world.map_profile=router.profile("map_coast_01")
    world.build(1,2)
    var exterior_size: Vector2i=world.terrain_layout.get("size",Vector2i.ZERO)
    var chapter_before: int=state.chapter
    var flags_before: Dictionary=state.flags.duplicate(true)
    check(world.enter_building("inn"),"Morning Dew inn entry failed")
    check(world.interior_building=="inn","Interior map not selected")
    var indoor: Dictionary=atlas.small_view.local_frame()
    check(int(indoor.get("width",0))==72 and int(indoor.get("height",0))==48,
        "Minimap not resized to interior")
    check(world.leave_building(),"Failed to return from inn")
    var outdoor: Dictionary=atlas.full_view.local_frame()
    check(int(outdoor.get("width",0))==exterior_size.x,
        "Outdoor map dimensions did not recover")
    check(state.chapter==chapter_before and state.flags==flags_before,
        "Map or indoor view changed story flags")

    atlas.show_exploration(true)
    atlas.open_map()
    await process_frame
    check(atlas.full_view.mode=="local","Expanded map must remain local only")
    atlas._set_mode("world")
    check(atlas.full_view.mode=="world","World atlas mode must be available")
    atlas._set_mode("region")
    check(atlas.full_view.mode=="region","Regional atlas mode must be available")
    atlas._set_mode("local")
    check(atlas.full_view.mode=="local","Switching back to local terrain must work")
    check(not state.rpg.get("world",{}).has("fog"),
        "Viewing maps must not create persistent fog data")
    check(not router.can_travel("unknown_map"),"Viewing map unlocked forbidden travel")
    atlas.close_map()
    check(atlas.small_frame.visible,"Closing map should recover minimap")
    if failures.is_empty():
        print("PASS: all 40 map sizes, no-fog local/region/world modes, zoom, safe inn round-trip")
        quit(0)
    else:
        for problem in failures:
            push_error(problem)
        quit(1)
