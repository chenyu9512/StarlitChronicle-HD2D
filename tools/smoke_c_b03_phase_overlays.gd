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
        var selected: String=motion.selected_art_sheet
        check(selected.contains("/b03/boss_motion/"),str(chapter)+": still bound to generic animation")
        check(not unique.has(selected),str(chapter)+": reused another boss overlay")
        unique[selected]=true
        check(motion.atlas!=null and motion.atlas.atlas!=null,str(chapter)+": overlay not loaded")
        if motion.atlas!=null and motion.atlas.atlas!=null:
            check(motion.atlas.atlas.get_size()==Vector2(1152,192),str(chapter)+": sheet resolution")
            var pixels: Image=motion.atlas.atlas.get_image()
            check(pixels!=null,str(chapter)+": imported SVG unreadable")
            if pixels!=null:
                var start: PackedByteArray=pixels.get_region(Rect2i(0,0,192,192)).get_data()
                var end: PackedByteArray=pixels.get_region(Rect2i(960,0,192,192)).get_data()
                check(start!=end,str(chapter)+": phase artwork has no genuine difference")
        motion.awaken()
        for step in range(6):
            motion._advance(BossPhase.DURATION/6.0)
        check(motion.frame_switches>=6,str(chapter)+": frames not played")
        check(not motion.active_phase,str(chapter)+": phase effect does not end")
        motion.queue_free()
        portrait.queue_free()
    if errors.is_empty():
        print("PASS: five authored B03 phase overlays, 30 illustrated frames, imported and animated")
        quit(0)
    for err in errors:
        push_error(err)
    quit(1)
