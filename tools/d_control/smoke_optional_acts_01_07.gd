extends SceneTree
const Optional = preload("res://scripts/optional_director.gd")
const State = preload("res://scripts/first_act_state.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var director = Optional.new()
    director.bind(State.new())
    var counts: Dictionary = director.count()
    if int(counts.get("optional_scenes",0)) == 84 and int(counts.get("choice_reactions",0)) == 84:
        print("PASS: acts 1-7 optional scenes/reactions registered")
        quit(0)
    else:
        push_error("Registration mismatch " + str(counts))
        quit(1)
