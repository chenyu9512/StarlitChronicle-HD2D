extends SceneTree
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var s = State.new()
    s.chapter = 49
    s.flags["story.ch048.done"] = true
    s.actors.append({"id":"cast_nuo_yi","name":"诺依","level":49,"hp":100,"max_hp":100})
    var core = RPG.new()
    core.bind(s)
    var ok: bool = core.active_party_ids() == ["cast_nuo_yi"]
    ok = ok and not core.is_active("char_wayfarer")
    s.chapter = 52
    ok = ok and core.is_active("cast_nuo_yi")
    if ok:
        print("PASS: adult Noe era control")
        quit(0)
    else:
        push_error("Noe era transition failed")
        quit(1)
