extends SceneTree
## Isolated real-V3 world-object transaction checks; no cheats or test save reuse.
## Queue in the next single Godot 4.7.2 batch, NOT per incremental commit.
const State = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Tx = preload("res://scripts/d_world_interaction/world_object_settlement.gd")
const Puzzles = preload("res://scripts/world_dungeon_puzzles.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)

func _run() -> void:
    var sandbox: String = "user://d_world_object_%d" % OS.get_process_id()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox)) != OK:
        push_error("Cannot create isolated world-object test directory")
        quit(1)
        return
    var state = State.new()
    state.save_path = sandbox + "/v3.json"
    state.backup_path = sandbox + "/v3.bak.json"
    var core = Core.new()
    core.bind(state)
    var first: Dictionary = state._pack().duplicate(true)
    var starting_gold: int = state.gold
    var starting_herbs: int = core.count("item_herb_01")
    var test_reward: Dictionary = {"gold":17,"item_id":"item_herb_01","amount":2}

    state.save_path = sandbox + "/missing/v3.json"
    var denied: Dictionary = Tx.claim(state,core,"discover.map_coast_01.test",test_reward)
    check(str(denied.get("reason",""))=="save_failed", "Discovery must reject failed V3 save")
    check(state._pack()==first, "Failed discovery changed flags, gold or inventory")
    state.save_path = sandbox + "/v3.json"
    var awarded: Dictionary = Tx.claim(state,core,"discover.map_coast_01.test",test_reward)
    check(bool(awarded.get("ok",false)) and bool(awarded.get("changed",false)), "Discovery did not save")
    check(state.gold==starting_gold+17 and core.count("item_herb_01")==starting_herbs+2, "Discovery payout missing")
    var repeated: Dictionary = Tx.claim(state,core,"discover.map_coast_01.test",test_reward)
    check(bool(repeated.get("repeated",false)) and state.gold==starting_gold+17, "Discovery paid twice")

    var before_invalid: Dictionary = state._pack().duplicate(true)
    var invalid: Dictionary = Tx.claim(state,core,"map.test.invalid",{"gold":1,"item_id":"item_does_not_exist","amount":1})
    check(str(invalid.get("reason",""))=="invalid_reward" and state._pack()==before_invalid,
        "Unknown item was allowed to pay")

    var reload = State.new()
    reload.save_path = state.save_path
    reload.backup_path = state.backup_path
    check(reload.load_saved(), "Saved discovery did not survive restart")
    var reload_core = Core.new()
    reload_core.bind(reload)
    var persisted: Dictionary = Tx.claim(reload,reload_core,"discover.map_coast_01.test",test_reward)
    check(bool(persisted.get("repeated",false)) and reload.gold==starting_gold+17,
        "Reloaded discovery granted twice")

    var puzzles = Puzzles.new()
    check(puzzles.issues.is_empty(), "Authored puzzle catalogue has errors")
    var info: Dictionary = puzzles.config("map_coast_04")
    var pattern: Array = info.get("pattern",[])
    check(not pattern.is_empty(), "Coast dungeon sequence not available")
    if not pattern.is_empty():
        var initial: Dictionary = reload._pack().duplicate(true)
        reload.save_path = sandbox + "/missing/puzzle.json"
        var failed_step: Dictionary = Tx.puzzle(reload,reload_core,puzzles,"map_coast_04",str(pattern[0]))
        check(str(failed_step.get("reason",""))=="save_failed" and reload._pack()==initial,
            "Failed device adjustment did not roll back")
        reload.save_path = sandbox + "/v3.json"
        for control in pattern:
            var step: Dictionary = Tx.puzzle(reload,reload_core,puzzles,"map_coast_04",str(control))
            check(bool(step.get("ok",false)) and bool(step.get("changed",false)),
                "Device sequence step did not persist")
        var before_reward: int = reload.gold
        reload.save_path = sandbox + "/missing/seal.json"
        var failed_seal: Dictionary = Tx.puzzle(reload,reload_core,puzzles,"map_coast_04","seal")
        check(str(failed_seal.get("reason",""))=="save_failed" and reload.gold==before_reward
            and not bool(Puzzles.snapshot(reload,"map_coast_04").get("claimed",false)),
            "Seal failure leaked reward or completion")
        reload.save_path = sandbox + "/v3.json"
        var seal: Dictionary = Tx.puzzle(reload,reload_core,puzzles,"map_coast_04","seal")
        check(bool(seal.get("ok",false)) and bool(seal.get("changed",false))
            and bool(Puzzles.snapshot(reload,"map_coast_04").get("claimed",false)),
            "Seal did not persist with its reward")
        var paid: int = reload.gold
        var seal_repeat: Dictionary = Tx.puzzle(reload,reload_core,puzzles,"map_coast_04","seal")
        check(bool(seal_repeat.get("ok",false)) and not bool(seal_repeat.get("changed",true))
            and reload.gold==paid, "Repeat seal paid twice")

    for path in [state.save_path,state.backup_path,state.save_path+".tmp",
            state.backup_path+".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
    if failures.is_empty():
        print("PASS: V3 discovery and puzzle reward atomicity, invalid item, failed save, restart and idempotency")
        quit(0)
    else:
        for message in failures:
            push_error(message)
        quit(1)
