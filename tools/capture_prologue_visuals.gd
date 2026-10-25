extends SceneTree
## Actual GPU-frame capture for P4: not placeholders, not static preview art.
const Game=preload("res://scripts/first_act.gd")
const OUT: String="res://build/art-qa/"
var failures: Array[String]=[]
var evidence: Array[Dictionary]=[]

func _initialize() -> void:
    call_deferred("_capture")

func _screenshot(id: String,stage: String,game) -> void:
    var frame: Image=root.get_texture().get_image()
    var path: String=OUT+id+".png"
    var outcome: Error=frame.save_png(ProjectSettings.globalize_path(path))
    if outcome!=OK or frame.get_width()<640 or frame.get_height()<360:
        failures.append("Missing or undersized real GPU frame: "+id)
        return
    var brightness: float=0.0
    var samples: int=0
    for y in range(2,9):
        for x in range(2,17):
            var px: int=int(float(x)/18.0*float(frame.get_width()))
            var py: int=int(float(y)/10.0*float(frame.get_height()))
            var color: Color=frame.get_pixel(px,py)
            brightness+=(color.r+color.g+color.b)/3.0
            samples+=1
    evidence.append({
        "id":id,"stage":stage,"file":path,
        "width":frame.get_width(),"height":frame.get_height(),
        "luminance":snappedf(brightness/float(maxi(1,samples)),0.0001),
        "visual_hash":str(hash(frame.get_data())),
        "chapter":game.progress.chapter
    })

func _settle() -> void:
    for i in range(6):
        await process_frame
    await RenderingServer.frame_post_draw

func _capture() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    root.size=Vector2i(1152,648)
    var game=Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    if game.cinematic.is_playing():
        game.cinematic.skip()
    # The cinematic now fades out over 300ms; render only the actual world.
    await create_timer(0.48).timeout
    game.ui.set_play_visible(false)
    game.atlas.show_exploration(false)
    if game.progress.chapter!=0:
        failures.append("P4 capture did not launch original playable prologue")
    game.world.camera.position_smoothing_enabled=false
    game.world.camera.reset_smoothing()
    for item in [
        {"name":"prologue_festival","index":2,"phase":"festival"},
        {"name":"prologue_black_star_world","index":5,"phase":"falling"},
        {"name":"prologue_blackout","index":6,"phase":"fallen"},
        {"name":"prologue_ten_years","index":8,"phase":"ten_years"}
    ]:
        game.world.set_prologue_phase(int(item["index"]),0)
        if game.world.prologue_stage.stage!=str(item["phase"]):
            failures.append("World transition mismatch at "+str(item["name"]))
        if str(item["phase"])=="falling":
            await create_timer(3.0).timeout
        await _settle()
        _screenshot(str(item["name"]),str(item["phase"]),game)
    # P5: deterministic authored blocking timecodes, captured from the real renderer.
    # A screenshot alone cannot prove action, so the manifest includes cast positions.
    var blocking = game.world.prologue_stage.blocking
    for shot in [
        {"id":"p5_star_arrival_000","index":5,"time":0.0},
        {"id":"p5_chengzhou_intercept_018","index":5,"time":1.8},
        {"id":"p5_lanyin_moves_033","index":5,"time":3.3},
        {"id":"p5_rear_guard_000","index":6,"time":0.0},
        {"id":"p5_escape_025","index":6,"time":2.5},
        {"id":"p5_escape_040","index":6,"time":4.0},
        {"id":"p5_ash_morning","index":7,"time":0.0},
        {"id":"p5_ten_year_match","index":8,"time":0.0}
    ]:
        game.world.set_prologue_phase(int(shot["index"]),0)
        blocking.seek(float(shot["time"]))
        await _settle()
        _screenshot(str(shot["id"]),"actor_blocking",game)
        var cast_data: Dictionary={}
        for who in blocking.cast.keys():
            var performer=blocking.cast[who]
            cast_data[str(who)]={"visible":performer.visible,
                "position":[snappedf(performer.position.x,0.01),snappedf(performer.position.y,0.01)]}
        evidence[evidence.size()-1]["timecode_seconds"]=shot["time"]
        evidence[evidence.size()-1]["cast"]=cast_data
    blocking.apply("normal")
    game.world.set_prologue_phase(5,0)
    var cue: Dictionary=game.cinematic_prologue.get("beats",{}).get("prologue_5",{})
    if not game.cinematic.start("prologue_5",cue):
        failures.append("Full-screen black-star cutscene failed to open")
    else:
        await create_timer(3.0).timeout
        await _settle()
        _screenshot("prologue_black_star_cinematic","screen_black_star",game)
        game.cinematic.skip()
    var unique: Dictionary={}
    for item in evidence:
        unique[str(item["visual_hash"])]=true
    if unique.size()<4:
        failures.append("Scene states generated visually identical frames; check stage compositor")
    var report: Dictionary={
        "schema":"starlit.prologue.visual-qa.v2",
        "engine":"Godot 4.7.2",
        "real_renderer":"Xvfb GL Compatibility",
        "resolution":[1152,648],
        "evidence":evidence,
        "unique_frame_count":unique.size(),
        "passes":failures.is_empty() and evidence.size()==13,
        "manual_director_review":false,
        "iphone_real_device_review":false,
        "notes":"Rendered visuals are art-direction evidence, not evidence of commercial final-paint quality."
    }
    var handle=FileAccess.open(OUT+"prologue_manifest.json",FileAccess.WRITE)
    if handle==null:
        failures.append("Could not write render manifest")
    else:
        handle.store_string(JSON.stringify(report,"  ")+"\n")
        handle.close()
    if failures.is_empty() and evidence.size()==5:
        print("PASS P4: 13 actual Godot gameplay/cinematic frames captured; human visual review still required")
        quit(0)
        return
    for problem in failures:
        push_error(problem)
    quit(1)
