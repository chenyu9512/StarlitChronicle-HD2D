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
    var game=Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    var before: Vector2=game.world.hero.position
    game._interact("building:shop")
    check(game.world.interior_building=="shop","Town building not entered")
    var saved: Dictionary=game.progress.rpg.get("world",{})
    check(str(saved.get("indoor_building",""))=="shop","Indoor checkpoint not persisted")
    check(game.progress.save(),"Indoor save failed")
    game._enter_location()
    check(game.world.interior_building=="shop","Saved indoor location did not restore")
    game._interact("interior_exit")
    check(game.world.interior_building.is_empty(),"Indoor exit failed")
    check(game.world.hero.position==before,"Indoor exit did not restore street spawn")
    check(not game.progress.rpg.get("world",{}).has("indoor_building"),"Interior checkpoint wasn't cleared after exit")
    game.progress.chapter=3
    game.world_router.sync_chapter(3)
    game._enter_location()
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
    check(reloaded.load_saved(),"Field camp save could not be restored")
    check(int(reloaded.rpg.get("camp_last_day",{}).get("map_coast_03",-1))==day,"Daily camp data lost after reload")
    if failures.is_empty():
        print("PASS: saved indoor checkpoints, return spawn, persistent one-rest-per-day wilderness recovery and safe encounter grace")
        quit(0)
    for error in failures:
        push_error(error)
    quit(1)
