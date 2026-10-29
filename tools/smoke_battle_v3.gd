extends SceneTree
## V3 battle presentation regression. Combat states and visuals are tested separately.
const Stage = preload("res://scripts/battle_enemies.gd")
const Director = preload("res://scripts/battle_timeline.gd")
const Camera = preload("res://scripts/battle_camera.gd")
const FX = preload("res://scripts/battle_fx.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, description: String) -> void:
    if not ok:
        failures.append(description)

func _run() -> void:
    var viewport := Control.new()
    viewport.size = Vector2(1152,648)
    root.add_child(viewport)
    var stage = Stage.new()
    stage.size = viewport.size
    viewport.add_child(stage)
    var foes: Array = [
        {"name":"泥团","art":"salt_slime","hp":45,"max_hp":45},
        {"name":"雾蟹","art":"fog_crab","hp":60,"max_hp":60},
        {"name":"狼","art":"salt_wolf","hp":50,"max_hp":50}
    ]
    stage.configure(foes,3,false)
    verify(stage.slots.size() == 3,"Cannot stage three independent foes")
    verify(stage.point(0).distance_to(stage.point(1)) > 60.0,"Enemies overlap on stage")
    stage.focus(2)
    verify(stage.active_index == 2,"Focus was not changed")
    stage.attack(2)
    verify(float(stage.slots[2].get("attack",0.0)) > 0.0,"Enemy attack windup missing")
    stage._process(0.08)
    var attacker_sprite: TextureRect = stage.slots[2]["node"]
    verify(attacker_sprite.position.x < Vector2(stage.slots[2]["base"]).x,"Attacking foe did not lunge")
    stage.hit(1,true)
    for i in range(7):
        stage._process(0.1)
    verify(bool(stage.slots[1].get("dead",false)),"Fallen enemy did not fade out")
    verify(not bool(stage.slots[0].get("dead",false)),"Unrelated foe disappeared")
    stage.reduced_motion = true
    stage._process(0.1)

    var background := Control.new()
    viewport.add_child(background)
    var camera = Camera.new()
    viewport.add_child(camera)
    camera.bind_targets([background])
    camera.impulse(7.0)
    camera._process(0.08)
    verify(background.position != Vector2.ZERO,"Scenery camera impulse did not move target")
    for i in range(4):
        camera._process(0.1)
    verify(background.position.distance_to(Vector2.ZERO) < 0.01,"Camera failed to restore scenery")
    camera.reduced_motion = true
    camera.impulse(8.0)
    verify(camera.shake_time <= 0.0,"Reduced motion should disable shaking")

    var fx = FX.new()
    fx.size = viewport.size
    viewport.add_child(fx)
    var timeline = Director.new()
    viewport.add_child(timeline)
    timeline.bind_layers(fx,null,camera)
    timeline.queue_actor("skill",Vector2(180,350),Vector2(700,210),28,
        {"element":"雷","tier":3,"job_id":"vanguard"},false)
    verify(timeline.pending.size() == 1,"Skill impact not queued on presentation timeline")
    timeline._process(0.1)
    verify(timeline.pending.size() == 1,"Skill impact fired before cast windup")
    timeline._process(0.1)
    verify(timeline.pending.is_empty(),"Timeline did not dispatch impact")
    verify(fx._visual_hit_stop > 0.0,"Impact did not create visual-only hit stop")
    timeline.queue_enemy(Vector2(700,220),Vector2(250,390),13)
    timeline._process(0.1)
    timeline._process(0.1)
    verify(timeline.pending.is_empty(),"Enemy impact cue was not dispatched")
    fx.play_warning(Vector2(710,230),"蓄力重击")
    verify(fx.effects.any(func(e: Dictionary) -> bool: return str(e.get("kind","")) == "warning"),"Boss warning missing")
    viewport.queue_free()

    var state = State.new()
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.invincible = true
    battle.start(state,4,false)
    verify(is_instance_valid(battle.timeline),"Battle did not bind a visual timeline")
    verify(is_instance_valid(battle.camera_motion),"Battle did not bind camera")
    verify(is_instance_valid(battle.enemy_stage),"Battle did not construct enemy slots")
    if battle.formation.units.size() < 2:
        var extra: Dictionary = battle.formation.units[0].duplicate(true)
        extra["name"] = "额外测试敌人"
        battle.formation.units.append(extra)
        battle.enemy_stage.configure(battle.formation.units,4,false)
        battle.enemy_stage.visible = true
        battle.portrait.visible = false
    var hp_before: int = int(battle.formation.units[1].get("hp",0))
    battle._act("attack#1")
    verify(battle.active_target == 1,"Manual target selection did not focus second foe")
    verify(int(battle.formation.units[1].get("hp",0)) < hp_before,"Attack failed to damage chosen foe")
    verify(battle.enemy_stage.active_index == 1,"Enemy animation focus did not follow selected foe")
    battle.queue_free()

    var boss_battle = Battle.new()
    root.add_child(boss_battle)
    boss_battle.game_core = core
    boss_battle.invincible = true
    boss_battle.start(state,5,true)
    boss_battle.current_round = 3
    # Set up this round's real, frozen intent before asserting its warning.
    # Changing current_round alone leaves round_boss_intent at the opening beat.
    boss_battle._begin_round()
    boss_battle.turn_queue.clear()
    boss_battle.turn_queue.append({"team":"ally","index":0})
    boss_battle.turn_queue.append({"team":"enemy","index":0})
    boss_battle.turn_cursor = 0
    boss_battle.last_warning_round = 0
    boss_battle._telegraph_next_boss_action()
    verify(boss_battle.last_warning_round == 3,"Boss special attack was not telegraphed")
    var count: int = boss_battle.vfx.effects.size()
    boss_battle._telegraph_next_boss_action()
    verify(boss_battle.vfx.effects.size() == count,"Boss warning repeated during a single round")
    boss_battle.queue_free()

    if not failures.is_empty():
        for failure in failures:
            push_error(failure)
        quit(1)
        return
    print("PASS V3: distinct enemies, target damage, warnings, timed hits, camera recovery, reduced motion")
    quit(0)
