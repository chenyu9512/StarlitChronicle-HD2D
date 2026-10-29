extends SceneTree
## A16 real runtime visual acceptance after Main2's SVG retirement.
## Authored strips are checked when imported; otherwise inspect actual timed
## boss aura, tier-7 geometry and original actor portrait animation.
const BossSequence=preload("res://scripts/battle_boss_awakening.gd")
const FX=preload("res://scripts/battle_fx.gd")
const Battle=preload("res://scripts/first_act_battle.gd")
const State=preload("res://scripts/first_act_state.gd")
const RPG=preload("res://scripts/rpg_core.gd")
var errors: Array[String]=[]
func check(ok: bool,why: String) -> void:
    if not ok: errors.append(why)
func _initialize() -> void: call_deferred("_run")
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
    check(boss.aura!=null and boss.aura.texture!=null,
        "Real six-stage boss phase has no visible texture/light")
    check(boss.motion_source in ["authored_strip","live_aura"],
        "Unknown actual boss phase visual")
    if boss.motion_source=="authored_strip":
        check(boss.atlas!=null and boss.atlas.atlas!=null,
            "Declared imported boss strip is not loadable")
    else:
        check(boss.selected_art_sheet.is_empty() and boss.atlas.atlas==null,
            "Live aura incorrectly labels a legacy illustrated atlas")
    boss.awaken()
    check(boss.active_phase,"Boss phase did not begin")
    var frames: Array[int]=[]
    for tick in range(6):
        frames.append(boss.displayed_frame)
        boss._advance(BossSequence.DURATION/5.0)
    check(frames==[0,1,2,3,4,5],
        "Six boss timing states skipped: "+str(frames))
    check(boss.frame_switches==6,"Boss phase has incomplete timing")
    check(not boss.active_phase and boss.aura.modulate.a==0.0,
        "Boss light failed to expire")
    target.position=Vector2(470,120)
    boss._process(0.0)
    check(boss.aura.position.distance_to(target.position+target.size*0.5)<0.02,
        "Live boss aura did not track its portrait")
    boss.reduced_motion=true
    boss.awaken()
    boss._advance(0.35)
    check(boss.displayed_frame==3 and boss.frame_switches==1,
        "Reduced-motion boss phase is not static and accessible")
    var vfx:=FX.new()
    vfx.size=host.size
    host.add_child(vfx)
    vfx.play_skill(Vector2(260,360),Vector2(760,240),
        {"id":"a16_test","element":"雷","job_id":"tidecaller","tier":7},0,true)
    var keyframes: Array=vfx.effects.filter(func(item: Dictionary) -> bool:
        return str(item.get("kind",""))=="elite_frames")
    check(keyframes.size()==1,"Tier-7 spell lacked high-level visible effect")
    for i in range(14): vfx._process(0.10)
    check(vfx.effects.is_empty(),"Visual effects failed to recycle")
    vfx.reduced_motion=true
    vfx.play_skill(Vector2(260,360),Vector2(760,240),
        {"id":"a16_access","element":"冰","job_id":"cantor","tier":7},0,false)
    check(not vfx.effects.any(func(item: Dictionary) -> bool:
        return str(item.get("kind",""))=="elite_frames"),
        "Reduced motion still added intense spell flashes")
    host.queue_free()
    var state:=State.new()
    var health_before: Array[int]=[]
    for member in state.actors: health_before.append(int(member.get("hp",0)))
    var core:=RPG.new()
    core.bind(state)
    var live:=Battle.new()
    root.add_child(live)
    live.game_core=core
    live.invincible=true
    live.start(state,2,true)
    check(is_instance_valid(live.actor_stage),
        "Live combat did not mount party art stage")
    if is_instance_valid(live.actor_stage) and live.actor_stage.avatars.has("char_wayfarer"):
        var party=live.actor_stage
        var person: Dictionary=party.avatars["char_wayfarer"]
        var portrait: TextureRect=person["node"]
        check(portrait.texture!=null,
            "The imported Wayfarer combat portrait is missing")
        for action in ["attack","guard","heal","skill","special"]:
            party.play_action("char_wayfarer",action)
            party._process(0.10)
            var base: Vector2=party.avatars["char_wayfarer"]["base"]
            check(portrait.position!=base or portrait.scale!=Vector2.ONE,
                "No real portrait movement for "+action)
        party.play_hit("char_wayfarer",false)
        party._process(0.08)
        check(portrait.modulate.g<0.9,
            "Live party hit feedback never changed the portrait")
        party.reduced_motion=true
        party.play_action("char_wayfarer","guard")
        party._process(0.10)
        check(portrait.rotation==0.0,
            "Reduced-motion fighter still rocks during guard")
    check(is_instance_valid(live.boss_animation),
        "Boss phase presentation absent from the actual fight")
    check(is_instance_valid(live.vfx),
        "Actual battle did not mount the high-level spell visuals")
    if is_instance_valid(live.boss_animation):
        live.boss_animation.awaken()
        live.boss_animation._advance(0.19)
        check(live.boss_animation.displayed_frame>0,
            "Real fight did not display timed boss phase")
    for i in range(state.actors.size()):
        check(int(state.actors[i].get("hp",0))==health_before[i],
            "Visual-only animations illegally changed HP")
    live.queue_free()
    if errors.is_empty():
        print("PASS A16: six boss phase states, real portraits, attacks, hits, tier-7 VFX and accessibility")
        quit(0)
    else:
        for issue in errors: push_error(issue)
        quit(1)
