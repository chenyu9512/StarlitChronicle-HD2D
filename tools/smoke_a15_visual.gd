extends SceneTree
## A15 visual-only acceptance: assert RPG/AI state untouched by presentation.
const Actors = preload("res://scripts/battle_actors.gd")
const Enemies = preload("res://scripts/battle_enemies.gd")
const NPC = preload("res://scripts/world_npc_visual.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func verify(ok: bool,message: String) -> void:
    if not ok:
        errors.append(message)

func _verify() -> void:
    var state = State.new()
    var saved_hp: Array[int] = []
    for member in state.actors:
        saved_hp.append(int(member.get("hp",0)))
    var stage := Control.new()
    stage.size=Vector2(1152,648)
    root.add_child(stage)
    var actors = Actors.new()
    actors.size=stage.size
    stage.add_child(actors)
    actors.configure(state.actors)
    verify(actors.avatars.size()>=2,"Expected actual party avatars")
    var hero_key: String="char_wayfarer"
    verify(actors.avatars.has(hero_key),"No protagonist in battle")
    if actors.avatars.has(hero_key):
        var entry: Dictionary=actors.avatars[hero_key]
        var footing: Sprite2D=entry["footing"]
        var sigil: Sprite2D=entry["sigil"]
        var portrait: TextureRect=entry["node"]
        verify(footing.texture is Texture2D and sigil.texture is Texture2D,"A15 artwork did not load")
        verify(footing.get_parent()==actors and footing.position.y>portrait.position.y,"Actor has no staged floor contact")
        actors.play_action(hero_key,"skill")
        actors._process(0.10)
        verify(sigil.modulate.a>0.1,"Casting sigil did not appear")
        actors.play_hit(hero_key,true)
        actors._process(0.08)
        verify(footing.modulate.a<0.5,"Fallen character shadow did not dim")
        actors.reduced_motion=true
        actors.play_hit(hero_key,false)
        actors._process(0.09)
        verify(portrait.position.distance_to(entry["base"])<0.02,"Reduced motion still moves party silhouette")
    var enemies=Enemies.new()
    enemies.size=stage.size
    stage.add_child(enemies)
    var enemy_data: Array=[
        {"name":"盐泥团","hp":50,"max_hp":50,"art":"salt_slime"},
        {"name":"雾壳蟹","hp":45,"max_hp":45,"art":"fog_crab"}
    ]
    enemies.configure(enemy_data,2,false)
    verify(enemies.slots.size()==2,"Multiple enemy silhouettes lost")
    if enemies.slots.size()==2:
        var first: Dictionary=enemies.slots[0]
        var second: Dictionary=enemies.slots[1]
        verify((first["footing"] as Sprite2D).texture is Texture2D,"Missing monster stage floor")
        enemies.focus(1)
        enemies._process(0.1)
        verify((second["footing"] as Sprite2D).modulate.a>(first["footing"] as Sprite2D).modulate.a,"Selected enemy should have clearer footing")
        enemies.attack(1)
        enemies._process(0.04)
        verify((second["footing"] as Sprite2D).modulate.r>0.5,"Enemy windup should change ground lighting")
        enemies.hit(1,true)
        for i in range(7):
            enemies._process(0.10)
        verify((second["footing"] as Sprite2D).modulate.a<0.01,"Defeated enemy grounding not faded")
    var npc=NPC.new()
    stage.add_child(npc)
    npc.setup({"id":"a15_absent","name":"工房师傅","role":"craft"})
    npc._process(0.15)
    verify(npc.animation_redraws>0,"Craft NPC has no work pose tick")
    npc._process(4.0)
    verify(npc.blink_phase>=0.0 and npc.blink_phase<3.9,"NPC blinking interval invalid")
    for i in range(state.actors.size()):
        verify(int(state.actors[i].get("hp",0))==saved_hp[i],"Pure visual stage edited party HP")
    stage.queue_free()
    var core=RPG.new()
    core.bind(state)
    var battle=Battle.new()
    root.add_child(battle)
    battle.game_core=core
    battle.invincible=true
    battle.start(state,2,true)
    verify(is_instance_valid(battle.enemy_grounding),"Boss battle lacks grounded silhouette")
    if is_instance_valid(battle.enemy_grounding):
        verify(battle.enemy_grounding.texture is Texture2D,"Boss footing SVG failed to load")
        verify(battle.enemy_grounding.visible,"Single boss stage does not display its footing")
    verify(is_instance_valid(battle.actor_stage) and battle.actor_stage.avatars.size()>=2,"Real combat lost actors")
    battle.queue_free()
    if errors.is_empty():
        print("PASS A15: combat character/foe/boss footing, casting sigils, NPC work/blink, reduced motion and unchanged HP")
        quit(0)
    else:
        for detail in errors:
            push_error(detail)
        quit(1)
