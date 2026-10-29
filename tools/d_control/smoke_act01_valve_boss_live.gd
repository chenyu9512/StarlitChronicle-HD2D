extends SceneTree
const State = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const Puzzles = preload("res://scripts/world_dungeon_puzzles.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var state = State.new()
    state.chapter = 3
    state.flags["ch003.evidence"] = true
    var cave = Puzzles.new()
    for valve in ["b","a","c"]:
        cave.interact("map_coast_04",valve,state)
    var core = Core.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.invincible = true
    battle.encounter_data = {"cave_snapshot":Puzzles.snapshot(state,"map_coast_04")}
    var outcome: Dictionary = {"count":0,"won":false}
    battle.completed.connect(func(won: bool, _xp: int, _gold: int) -> void:
        outcome["count"] = int(outcome["count"])+1
        outcome["won"] = won
    )
    battle.start(state,3,true)
    battle._act("special")
    var ok: bool = bool(outcome["won"]) and int(outcome["count"]) == 1
    ok = ok and bool(battle.act01_mechanics.boss_ch003_is_pacified)
    ok = ok and str(battle.last_boss_settlement) == "nonlethal"
    battle._act("special")
    ok = ok and int(outcome["count"]) == 1
    battle.free()
    if ok:
        print("PASS: ch003 real saved valves to one pacification battle result")
        quit(0)
    else:
        push_error("Ch003 live cave-to-combat route failed")
        quit(1)
