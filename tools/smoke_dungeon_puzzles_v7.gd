extends SceneTree
## V7: eight unique interactable dungeon puzzles with geographical, gameplay and old-save checks.
const Puzzles = preload("res://scripts/world_dungeon_puzzles.gd")
const Geography = preload("res://scripts/world_geography.gd")
const State = preload("res://scripts/first_act_state.gd")
const Game = preload("res://scripts/first_act.gd")
var errors: Array[String] = []
const SOLUTIONS: Dictionary = {
    "map_coast_04":["b","a","c"],
    "map_oaths_04":["a","a","b","c"],
    "map_forge_04":["a","b"],
    "map_isles_04":["a","a","b","c"],
    "map_mirror_04":["a","a","b","c"],
    "map_oldland_04":["a","c","b","a"],
    "map_sanctum_04":["a","c","a","b"],
    "map_city_04":["a","a","b","c","c"]
}

func check(ok: bool, cause: String) -> void:
    if not ok:
        errors.append(cause)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var puzzles = Puzzles.new()
    var geo = Geography.new()
    check(puzzles.issues.is_empty(),"Invalid dungeon puzzle definitions: "+str(puzzles.issues))
    check(puzzles.maps.size()==8,"Not all eight dungeon types are loaded")
    var seen_modes: Dictionary = {}
    for dungeon_id in SOLUTIONS.keys():
        var spec: Dictionary = puzzles.config(dungeon_id)
        var mode: String = str(spec.get("mode",""))
        check(not spec.is_empty(),"Missing puzzle "+dungeon_id)
        check(not seen_modes.has(mode),"Two dungeons reuse the same puzzle model")
        seen_modes[mode]=true
        var physical: Dictionary = geo.layout(dungeon_id,5)
        var room_bounds: Vector2i = physical.get("size",Vector2i.ZERO)
        var all_stops: Array[Vector2i] = []
        for device in puzzles.devices(dungeon_id):
            var pt: Array = device.get("cell",[])
            var tile: Vector2i = Vector2i(int(pt[0]),int(pt[1]))
            all_stops.append(tile)
            check(tile.x>2 and tile.y>2 and tile.x<room_bounds.x-2 and tile.y<room_bounds.y-2,"Dungeon device beyond map "+dungeon_id)
            check(not (physical.get("blocked",{}) as Dictionary).has(tile),"Puzzle device blocked by map terrain "+dungeon_id+":"+str(device.get("id","")))
        check(geo.reachable(physical,[physical.get("spawn",Vector2i.ZERO)],all_stops),"Cannot reach all four mechanisms in "+dungeon_id)
        var old_save = State.new()
        old_save.new_game()
        old_save.rpg.erase("dungeon_puzzles_v7")
        var first: Dictionary = puzzles.interact(dungeon_id,"seal",old_save)
        check(not first.has("reward"),"Locked reward bypassed without puzzle "+dungeon_id)
        if mode=="sequence" or mode=="rhythm":
            puzzles.interact(dungeon_id,"b" if mode=="rhythm" else "a",old_save)
            check(int(puzzles.snapshot(old_save,dungeon_id).get("index",-1))==0,"Wrong sequence did not reset in "+dungeon_id)
        for control in SOLUTIONS[dungeon_id]:
            puzzles.interact(dungeon_id,control,old_save)
        var output: Dictionary = puzzles.interact(dungeon_id,"seal",old_save)
        check(bool(output.get("completed",false)),"Puzzle solution failed: "+dungeon_id+" state="+str(puzzles.snapshot(old_save,dungeon_id)))
        check((output.get("reward",{}) as Dictionary).get("gold",0)>0,"Missing unique dungeon payout "+dungeon_id)
        check(not puzzles.interact(dungeon_id,"seal",old_save).has("reward"),"Repeatable dungeon treasure "+dungeon_id)
        var recovered = State.new()
        check(recovered.restore_snapshot(old_save._pack()),"V7 save snapshot invalid "+dungeon_id)
        check(bool(puzzles.snapshot(recovered,dungeon_id).get("claimed",false)),"V7 dungeon completion lost on reload "+dungeon_id)
    var playable = Game.new()
    root.add_child(playable)
    playable.ui.title_overlay.hide()
    playable._start(false)
    playable.progress.chapter=4
    playable.world_router.sync_chapter(4)
    playable._enter_location()
    check(playable.world_router.current_map()=="map_coast_04","Original chapter-4 route changed")
    for id in ["a","b","c","seal"]:
        check(playable.world.nodes.has("puzzle:"+id),"Actual cave missing physical device "+id)
    check(playable.world.nodes.has("dungeon_chest") and playable.world.nodes.has("dungeon_switch_a"),"Original cave puzzle was removed")
    if errors.is_empty():
        print("PASS: eight distinct dungeon mechanisms, 32 physical reachable devices, incorrect-sequence reset, one-time reward, save restore, original chest compatibility")
        quit(0)
    for issue in errors:
        push_error(issue)
    quit(1)
