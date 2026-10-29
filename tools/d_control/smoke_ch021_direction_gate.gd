extends SceneTree
## Engine-only V3 gate regression. It is NOT a visual/player-path acceptance.
const Registry = preload("res://scripts/systems/MechanicsRegistry.gd")
const State = preload("res://scripts/first_act_state.gd")
const Transition = preload("res://scripts/d_world_interaction/v3_progress_transition.gd")
const Catalog = preload("res://scripts/story_catalog.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, label: String) -> void:
    if not condition:
        errors.append(label)

func _run() -> void:
    var registry = Registry.new()
    check(registry.load_all(), "registry load: " + "; ".join(registry.errors))
    # ch015 is now an explicitly active, chapter-owned eight-trial controller.
    # Do not mistake the new active mechanism for an unsafe pending shortcut.
    var ch015: Node = registry.create_controller("ch015")
    check(str(registry.binding_for("ch015").get("status", "")) == "active", "ch015 must have an explicit active binding")
    check(ch015 != null, "active ch015 safety-trial controller did not instantiate")
    if ch015 != null:
        ch015.free()
    # An unregistered chapter must still fail closed.
    check(registry.create_controller("ch014") == null, "unregistered chapter instantiated an unauthorized controller")
    var director: Node = registry.create_controller("ch021")
    check(director != null, "active chapter controller missing")
    var catalog = Catalog.new()
    check(catalog.load_all(), "canonical story catalog failed to load")
    var scene: Dictionary = catalog.get_scene("ch021", "ch021.crisis")
    if director != null:
        var cue: Dictionary = director.build_cue(scene)
        check(not cue.is_empty() and not bool(cue.get("can_skip", true)), "ch021 cue must be non-skippable")
        check(str(cue.get("location", "")).contains("现世营火"), "campfire location is missing")
        check((cue.get("lines", []) as Array).size() == 4, "direction sequence must have four beats")
    var sandbox: String = "user://ch021_gate_%d" % OS.get_process_id()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
    var state = State.new()
    state.save_path = sandbox + "/v3.json"
    state.backup_path = sandbox + "/v3.backup.json"
    state.chapter = 21
    state.scene_index = 2
    check(state.save(), "baseline V3 save failed")
    if director != null:
        check(not director.choice_is_unlocked(state), "choice opened before transition")
    var checkpoint: Dictionary = Transition.commit(state, func() -> Dictionary:
        state.rpg["cinematic_checkpoint"] = "direction.ch021.crisis"
        return {"ok":true}
    )
    check(bool(checkpoint.get("ok", false)), "checkpoint did not persist")
    var previous: Dictionary = state._pack().duplicate(true)
    state.save_path = sandbox + "/missing/v3.json"
    var failed: Dictionary = Transition.commit(state, func() -> Dictionary:
        state.flags["ch021.campfire_returned"] = true
        state.rpg["direction_ch021_era"] = "present_campfire"
        state.rpg.erase("cinematic_checkpoint")
        return {"ok":true}
    )
    check(not bool(failed.get("ok", false)) and state._pack() == previous, "failed transition leaked state")
    state.save_path = sandbox + "/v3.json"
    var finished: Dictionary = Transition.commit(state, func() -> Dictionary:
        state.flags["ch021.campfire_returned"] = true
        state.rpg["direction_ch021_era"] = "present_campfire"
        state.rpg.erase("cinematic_checkpoint")
        return {"ok":true}
    )
    check(bool(finished.get("ok", false)), "transition did not persist")
    var restarted = State.new()
    restarted.save_path = state.save_path
    restarted.backup_path = state.backup_path
    check(restarted.load_saved(), "V3 load after transition failed")
    if director != null:
        check(director.choice_is_unlocked(restarted), "campfire choice not unlocked after restart")
    check(not restarted.rpg.has("cinematic_checkpoint"), "checkpoint still pending")
    # An already saved choice must still be present after another process load.
    var chosen: Dictionary = Transition.commit(restarted, func() -> Dictionary:
        restarted.flags["ch021.choice.chosen"] = true
        restarted.flags["ch021.approach"] = "read_together"
        return {"ok":true}
    )
    check(bool(chosen.get("ok", false)), "canonical choice did not persist")
    var choice_resume = State.new()
    choice_resume.save_path = restarted.save_path
    choice_resume.backup_path = restarted.backup_path
    check(choice_resume.load_saved(), "saved choice cannot reload")
    check(bool(choice_resume.flags.get("ch021.choice.chosen", false)), "choice receipt lost after restart")
    check(str(choice_resume.flags.get("ch021.approach", "")) == "read_together", "canonical choice branch changed")
    if director != null:
        director.free()
    if errors.is_empty():
        print("PASS: ch021 registry/sequence/V3 transition gate (headless, not visual)")
        quit(0)
    else:
        for issue in errors:
            push_error(issue)
        quit(1)
