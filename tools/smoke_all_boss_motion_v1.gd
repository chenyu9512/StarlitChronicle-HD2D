extends SceneTree
## All 66 boss identities must use their own six-pose 4-frame actual Texture2D.
const BossMotion = preload("res://scripts/c_boss_action_atlas_v1.gd")
const Enemies = preload("res://scripts/battle_enemies.gd")
var faults: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        faults.append(message)
func _run() -> void:
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/assets/av_registry.json"))
    if not doc is Dictionary:
        push_error("Cannot read boss registry")
        quit(1)
        return
    var names: Array = doc.get("bosses",[])
    check(names.size()==66 and BossMotion.count()==66,"66 boss action identities required")
    var unique: Dictionary={}
    for record in names:
        var id: String = str(record.get("id",""))
        var sheet: Texture2D = BossMotion.texture(id)
        check(sheet!=null,"Missing boss motion Texture2D: "+id)
        if sheet==null:
            continue
        check(sheet.get_size()==Vector2(512,768),id+" incorrect 4x6 atlas dimensions")
        unique[sheet.resource_path]=true
        var stage:=Enemies.new()
        stage.size=Vector2(1280,720)
        root.add_child(stage)
        stage.configure([{"boss_id":id,"hp":400,"art":"boss"}],int(record.get("act",1)),true)
        check(stage.slots.has(0),id+" absent from real battle renderer")
        if stage.slots.has(0):
            var data: Dictionary = stage.slots[0]
            var actor: TextureRect = data.get("node",null) as TextureRect
            var atlas: AtlasTexture = actor.texture as AtlasTexture if actor!=null else null
            check(atlas!=null and bool(data.get("boss_motion",false)),id+" battle actor not showing imported action PNG")
            if atlas!=null:
                stage.attack(0)
                stage._process(0.02)
                check(atlas.region.position.y==128.0,id+" attack row not active")
                stage.hit(0)
                stage._process(0.02)
                check(atlas.region.position.y==256.0,id+" hit row not active")
                for t in range(15):
                    stage._process(0.08)
                stage.phase_shift(0)
                stage._process(0.02)
                check(atlas.region.position.y==640.0,id+" phase change row not active")
                for t in range(15):
                    stage._process(0.08)
                stage.status_visual(0)
                stage._process(0.02)
                check(atlas.region.position.y==384.0,id+" status row not active")
                stage.hit(0,true)
                stage._process(0.02)
                check(atlas.region.position.y==512.0,id+" down row not active")
        stage.free()
    check(unique.size()==66,"66 distinct boss GPU sheets not verified")
    if faults.is_empty():
        print("PASS 66 bosses with actual 6-pose 4-frame PNG atlases and live battle state switching; visual QA pending")
        quit(0)
    else:
        for message in faults:
            push_error(message)
        quit(1)
