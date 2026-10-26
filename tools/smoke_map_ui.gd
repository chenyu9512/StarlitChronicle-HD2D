extends SceneTree
## Real-engine map regression: fog-free current area, compact minimap, no global atlas.
const World = preload("res://scripts/first_act_world.gd")
const Atlas = preload("res://scripts/map_hud.gd")
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _expect(value: bool, message: String) -> void:
    if not value:
        errors.append(message)

func _run() -> void:
    var state = State.new()
    state.chapter = 1
    var router = Registry.new()
    router.bind(state)
    var world = World.new()
    root.add_child(world)
    world.map_profile = router.profile()
    world.build(1,2)
    var atlas = Atlas.new()
    root.add_child(atlas)
    atlas.bind_world(world,router)
    atlas.set_targets("key_npc","side_start")
    atlas.show_exploration(true)
    _expect(atlas.small_frame.visible,"Minimap should be visible during exploration")
    _expect(atlas.small_view.main_target == "key_npc","Minimap must show the current story target")
    _expect(atlas.small_view.side_target == "side_start","Minimap must show the current side quest")
    atlas.open_map()
    _expect(atlas.is_open(),"Touch/keyboard route must open area map")
    _expect(not atlas.small_frame.visible,"Compact map should be hidden behind the atlas")
    _expect(atlas.full_view.mode == "local","Expanded view must open on local terrain")
    atlas._set_mode("world")
    await process_frame
    _expect(atlas.full_view.mode == "local","Deprecated world chart must fall back to current area")
    _expect(atlas.full_view.local_frame().get("columns",0) == world.WIDTH,
        "Current area map must display the entire actual terrain without fog")
    _expect(atlas.small_view.local_frame().get("width",0) == world.WIDTH,
        "Compact minimap must track the actual playable world dimensions")
    _expect(not router.can_travel("unknown_map"),"Map UI must not unlock travel")
    var flags_before: Dictionary = state.flags.duplicate(true)
    var world_before: Dictionary = state.rpg.get("world",{}).duplicate(true)
    atlas.full_view.zoom_local(2.0)
    _expect(atlas.full_view.local_zoom > 1.0,"Current area map zoom must remain usable")
    atlas.full_view.reset_local_view()
    _expect(state.flags == flags_before and state.rpg.get("world",{}) == world_before,
        "Reading and zooming map must not mutate world state")
    atlas.close_map()
    _expect(not atlas.is_open(),"Closing map should remove modal")
    _expect(atlas.small_frame.visible,"Closing map should restore the minimap")
    atlas.show_exploration(false)
    _expect(not atlas.small_frame.visible,"Battle/story/menu must hide minimap")
    if errors.is_empty():
        print("PASS: fog-free minimap, full local terrain, no world atlas, retained objectives and modal closure")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        quit(1)
