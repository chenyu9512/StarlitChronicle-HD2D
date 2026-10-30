extends SceneTree
## Act-I chapters 5/6: live Boss presentation and source-of-truth objectives.
## Uses existing battle scene, HUD and registered assets; no counterfeit textures.
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
const Registry = preload("res://scripts/encounter_registry.gd")

var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var registry = Registry.new()
    for chapter_no in [5,6]:
        var id: String = "boss.ch%03d" % chapter_no
        var spec: Dictionary = registry.boss_profile(id)
        _check(not spec.is_empty(), "Missing canonical Boss profile " + id)
        _check(str(spec.get("goal","")) == "legacy", "Bespoke Boss was incorrectly promoted to generic mechanics: " + id)
        _check(str(spec.get("settlement","")) == "legacy_story", "Bespoke victory handler unexpectedly changed: " + id)
        var goal: String = str(spec.get("objective_label",""))
        var hint: String = str(spec.get("counter_hint",""))
        _check(goal.length() > 7 and hint.length() > 15, "Missing helpful player-facing goal/hint: " + id)
        _check(not goal.contains("击败") and not goal.contains("取胜"), "Misleading kill objective: " + id)
        _check(not hint.contains("直接攻击"), "Misleading resource instruction: " + id)

        var state = State.new()
        state.chapter = chapter_no
        if chapter_no == 5:
            state.recruit_sailor()
        var core = RPG.new()
        core.bind(state)
        var battle = Battle.new()
        root.add_child(battle)
        battle.game_core = core
        battle.start(state,chapter_no,true)
        _check(not battle.boss_mechanics.enabled(), "Chapter %d accidentally enabled a second generic win route" % chapter_no)
        _check(battle._show_boss_objective(), "Chapter %d objective visibility gate is closed" % chapter_no)
        _check(battle.report.text.contains("目标：" + goal), "Chapter %d combat introduction has no canonical goal" % chapter_no)
        _check(battle.report.text.contains(hint), "Chapter %d combat introduction has no real command hint" % chapter_no)
        _check(battle.foe_info.text.contains("目标：" + goal), "Chapter %d HUD lost the dynamic goal" % chapter_no)
        _check(is_instance_valid(battle.special_button), "Chapter %d lost the dedicated command button" % chapter_no)
        if is_instance_valid(battle.special_button):
            if chapter_no == 5:
                _check(battle.special_button.text.contains("双哨"), "Chapter five no longer teaches the whistle first")
                _check(battle.foe_info.text.contains("星锁"), "Chapter five lost the actual star-lock counter")
            else:
                _check(battle.special_button.text.contains("见证"), "Chapter six no longer teaches shared testimony")
                _check(battle.foe_info.text.contains("共鸣"), "Chapter six lost the actual resonance counter")
        battle.queue_free()

    if failures.is_empty():
        print("PASS Act I Boss goals: real chapter-five star locks and chapter-six testimony show in battle and HUD; no duplicate win path")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
