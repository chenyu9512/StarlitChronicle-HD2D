extends SceneTree
## C-line five chapter-unique six-frame phase overlays over static B03 portrait.
## Visual only: no battle damage/turn/phase mutation.
const BossPhase=preload("res://scripts/battle_boss_awakening.gd")
var errors: Array[String]=[]
func check(ok: bool, message: String) -> void:
    if not ok:
        errors.append(message)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var unique: Dictionary={}
    for chapter in range(2,7):
        var portrait:=Control.new()
        portrait.size=Vector2(200,200)
        root.add_child(portrait)
        var motion=BossPhase.new()
        root.add_child(motion)
        motion.configure(portrait,chapter,false)
        check(motion.aura!=null and motion.aura.texture!=null,
            str(chapter)+": no player-visible phase visual")
        check(motion.motion_source in ["authored_strip","live_aura"],
            str(chapter)+": cannot identify playable art source")
        var selected: String=motion.selected_art_sheet
        if motion.motion_source=="authored_strip":
            check(selected.contains("/b03/boss_motion/") or selected==motion.SHEET,
                str(chapter)+": authored atlas identity is wrong")
            check(not unique.has(selected),str(chapter)+": reused another boss overlay")
            unique[selected]=true
        else:
            # Retired SVGs must use the chapter-coloured live light stage, not
            # a bogus AtlasTexture slicing one 32px migration image.
            check(selected.is_empty(),str(chapter)+": false authored-sheet label")
            check(motion.atlas.atlas==null,
                str(chapter)+": live light must not masquerade as a frame strip")
            check(motion.aura.texture.get_size()==Vector2(192,192),
                str(chapter)+": the live light texture has bad dimensions")
        if motion.motion_source=="authored_strip":
            check(motion.atlas.atlas.get_size()==Vector2(1152,192),str(chapter)+": sheet resolution")
            var pixels: Image=motion.atlas.atlas.get_image()
            check(pixels!=null,str(chapter)+": imported SVG unreadable")
            if pixels!=null:
                var start: PackedByteArray=pixels.get_region(Rect2i(0,0,192,192)).get_data()
                var end: PackedByteArray=pixels.get_region(Rect2i(960,0,192,192)).get_data()
                check(start!=end,str(chapter)+": phase artwork has no genuine difference")
        motion.awaken()
        check(motion.active_phase,str(chapter)+": timed phase never started")
        var start_scale: Vector2=motion.aura.scale
        for step in range(6):
            motion._advance(BossPhase.DURATION/6.0)
        check(motion.frame_switches>=6,str(chapter)+": phase time steps not played")
        check(motion.aura.scale!=start_scale or motion.motion_source=="authored_strip",
            str(chapter)+": live phase light has no expansion")
        motion.reduced_motion=true
        motion.awaken()
        motion._advance(0.12)
        check(motion.displayed_frame==3,
            str(chapter)+": reduced-motion light not stabilized")
        motion._advance(BossPhase.DURATION)
        check(not motion.active_phase,str(chapter)+": phase effect does not end")
        motion.queue_free()
        portrait.queue_free()
    if errors.is_empty():
        print("PASS: five chapter-themed imported-sheet or actual live aura phase overlays, with six timed phase states and accessible motion")
        quit(0)
        return
    for err in errors:
        push_error(err)
    quit(1)
