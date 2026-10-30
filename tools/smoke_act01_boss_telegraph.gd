extends SceneTree
## Act-I real Boss warning regression: actionable heavy windups, no false charge
## cues on routine turns, preserved combat mitigation and no extra win routes.
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
const Combat = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var rules = Combat.new()
    rules.start({"difficulty":"标准"})
    var normal_hit: int = rules.mitigated_damage(100,"hero",false)
    var guarded_hit: int = rules.mitigated_damage(100,"hero",true)
    check(guarded_hit < normal_hit and guarded_hit <= roundi(float(normal_hit)*0.36),
        "Defend command did not actually mitigate a threatening Boss strike")

    for chapter_no in range(2,7):
        var state = State.new()
        state.chapter = chapter_no
        if chapter_no >= 4:
            state.recruit_sailor()
        var core = RPG.new()
        core.bind(state)
        var battle = Battle.new()
        root.add_child(battle)
        battle.game_core = core
        battle.start(state,chapter_no,true)
        check(battle.boss, "Story Boss not created for chapter %d" % chapter_no)
        # Each first-act Boss has a quiet opening round, and a meaningful
        # heavy turn based on its actual data-driven cadence (or chapter script).
        battle.current_round = 1
        battle._begin_round()
        battle.turn_queue.clear()
        battle.turn_queue.append({"team":"ally","index":0})
        battle.turn_queue.append({"team":"enemy","index":0})
        battle.turn_cursor = 0
        battle.last_warning_round = 0
        battle._telegraph_next_boss_action()
        check(battle.last_warning_text.is_empty(),
            "Chapter %d raises a false heavy warning for routine opening action" % chapter_no)

        var heavy_round: int = maxi(2,int(battle.boss_mechanics.spec.get("cadence",3))) if battle.boss_mechanics.enabled() else 3
        battle.current_round = heavy_round
        battle._begin_round()
        battle.turn_queue.clear()
        battle.turn_queue.append({"team":"ally","index":0})
        battle.turn_queue.append({"team":"enemy","index":0})
        battle.turn_cursor = 0
        battle.last_warning_round = 0
        battle._telegraph_next_boss_action()
        var warning: String = battle.last_warning_text
        check(not warning.is_empty() and warning.contains("防御可减伤"),
            "Chapter %d real strong action has no useful guard telegraph" % chapter_no)
        check(warning.contains("倾向") or warning.contains("目标不定"),
            "Chapter %d strong action omitted its targeting tendency" % chapter_no)
        check(battle.battle_hud.warning == warning,
            "Chapter %d in-game combat HUD and warning have diverged" % chapter_no)
        var count: int = battle.vfx.effects.size()
        battle._telegraph_next_boss_action()
        check(battle.vfx.effects.size() == count,
            "Chapter %d duplicated charge warning in one turn" % chapter_no)
        if chapter_no in [5,6]:
            check(not battle.boss_mechanics.enabled(),
                "Bespoke star-lock/testimony Boss gained a generic victory route")
        battle.queue_free()

    if failures.is_empty():
        print("PASS Act-I warnings: five Bosses reserve charge cues for heavy attacks, show target tendency and guard feedback, no duplicate warning")
        quit(0)
    else:
        for problem in failures:
            push_error(problem)
        quit(1)
