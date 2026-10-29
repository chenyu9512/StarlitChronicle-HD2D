extends SceneTree
## Hard P0 gate: Godot --editor --quit does not always fail on dependency parse errors.
## Never call .new() on a script that cannot instantiate; report and exit instead.
const REQUIRED: Array[String] = [
    "res://scripts/combat_rules.gd",
    "res://scripts/battle_formation.gd",
    "res://scripts/encounter_registry.gd",
    "res://scripts/first_act_battle.gd",
    "res://scripts/first_act.gd"
]

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var failures: Array[String] = []
    for file_path in REQUIRED:
        var resource: Resource = load(file_path)
        if not resource is Script:
            failures.append("Not a loadable script: " + file_path)
            continue
        var source: Script = resource as Script
        if not source.can_instantiate():
            failures.append("Cannot instantiate compiled script: " + file_path)
    if failures.is_empty():
        print("PASS: all five combat/controller scripts compile and can instantiate")
        quit(0)
    else:
        for error in failures:
            push_error(error)
        quit(1)
