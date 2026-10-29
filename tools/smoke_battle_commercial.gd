extends SceneTree
## One-pass consolidated battle art acceptance: 63 skills / five bosses / UI / choreography.
## Live combat math remains protected by smoke_combat_turns and smoke_first_act_flow.
const ArtDirection = preload("res://scripts/battle_art_direction.gd")
const BattleHud = preload("res://scripts/battle_hud.gd")
const BattleFX = preload("res://scripts/battle_fx.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")

var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_validate")

func check(condition: bool, reason: String) -> void:
    if not condition:
        errors.append(reason)

func _validate() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/content/skills.json"))
    check(raw is Dictionary,"Skills catalog failed to parse")
    var entries: Array = []
    if raw is Dictionary:
        entries = raw.get("entries",[])
    check(entries.size() == 63,"Expected 63 authored skill records")
    check(ArtDirection.skill_catalog_valid(entries),"Skill FX keys, elements or tiers invalid")
    var signatures: Dictionary = {}
    var elements: Dictionary = {}
    var fx = BattleFX.new()
    var viewport := Control.new()
    viewport.size = Vector2(1152,648)
    root.add_child(viewport)
    fx.size = viewport.size
    viewport.add_child(fx)
    for skill in entries:
        var profile: Dictionary = ArtDirection.signature(skill)
        var key: int = int(profile.get("seed",-1))
        check(not signatures.has(key),"FX signature hash collision")
        signatures[key] = true
        elements[str(skill.get("element",""))] = true
        fx.play_skill(Vector2(300,420),Vector2(720,220),skill,25,
            str(skill.get("target",""))=="all_enemies")
        check(fx.effects.size() <= BattleFX.MAX_EFFECTS,"Effect pool exceeded its cap")
        check(fx.effects.any(func(e: Dictionary) -> bool: return str(e.get("kind",""))=="signature"),
            "Missing skill signature for "+str(skill.get("id","")))
    check(elements.size() == 9,"Not all nine elemental styles represented")
    check(signatures.size() == 63,"Expected a unique signature for each skill")
    var boss_palette: Dictionary = {}
    for chapter in range(2,7):
        var style: Dictionary = ArtDirection.boss_style(chapter)
        var color: String = str(style.get("color",""))
        check(not boss_palette.has(color),"Boss visual palette duplicated")
        boss_palette[color] = true
        fx.play_boss_cue(Vector2(650,200),chapter,true)

    var state = State.new()
    var core = RPG.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.invincible = true
    battle.start(state,4,false)
    check(is_instance_valid(battle.battle_hud),"Polished HUD was not attached")
    if is_instance_valid(battle.battle_hud):
        check(battle.battle_hud.enemy_units.size() == battle.formation.units.size(),
            "Health bar count does not match encounter")
        check(battle.battle_hud.party_members.size() == state.actors.size(),
            "Party status bars do not mirror actors")
        battle.battle_hud._process(0.1)
    battle._act("guard")
    check(is_instance_valid(battle.actor_stage),"Party pose system no longer attached")
    if is_instance_valid(battle.actor_stage):
        battle.actor_stage.play_victory()
        var id: String = str(state.actors[0].get("id",""))
        check(float(battle.actor_stage.avatars[id].get("victory_time",0.0)) > 0.0,
            "Victory pose was not played")
    battle.queue_free()

    var boss_battle = Battle.new()
    root.add_child(boss_battle)
    boss_battle.game_core = core
    boss_battle.start(state,5,true)
    check(is_instance_valid(boss_battle.battle_hud),"Boss health bar not loaded")
    if is_instance_valid(boss_battle.battle_hud):
        check(boss_battle.battle_hud.boss,"Boss HUD not in boss mode")
        boss_battle.battle_hud.sync(boss_battle.formation.units,state.actors,0,true,"蓄力重击")
        check(boss_battle.battle_hud.phase_two,"Boss phase state not passed to HUD")
        boss_battle.battle_hud.show_result(true,250,70)
        check(boss_battle.battle_hud.banner == "VICTORY","Victory overlay not displayed")
        check(boss_battle.battle_hud.earned_xp == 250,"Reward numbers not rendered")
    boss_battle.queue_free()
    viewport.queue_free()
    if not errors.is_empty():
        for error in errors:
            push_error(error)
        quit(1)
        return
    print("PASS: 63 distinct signatures, 9 elements, 5 boss palettes, "
        + "pooled VFX, player/boss HUD, victory choreography and rewards")
    quit(0)
