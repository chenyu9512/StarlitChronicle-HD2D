extends SceneTree
const State = preload("res://scripts/first_act_state.gd")
const Puzzles = preload("res://scripts/world_dungeon_puzzles.gd")
const Mechanics = preload("res://scripts/mechanics/Act01Mechanics.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var state = State.new()
    var puzzles = Puzzles.new()
    var ok: bool = not puzzles.config("map_coast_04").is_empty()
    for key in ["b","a","c"]:
        puzzles.interact("map_coast_04",key,state)
    ok = ok and int(Puzzles.snapshot(state,"map_coast_04").get("index",0)) == 3
    var opened: Dictionary = puzzles.interact("map_coast_04","seal",state)
    ok = ok and bool(opened.get("completed",false))
    var mech = Mechanics.new()
    mech.operate_sea_cave_mechanism(1)
    mech.operate_sea_cave_mechanism(2,true)
    mech.operate_sea_cave_mechanism(3)
    mech.on_boss_ch003_pre_attack_telegraph()
    var pacified: Dictionary = mech.execute_boss_ch003_tactical_action("SHOW_CROOKED_TREE_BADGE",true)
    ok = ok and bool(pacified.get("success",false))
    ok = ok and not bool(mech.execute_boss_ch003_tactical_action("SHOW_CROOKED_TREE_BADGE",true).get("success",false))
    mech.free()
    var beast = Mechanics.new()
    beast.trigger_fisherman_red_flag_warning()
    for n in range(3):
        beast.trigger_shuoxian_double_whistle()
        var step: Dictionary = beast.attempt_dismantle_star_lock(false)
        ok = ok and bool(step.get("success",false))
    ok = ok and beast.boss_ch005_is_complete
    ok = ok and not bool(beast.attempt_dismantle_star_lock(false).get("success",false))
    beast.free()
    if ok:
        print("PASS: cave physical order and nonlethal mechanic state (headless)")
        quit(0)
    else:
        push_error("Act01 mechanism regression failed")
        quit(1)
