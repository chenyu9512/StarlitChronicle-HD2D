extends SceneTree
## First-act special Boss phase pacing: real Battle turns, no duplicate stage,
## enemy pressure and visible recovery choices. Standalone phase test data is
## synthetic; the canonical six-chapter normal smoke proves actual story gates.
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")

var failures: Array[String] = []

func verify(ok: bool, why: String) -> void:
    if not ok:
        failures.append(why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for chapter_no in [5,6]:
        var progress = State.new()
        progress.chapter = chapter_no
        progress.give_rewards(580,0) # controlled normal-level test fixture
        progress.recruit_sailor()
        var core = RPG.new()
        core.bind(progress)
        var battle = Battle.new()
        root.add_child(battle)
        battle.game_core = core
        if chapter_no == 6:
            battle.encounter_data = {
                "lighthouse_fragments":{"breakwater_wick":true,
                    "keeper_wick":true,"summit_wick":true},
                "lighthouse_testimonies":[
                    {"id":"w1","name":"渔夫","line":"归航的灯仍在。"},
                    {"id":"w2","name":"工匠","line":"共同修复而非牺牲。"},
                    {"id":"w3","name":"水手","line":"我们一起守住方向。"},
                    {"id":"w4","name":"守灯人","line":"让所有人拥有归路。"}]
            }
        battle.start(progress,chapter_no,true)
        verify(not battle.invincible,"Phase test used invincibility in %d" % chapter_no)
        var actions: int = 0
        var locked_checks: int = 0
        var strikes: int = 0
        while not battle.win_locked and actions < 80:
            var was_round: int = battle.current_round
            var on_cooldown: bool = battle.story_progress_round == was_round
            if on_cooldown:
                var step_before: int = (battle.act01_mechanics.beast_star_locks_remaining
                    if chapter_no == 5 else battle.resonance)
                battle._act("special") # direct API cannot bypass disabled UI
                var step_after: int = (battle.act01_mechanics.beast_star_locks_remaining
                    if chapter_no == 5 else battle.resonance)
                verify(step_before==step_after and battle.current_round==was_round,
                    "Chapter %d repeated the story step in one round" % chapter_no)
                verify(battle.special_button.disabled,
                    "Chapter %d did not disable completed phase command" % chapter_no)
                verify(battle.foe_info.text.contains("本回合关键阶段已完成"),
                    "Chapter %d does not explain phase cooldown" % chapter_no)
                locked_checks += 1
                battle._act("guard")
            else:
                battle._act("special")
            actions += 1
            strikes = battle.enemy_strike_count
        var min_rounds: int = 6 if chapter_no == 5 else 4
        verify(battle.win_locked and battle.current_round >= min_rounds,
            "Chapter %d ended without four/six real phase rounds" % chapter_no)
        verify(locked_checks >= 2 and strikes >= 2,
            "Chapter %d missed defensive decisions or real Boss attacks" % chapter_no)
        verify(battle.last_boss_settlement == ("nonlethal" if chapter_no==5 else "testimony"),
            "Chapter %d lost the authored humane victory outcome" % chapter_no)
        verify(not battle.boss_mechanics.enabled(),
            "Chapter %d created an alternative generic Boss win route" % chapter_no)
        print("ACT01_BOSS_PHASE " + JSON.stringify({"chapter":chapter_no,
            "rounds":battle.current_round,"actions":actions,
            "enemy_strikes":strikes,"defensive_choices":locked_checks,
            "resolution":battle.last_boss_settlement}))
        # A standalone SceneTree smoke quits immediately after assertions.
        # Free the entire battle subtree synchronously; queue_free() needs
        # more idle frames and leaves ObjectDB nodes alive at process exit.
        battle.free()
        battle = null
        core = null
        progress = null
    # Release every _run() local before the SceneTree shutdown path. A direct
    # quit() here retains the script call stack (and its RefCounted resources)
    # while the engine counts outstanding objects at process exit.
    call_deferred("_finish_test")

func _finish_test() -> void:
    # Allow renderer/audio servers and any pending child callbacks to drain
    # after _run has returned; do not bypass the real combat/VFX assertions.
    for frame in range(3):
        await process_frame
    if failures.is_empty():
        print("PASS Act-I phase pacing: humane rescue/testimony require separate rounds and defensible Boss pressure")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
