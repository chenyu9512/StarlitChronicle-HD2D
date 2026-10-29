extends SceneTree
## Live monster-identity acceptance for all nine first-act coast species.
## Distinct physically imported portraits and actual battle attack/hit/defeat
## response are checked. The retired 4-state SVG pose-sheet quality gate is
## still outstanding and must not be marked commercially accepted.
const Registry = preload("res://scripts/encounter_registry.gd")
const Art = preload("res://scripts/art_assets.gd")
const LiveArt = preload("res://scripts/c_act01_global_art_v14.gd")
const Foes = preload("res://scripts/battle_enemies.gd")
const IDS: Array[String] = ["salt_slime","fog_crab","sand_lizard","tide_ghost",
    "white_seabird","shell_hermit","salt_wolf","star_ray","tide_guardian"]
const NAMES: Array[String] = ["盐泥团","雾壳蟹","砂灯蜥","潮泡幽灵","白礁鸟",
    "空贝寄居","盐纹狼","星涡鳐","潮底看守"]
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        failures.append(message)

func _run() -> void:
    var registry := Registry.new()
    var tracked: Dictionary = {}
    for record in registry.monsters:
        if record is Dictionary and str(record.get("id","")).begins_with("mon_coast_"):
            tracked[str(record.get("id",""))] = record
    check(registry.COAST_ART.size() == 9,"First-act sprite contract changed")
    var used_portraits: Dictionary = {}
    for i in range(9):
        var id: String = "mon_coast_%02d" % (i+1)
        var art: String = IDS[i]
        var content_name: String = str(tracked.get(id,{}).get("name",""))
        check(content_name == NAMES[i],id+" canonical monster identity changed")
        check(registry.COAST_ART[i] == art,id+" has the wrong battle silhouette: "+str(registry.COAST_ART[i]))
        var atlas_path: String = LiveArt.battle_path(id)
        var live_path: String = Art.battle_image({"monster_id":id,"art":art},false,3)
        check(not atlas_path.is_empty() and atlas_path == live_path,
            id+" combat did not choose the active imported monster portrait")
        if live_path.is_empty() or not ResourceLoader.exists(live_path):
            failures.append(id+" has no physically imported battle texture")
            continue
        check(not used_portraits.has(live_path),id+" duplicates another monster's picture")
        used_portraits[live_path] = true
        var stage := Foes.new()
        stage.size = Vector2(1152,648)
        root.add_child(stage)
        stage.configure([{"monster_id":id,"art":art,"hp":40}],3,false)
        check(stage.slots.has(0),id+" did not spawn in the actual battle renderer")
        if stage.slots.has(0):
            var slot: Dictionary = stage.slots[0]
            var sprite: TextureRect = slot["node"]
            check(sprite.texture != null,id+" displays a blank monster")
            var start: Vector2 = slot["base"] as Vector2
            var initial_x: float = start.x
            check(str(slot.get("motion_species","")) == art,
                id+" battle renderer is not using the corrected creature motion")
            stage._process(0.04)
            if art in ["tide_ghost","white_seabird","star_ray"]:
                check(sprite.position.y < start.y-1.0,
                    id+" non-sprite-sheet species glide/flight is absent")
            # The accessibility switch is a live setting, not a battle reload.
            stage.reduced_motion = true
            stage._process(0.05)
            check(absf(sprite.position.x-start.x)<0.1 and
                absf(sprite.position.y-start.y)<0.1 and absf(sprite.rotation)<0.001,
                id+" keeps previous species motion after live accessibility toggle")
            stage.reduced_motion = false
            stage.attack(0)
            stage._process(0.075)
            check(sprite.position.x < initial_x-1.0,id+" has no visible attack lunge")
            stage.hit(0,false)
            stage._process(0.05)
            check(sprite.modulate.g < sprite.modulate.r,id+" has no actual hit-color feedback")
            stage.hit(0,true)
            stage._process(0.1)
            check(float(stage.slots[0]["dying"])>0.0,id+" death transition not active")
            stage.reduced_motion = true
            stage.configure([{"monster_id":id,"art":art,"hp":40}],3,false)
            stage._process(0.04)
            var accessible: TextureRect = stage.slots[0]["node"]
            var accessible_base: Vector2 = stage.slots[0]["base"]
            check(absf(accessible.position.x-accessible_base.x)<0.1 and
                absf(accessible.position.y-accessible_base.y)<0.1 and
                absf(accessible.rotation)<0.001,
                id+" violates reduced-motion setting")
        stage.queue_free()
    check(used_portraits.size() == 9,"Nine real coastal monster textures not all distinct")
    if failures.is_empty():
        print("PASS Main2: 9 canonical coastal monster identities, distinct actual battle PNGs and attack/hit/death feedback; illustrated pose sheets remain unapproved")
        quit(0)
        return
    for error in failures:
        push_error(error)
    quit(1)
