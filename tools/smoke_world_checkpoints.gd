extends SceneTree
## Save migration smoke for indoor checkpoints and reusable daily wilderness camps.
const Game=preload("res://scripts/first_act.gd")
const State=preload("res://scripts/first_act_state.gd")
var failures: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool,reason: String) -> void:
    if not value:
        failures.append(reason)

func _run() -> void:
    var sandbox: String="user://qa_world_checkpoints_%d" % OS.get_process_id()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))!=OK:
        push_error("Cannot create isolated smoke save directory")
        quit(1)
        return
    var game=Game.new()
    root.add_child(game)
    game.progress.save_path=sandbox+"/state.json"
    game.progress.backup_path=sandbox+"/backup.json"
    game.ui.title_overlay.hide()
    game._start(false)
    var before: Vector2=game.world.hero.position
    game._interact("building:shop")
    check(game.world.interior_building=="shop","Town building not entered")
    var saved: Dictionary=game.progress.rpg.get("world",{})
    check(str(saved.get("indoor_building",""))=="shop","Indoor checkpoint not persisted")
    check(game.progress.save(),"Indoor save failed")
    check(game.progress.load_saved(),"Could not reload real indoor save from disk")
    game._enter_location()
    check(game.world.interior_building=="shop","Saved indoor location did not restore")
    game._interact("interior_exit")
    check(game.world.interior_building.is_empty(),"Indoor exit failed")
    check(game.world.hero.position==before,"Indoor exit did not restore street spawn")
    check(not game.progress.rpg.get("world",{}).has("indoor_building"),"Interior checkpoint wasn't cleared after exit")
    # A wilderness camp belongs to the ACTUAL road map (coast_03),
    # not the Chapter-3 destination map (coast_04 cave). The old smoke used
    # non-sequential chapter assignment as an accidental map teleport.
    # Travel on foot across adjacent gates, as the real player must do.
    # A new Godot game begins in the PROLOGUE (chapter 0). Advancing
    # straight from 0 to 2 is a non-sequential recovery spawn at the harbor,
    # not a chapter-1-to-2 on-foot continuation. Enter chapter 1 first.
    game.progress.chapter=1
    game.world_router.sync_chapter(1)
    check(game.world_router.current_map()=="map_coast_01",
        "Prologue-to-chapter-one transition did not keep the village")
    game.progress.chapter=2
    game.world_router.sync_chapter(2)
    check(game.world_router.current_map()=="map_coast_01",
        "Chapter-one-to-two continuation incorrectly teleported to harbor")
    if not game.world_router.can_travel("map_coast_02"):
        print("ACT01_ROUTE_DIAGNOSTIC chapter=",game.progress.chapter,
            " bound=",game.progress.rpg.get("world",{}).get("bound_chapter",-1),
            " current=",game.world_router.current_map(),
            " discovered=",game.progress.rpg.get("world",{}).get("discovered",[]),
            " unlock=",game.world_router.first_chapter.get("map_coast_02",-1),
            " neighbors=",game.world_router.current_info().get("neighbors",[]))
    check(game.world_router.travel("map_coast_02"),
        "Cannot walk from village to harbor before wilderness camp")
    game.progress.chapter=3
    game.world_router.sync_chapter(3)
    check(game.world_router.travel("map_coast_03"),
        "Chapter-3 saltwind road still inaccessible from harbor")
    game._enter_location()
    check(game.world_router.current_map()=="map_coast_03",
        "Wilderness camp checkpoint is not on the authored road")
    check(game.world.nodes.has("wild_camp"),"Wild country has no field rest site")
    var day: int=int(game.progress.rpg.get("game_clock",{}).get("day",0))
    game.progress.actors[0]["hp"]=25
    game.progress.actors[0]["mp"]=8
    var old_hp: int=int(game.progress.actors[0]["hp"])
    var old_mp: int=int(game.progress.actors[0]["mp"])
    game._interact("wild_camp")
    check(int(game.progress.actors[0]["hp"])>old_hp,"Field camp did not recover life")
    check(int(game.progress.actors[0]["mp"])>old_mp,"Field camp did not recover magic")
    check(game.world.encounter_meter<0.0,"Camp did not provide short enemy reprieve")
    check(int(game.progress.rpg.get("camp_last_day",{}).get("map_coast_03",-1))==day,"Daily camp did not mark rest date")
    var after: int=int(game.progress.actors[0]["hp"])
    game._interact("wild_camp")
    check(int(game.progress.actors[0]["hp"])==after,"Camp rest is exploitable multiple times per day")
    check(game.progress.save(),"Field camp data could not be saved")
    var reloaded=State.new()
    reloaded.save_path=game.progress.save_path
    reloaded.backup_path=game.progress.backup_path
    check(reloaded.load_saved(),"Field camp save could not be restored")
    check(int(reloaded.rpg.get("camp_last_day",{}).get("map_coast_03",-1))==day,"Daily camp data lost after reload")
    # Cleanup is unconditional, including failed assertions; never write to or
    # inspect the user's real first_act_v3.json save in a smoke test.
    for snapshot_path in [game.progress.save_path,game.progress.backup_path,
            game.progress.save_path+".tmp",game.progress.backup_path+".tmp"]:
        if FileAccess.file_exists(snapshot_path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(snapshot_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
    if failures.is_empty():
        print("PASS: saved indoor checkpoints, return spawn, persistent one-rest-per-day wilderness recovery and safe encounter grace")
        quit(0)
        return
    for error in failures:
        push_error(error)
    quit(1)
