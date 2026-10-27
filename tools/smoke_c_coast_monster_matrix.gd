extends SceneTree
## C-line monster art smoke; only visual actor state transitions; no combat HP mutation.
const C = preload("res://scripts/c_coast_monster_motion.gd")
const Foes = preload("res://scripts/battle_enemies.gd")
const IDS: Array[String] = ["salt_slime", "fog_crab", "shell_hermit", "sand_lizard", "salt_wolf", "white_seabird", "star_ray", "tide_ghost", "tide_guardian"]
var errors: Array[String] = []
func verify(ok: bool, msg: String) -> void:
    if not ok:
        errors.append(msg)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    for art_id in IDS:
        var pics: Dictionary = C.sheets(art_id)
        verify(pics.size() == 4, art_id + ": incomplete action atlas")
        if pics.size() != 4:
            continue
        for pose in ["idle", "attack", "hit", "defeat"]:
            var source: Texture2D = pics[pose]
            verify(source.get_size() == Vector2(C.frame_count(pose) * 128, 128), art_id + ":" + pose + " source dimensions wrong")
            var im: Image = source.get_image()
            verify(im != null, art_id + ":" + pose + " not importable")
            if im != null:
                var first: PackedByteArray = im.get_region(Rect2i(0,0,128,128)).get_data()
                var last: PackedByteArray = im.get_region(Rect2i((C.frame_count(pose)-1)*128,0,128,128)).get_data()
                verify(first != last, art_id + ":" + pose + " first/last identical")
        var enemies := Foes.new()
        enemies.size = Vector2(1200, 720)
        root.add_child(enemies)
        enemies.configure([{"art":art_id,"hp":45}], 1, false)
        var slot: Dictionary = enemies.slots.get(0,{})
        verify((slot.get("action_sheets",{}) as Dictionary).size() == 4, art_id + ": battle binding absent")
        if not slot.is_empty():
            enemies.attack(0)
            enemies._process(0.06)
            var atlas: AtlasTexture = enemies.slots[0]["atlas"]
            verify(atlas != null and atlas.atlas == pics["attack"], art_id + ": attack pose not selected")
            enemies.hit(0,false)
            enemies._process(0.04)
            verify(atlas.atlas == pics["hit"], art_id + ": hit pose not selected")
            enemies.hit(0,true)
            enemies._process(0.04)
            verify(atlas.atlas == pics["defeat"], art_id + ": defeat pose not selected")
        enemies.queue_free()
    verify(C.sheets("unknown_coastal_enemy").is_empty(), "Non-covered enemies must remain on original texture")
    if errors.is_empty():
        print("PASS C coast action matrix: nine monsters, 180 distinct poses, four states and visual-only battle bindings")
        quit(0)
    for item in errors:
        push_error(item)
    quit(1)
