extends SceneTree
## The nine playable coastal monsters must render *real imported portraits*,
## move in combat, respond to attacks/hits, and fade when defeated.
## Complete illustrated pose strips take priority if actually shipped.
const Motion=preload("res://scripts/c_coast_monster_motion.gd")
const Foes=preload("res://scripts/battle_enemies.gd")
const IDS: Array[String]=["salt_slime","fog_crab","shell_hermit","sand_lizard",
    "salt_wolf","white_seabird","star_ray","tide_ghost","tide_guardian"]
var errors: Array[String]=[]
func verify(ok: bool,reason: String) -> void:
    if not ok: errors.append(reason)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    for art_id in IDS:
        var sheets: Dictionary=Motion.sheets(art_id)
        verify(sheets.is_empty() or sheets.size()==4,
            art_id+": incomplete genuinely imported action strip set")
        for pose in sheets.keys():
            var tex: Texture2D=sheets[pose]
            verify(tex!=null and tex.get_size()==Vector2(
                Motion.frame_count(pose)*128,128),
                art_id+": "+pose+" actual strip dimensions invalid")
        var enemies:=Foes.new()
        enemies.size=Vector2(1200,720)
        root.add_child(enemies)
        enemies.configure([{"art":art_id,"hp":45}],1,false)
        var slot: Dictionary=enemies.slots.get(0,{})
        verify(not slot.is_empty(),art_id+": battle failed to spawn a visual actor")
        if not slot.is_empty():
            var sprite: TextureRect=slot["node"]
            verify(sprite.texture!=null,art_id+": real imported monster image is missing")
            verify(str(slot.get("motion_species",""))==art_id,
                art_id+": runtime did not bind species-specific motion")
            verify((slot.get("action_sheets",{}) as Dictionary).size()==sheets.size(),
                art_id+": action source differs from battle binding")
            enemies._process(0.07)
            var base_position: Vector2=sprite.position
            var base_scale: Vector2=sprite.scale
            enemies._process(0.1)
            verify(sprite.position!=base_position or sprite.scale!=base_scale,
                art_id+": idle portrait has no playable motion")
            enemies.attack(0)
            enemies._process(0.07)
            verify(float(enemies.slots[0].get("attack",0))>0.0,
                art_id+": actual attack animation was not triggered")
            if sheets.size()==4:
                var strip: AtlasTexture=enemies.slots[0]["atlas"]
                verify(strip!=null and strip.atlas==sheets["attack"],
                    art_id+": genuine action strip not selected on attack")
            enemies.hit(0,false)
            enemies._process(0.04)
            verify(sprite.modulate.g<0.9,art_id+": received hit has no red flash")
            enemies.hit(0,true)
            enemies._process(0.1)
            verify(sprite.modulate.a<1.0,art_id+": defeat has no fade")
            for step in range(5): enemies._process(0.1)
            verify(bool(enemies.slots[0].get("dead",false)),
                art_id+": defeat never completed")
            verify(sprite.modulate.a<=0.01,
                art_id+": defeated monster remains visible")
        enemies.queue_free()
    verify(Motion.sheets("unknown_coastal_enemy").is_empty(),
        "Unknown monster must not inherit a coastal sprite sheet")
    if errors.is_empty():
        print("PASS: nine actual coastal portraits, idle motion, attack/hit/death and optional real pose strips")
        quit(0)
    else:
        for e in errors: push_error(e)
        quit(1)
