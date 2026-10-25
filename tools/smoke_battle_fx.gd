extends SceneTree
## Headless regression: four-frame sprite atlas, battle VFX lifecycle, live battle hookup.
const BattleFX = preload("res://scripts/battle_fx.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")

var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_check")

func _expect(condition: bool, reason: String) -> void:
    if not condition:
        errors.append(reason)

func _check() -> void:
    var viewport := Control.new()
    viewport.size = Vector2(1152,648)
    root.add_child(viewport)
    var enemy := TextureRect.new()
    enemy.size = Vector2(220,220)
    viewport.add_child(enemy)
    var fx = BattleFX.new()
    fx.size = Vector2(1152,648)
    viewport.add_child(fx)
    fx.bind_enemy(enemy,"salt_slime",false)
    _expect(enemy.texture is AtlasTexture,"Coast monster idle animation was not bound")
    fx._process(0.27)
    if enemy.texture is AtlasTexture:
        var sheet: AtlasTexture = enemy.texture
        _expect(int(sheet.region.position.x) == 128,"Idle animation did not advance to frame 2")
    var p := Vector2(520,210)
    fx.play_attack(p,24)
    fx.play_spell(Vector2(250,430),p,"火",28)
    fx.play_heal(Vector2(250,430))
    fx.play_guard(Vector2(250,430))
    fx.play_charge(Vector2(250,430))
    fx.play_special(p,30)
    fx.play_status(p,8)
    fx.play_enemy_attack(p,Vector2(250,430),11)
    fx.play_phase(p)
    fx.play_victory(p)
    _expect(fx.effects.size() >= 10,"Visual effects did not enqueue")
    for i in range(15):
        fx._process(0.1)
    _expect(fx.effects.is_empty(),"Transient VFX were not reclaimed")
    fx.reduced_motion = true
    fx.play_guard(p)
    _expect(fx.effects.is_empty(),"Reduced motion should avoid extra transient graphics")
    viewport.queue_free()

    var state = State.new()
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.invincible = true
    battle.start(state,2,false)
    _expect(is_instance_valid(battle.vfx),"Active battle scene did not construct a VFX layer")
    _expect(is_instance_valid(battle.portrait),"Active battle has no portrait to animate")
    _expect(battle.portrait.texture is Texture2D,"Battle sprite failed to load")
    battle._act("guard")
    if is_instance_valid(battle.vfx):
        _expect(not battle.vfx.effects.is_empty(),"Guard action did not trigger presentation FX")
    battle.queue_free()
    if not errors.is_empty():
        for error in errors:
            push_error(error)
        quit(1)
        return
    print("PASS: animated coastal sprites, VFX events, lifetime cleanup, reduced motion, active battle wiring")
    quit(0)
