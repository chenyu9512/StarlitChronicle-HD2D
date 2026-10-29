extends SceneTree
## Salt slime: live, visible actions on the actual imported art, not a
## fictitious 20-frame animation after the SVG migration.
const Motion=preload("res://scripts/c_coast_monster_motion.gd")
const Foes=preload("res://scripts/battle_enemies.gd")
var errors: Array[String]=[]
func check(ok: bool,msg: String) -> void:
    if not ok: errors.append(msg)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var sheets: Dictionary=Motion.sheets("salt_slime")
    check(sheets.is_empty() or sheets.size()==4,
        "Partial pose atlases must never be displayed")
    check(Motion.sheets("unknown_coastal_enemy").is_empty(),
        "Unregistered monster incorrectly inherited a sprite")
    var stage:=Foes.new()
    stage.size=Vector2(1280,720)
    root.add_child(stage)
    stage.configure([{"art":"salt_slime","hp":30}],1,false)
    check(stage.slots.has(0),"Playable monster did not spawn")
    if stage.slots.has(0):
        var sprite: TextureRect=stage.slots[0]["node"]
        check(sprite.texture!=null,"Imported salt slime art missing from battle")
        stage._process(0.08)
        var previous: Vector2=sprite.scale
        stage._process(0.10)
        check(sprite.scale!=previous,"Original imported salt slime does not breathe")
        stage.attack(0)
        stage._process(0.06)
        check(float(stage.slots[0].get("attack",0))>0.0,
            "Salt slime attack has no active animation")
        if sheets.size()==4:
            var atlas: AtlasTexture=stage.slots[0]["atlas"]
            check(atlas!=null and atlas.atlas==sheets["attack"],
                "Real authored attack strip never appeared")
        stage.hit(0,false)
        stage._process(0.06)
        check(sprite.modulate.g<0.9,"Monster hit does not visibly flash")
        stage.hit(0,true)
        stage._process(0.1)
        check(sprite.modulate.a<1.0,"Defeat never fades the live portrait")
        for i in range(5): stage._process(0.1)
        check(bool(stage.slots[0]["dead"]) and sprite.modulate.a<=0.01,
            "Dead monster remains rendered after settlement")
        stage.reduced_motion=true
        stage._process(0.1)
        check(sprite.rotation==0.0,"Reduced motion failed to stabilize the corpse")
    stage.queue_free()
    if errors.is_empty():
        print("PASS: imported salt slime visual, genuine optional atlases, movement and combat responses")
        quit(0)
    else:
        for e in errors: push_error(e)
        quit(1)
