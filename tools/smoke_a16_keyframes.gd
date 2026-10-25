extends SceneTree
## A16: verify actual authored frame regions, low-motion access and combat isolation.
const BossSequence = preload("res://scripts/battle_boss_awakening.gd")
const FX = preload("res://scripts/battle_fx.gd")
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
var errors: Array[String]=[]

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,why: String) -> void:
    if not ok:
        errors.append(why)

func _run() -> void:
    var host:=Control.new()
    host.size=Vector2(1152,648)
    root.add_child(host)
    var target:=TextureRect.new()
    target.size=Vector2(270,248)
    target.position=Vector2(390,98)
    host.add_child(target)
    var boss:=BossSequence.new()
    boss.size=host.size
    host.add_child(boss)
    boss.configure(target,5)
    check(boss.atlas!=null and boss.atlas.atlas is Texture2D,
        "Six-frame phase atlas is not loadable")
    boss.awaken()
    var frames: Array[int]=[]
    for tick in range(6):
        frames.append(boss.displayed_frame)
        boss._advance(BossSequence.DURATION/5.0)
    check(frames==[0,1,2,3,4,5],"Boss phase sprite sheet did not visit all six frames: "+str(frames))
    check(boss.frame_switches==6,"Boss awakening advanced fewer than six frames")
    check(not boss.active_phase and boss.aura.modulate.a==0.0,"Phase overlay did not expire")
    target.position=Vector2(470,120)
    boss._process(0.0)
    check(boss.aura.position.distance_to(target.position+target.size*0.5)<0.02,
        "Boss aura does not follow displayed portrait")
    boss.reduced_motion=true
    boss.awaken()
    boss._advance(0.35)
    check(boss.displayed_frame==3 and boss.frame_switches==1,
        "Reduced-motion Boss does not use a static accessible pose")

    var vfx=FX.new()
    vfx.size=host.size
    host.add_child(vfx)
    check(vfx.elite_sequence is Texture2D,"Authored four-frame elite skill atlas not loaded")
    vfx.play_skill(Vector2(260,360),Vector2(760,240),
        {"id":"a16_test","fx_key":"a16_test","element":"雷","job_id":"tidecaller","tier":7},0,true)
    var keyframes: Array=vfx.effects.filter(func(item: Dictionary) -> bool:
        return str(item.get("kind",""))=="elite_frames")
    check(keyframes.size()==1,"Tier-7 skill must enqueue four authored frames")
    for i in range(14):
        vfx._process(0.10)
    check(vfx.effects.is_empty(),"New visual effects were not recycled")
    vfx.reduced_motion=true
    vfx.play_skill(Vector2(260,360),Vector2(760,240),
        {"id":"a16_access","element":"冰","job_id":"cantor","tier":7},0,false)
    check(not vfx.effects.any(func(item: Dictionary) -> bool:
        return str(item.get("kind",""))=="elite_frames"),"Reduced motion enqueued intense spell flashes")
    host.queue_free()

    var state=State.new()
    var health_before: Array[int]=[]
    for member in state.actors:
        health_before.append(int(member.get("hp",0)))
    var core=RPG.new()
    core.bind(state)
    var real_battle=Battle.new()
    root.add_child(real_battle)
    real_battle.game_core=core
    real_battle.invincible=true
    real_battle.start(state,2,true)
    if is_instance_valid(real_battle.actor_stage) and real_battle.actor_stage.avatars.has("char_wayfarer"):
        var party=real_battle.actor_stage
        var test_member: Dictionary=party.avatars["char_wayfarer"]
        var overlay: Sprite2D=test_member["motion"]
        var strip: AtlasTexture=test_member["motion_atlas"]
        check(strip.atlas is Texture2D,"Party six-frame motion atlas missing")
        for kind in ["attack","guard","heal","skill","special"]:
            party.play_action("char_wayfarer",kind)
            party._process(0.10)
            check(overlay.modulate.a>0.3,"Party animation not visible for "+kind)
            check(int(strip.region.position.x)>0,"Party animation has no active frame for "+kind)
        party.play_hit("char_wayfarer",false)
        party._process(0.1)
        check(str(party.avatars["char_wayfarer"].get("motion_kind",""))=="hit",
            "Hit animation did not override player action")
        party.reduced_motion=true
        party.play_action("char_wayfarer","guard")
        party._process(0.08)
        # Hit has precedence until its timer expires, then guard can display.
        for i in range(4):
            party._process(0.08)
        check(int(strip.region.position.x)==3*party.ACTION_FRAME_SIZE,
            "Reduced-motion stance should remain on the third non-flashing frame")
    check(is_instance_valid(real_battle.boss_animation),"Boss animation not mounted in real combat")
    check(is_instance_valid(real_battle.vfx) and real_battle.vfx.elite_sequence is Texture2D,
        "Real combat lost elite-effect atlas")
    if is_instance_valid(real_battle.boss_animation):
        real_battle.boss_animation.awaken()
        real_battle.boss_animation._advance(0.19)
        check(real_battle.boss_animation.displayed_frame>0,"Live phase overlay did not advance")
    for i in range(state.actors.size()):
        check(int(state.actors[i].get("hp",0))==health_before[i],
            "Boss animation mutated real combat HP")
    real_battle.queue_free()
    if errors.is_empty():
        print("PASS A16: six unique Boss frames, four authored elite effects, reduced motion, cleanup, live battle and HP isolation")
        quit(0)
    else:
        for issue in errors:
            push_error(issue)
        quit(1)
