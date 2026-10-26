extends SceneTree
## User-facing map policy: fully uncovered local chart and compact minimap only.
## No new fog persistence or world/regional atlas access through the HUD.
const State = preload("res://scripts/first_act_state.gd")
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
const MapUI = preload("res://scripts/map_hud.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func require(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)

func _run() -> void:
    var state=State.new()
    state.new_game()
    var router=Registry.new()
    router.bind(state)
    var world=World.new()
    world.map_profile=router.profile()
    root.add_child(world)
    world.build(1,2)
    var atlas=MapUI.new()
    root.add_child(atlas)
    atlas.bind_world(world,router)
    atlas.set_targets("key_npc","side_start")
    atlas.show_exploration(true)
    require(atlas.small_frame.visible,"Exploration minimap disappeared")
    require(atlas.small_view.mode=="local","Minimap must remain local")
    require(not world.has_method("_reveal_nearby"),"Old tile-by-tile reveal method still exists")
    require(not state.rpg.get("world",{}).has("fog"),"New game unexpectedly created fog data")
    atlas.open_map()
    require(atlas.is_open() and atlas.full_view.mode=="local",
        "Expanded map must show current terrain")
    var info: Dictionary=atlas.full_view.local_frame()
    require(int(info.get("width",0))==world.WIDTH and int(info.get("height",0))==world.HEIGHT,
        "Expanded map must reflect full authored terrain")
    atlas.full_view.display_mode("world")
    require(atlas.full_view.mode=="local","Global world map still reachable")
    atlas._set_mode("region")
    require(atlas.full_view.mode=="local","Regional overview still reachable")
    atlas.full_view.zoom_local(2.0)
    require(atlas.full_view.local_zoom>1.0,"Local zoom was disabled")
    atlas.full_view.reset_local_view()
    atlas.close_map()
    require(atlas.small_frame.visible,"Minimap not restored after closing enlarged map")
    var saved: Dictionary=state._pack()
    require(not state.rpg.get("world",{}).has("fog"),
        "Map viewing inserted fog or changed save state")
    var restored=State.new()
    require(restored.restore_snapshot(saved),"No-fog save failed to restore")
    require(not restored.rpg.get("world",{}).has("fog"),
        "No-fog restore unexpectedly adds exploration mask")
    if failures.is_empty():
        print("PASS maps: exposed terrain on current-area+minimap, no fog writes, no global atlas, save compatible")
        quit(0)
    else:
        for issue in failures:
            push_error(issue)
        quit(1)
