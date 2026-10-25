extends SceneTree
## P4 real-world visual state: no quest state, navigation or save-slot regressions.
const Game=preload("res://scripts/first_act.gd")
var errors: Array[String]=[]

func check(ok: bool,reason: String) -> void:
    if not ok: errors.append(reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game=Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    check(game.progress.chapter==0,"Fresh game must remain in playable childhood prologue")
    check(game.world.map_profile.get("id","")=="map_coast_01","P4 stage must load Morning Dew Village")
    var fx=game.world.prologue_stage
    check(fx!=null and fx.stage=="normal","First scene must open with unaltered village")
    check(fx.lamps.size()>0,"Village has no actual staged lamps to extinguish")
    var safe_nodes: int=game.world.nodes.size()
    var safe_collision: Dictionary=game.world.blocked.duplicate()
    var original_colors: Dictionary={}
    for lamp in fx.lamps:
        original_colors[lamp.get_instance_id()]=lamp.modulate
    game.world.set_prologue_phase(2,0)
    check(fx.stage=="festival" and fx.visible,"Festival did not light up walkable real village")
    game.world.set_prologue_phase(5,0)
    check(fx.stage=="falling","Black star isn't animated in the physical world")
    game.world.set_prologue_phase(6,0)
    check(fx.stage=="fallen","Lighthouse blackout isn't persistent")
    for lamp in fx.lamps:
        var original: Color=original_colors.get(lamp.get_instance_id(),Color.WHITE)
        check(lamp.modulate.r<=original.r*0.19,"Visible star lamp remains illuminated after disaster")
    game.world.set_prologue_phase(7,0)
    check(fx.stage=="forgotten","Memory loss must have an altered visual state")
    game.world.set_prologue_phase(8,0)
    check(fx.stage=="ten_years","Time jump is not visibly distinct")
    game.world.set_prologue_phase(0,1)
    check(fx.stage=="normal" and not fx.visible,"New act retained crisis overlay")
    for lamp in fx.lamps:
        var original: Color=original_colors.get(lamp.get_instance_id(),Color.WHITE)
        check(is_equal_approx(lamp.modulate.r,original.r),"Lamp illumination did not restore")
    check(game.world.nodes.size()==safe_nodes,"Pure visual transitions erased mission / shop interaction markers")
    check(game.world.blocked==safe_collision,"Visual transitions changed walkable collision")
    check(game.progress.chapter==0 and game.progress.scene_index==0,"Visual transition mutated actual chapter progression")
    check(game.cinematic.scene_fx!=null,"Full-screen animated layer was not attached")
    var scenes: Dictionary=game.cinematic_prologue.get("beats",{})
    for id in ["cold_open","prologue_2","prologue_5","prologue_6","prologue_7","prologue_8"]:
        var data: Dictionary=scenes.get(id,{})
        check(not str(data.get("effect","")).is_empty(),"No authored screen VFX: "+id)
        game.cinematic.start(id,data)
        check(game.cinematic.scene_fx.visible,"Cutscene overlay missing VFX layer at "+id)
        check(game.cinematic.scene_fx.effect==str(data["effect"]),"Wrong event visual director cue")
        game.cinematic.skip()
        check(not game.cinematic.scene_fx.visible and game.cinematic.scene_fx.effect.is_empty(),"Skipped cutscene leaked effects")
    if errors.is_empty():
        print("PASS: village festival, meteor, persistent outage, forgetting, decade time jump, 6 animated cutscene cues, safe skip and unchanged quest/collision")
        quit(0)
        return
    for item in errors:
        push_error(item)
    quit(1)
