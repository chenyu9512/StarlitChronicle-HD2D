extends SceneTree
## C10 visual art binding smoke; story migration is intentionally NOT touched.
const Art = preload("res://scripts/c_act01_production_registry.gd")
const Coast = preload("res://scripts/world_coastal_scene.gd")
const Geography = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
const Overrides = preload("res://scripts/c_art_overrides.gd")
var errors: Array[String] = []

func check(ok: bool,reason: String) -> void:
    if not ok:
        errors.append(reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var registry := Registry.new()
    var geography := Geography.new()
    for i in range(1,7):
        var spec: Dictionary=Art.chapter_bundle(i)
        check(int(spec.get("chapter",0))==i,"Chapter art record missing "+str(i))
        var canonical: String=str(spec.get("canonical_scene_map_id",""))
        check(Art.has_map(canonical),"Canonical art map not found "+canonical)
        check(not Art.production_paths(canonical).is_empty(),"No art assets for "+canonical)
    for map_key in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04","map_coast_05"]:
        check(Art.has_map(map_key),"Missing art bundle "+map_key)
        check(Art.production_paths(map_key).size()>5,"No production paths "+map_key)
        check(registry.maps.has(map_key),"Map registry lacks "+map_key)
    check(not Art.has_map("map_unknown"),"Unknown map accepted")
    check(Overrides.has_slot("res://assets/art/exteriors/coast_final_pass/tide_lighthouse_landmark.svg"),
        "Lighthouse not exposed to global DLC / gallery")
    for i in range(2,7):
        check(Overrides.texture(str(Art.chapter_bundle(i).get("boss_phase_overlay",""))) != null,
            "Chapter boss phase art missing after third-party remapping: "+str(i))
    check(Art.sprite_path("map_coast_05","tide_lighthouse_landmark")=="res://assets/art/exteriors/coast_final_pass/tide_lighthouse_landmark.svg",
        "Lighthouse artwork not registered")
    var layout: Dictionary=geography.layout("map_coast_05",6)
    var original_blocked: Dictionary=layout.get("blocked",{}).duplicate(true)
    var scene := Coast.new()
    root.add_child(scene)
    scene.configure("map_coast_05",layout)
    check(scene.authored_sprites.has("lighthouse_landmark"),"Lighthouse scene not rendered")
    check(is_instance_valid(scene.lighthouse_light), "Coastal lighthouse lamp missing")
    scene.set_clock(1320)
    scene.set_visual_quality(2)
    if is_instance_valid(scene.lighthouse_light):
        check(scene.lighthouse_light.visible, "Lighthouse night light disabled")
    scene.set_visual_quality(0)
    if is_instance_valid(scene.lighthouse_light):
        check(not scene.lighthouse_light.visible, "Lighthouse low-quality budget not respected")
    check(layout.get("blocked",{})==original_blocked,"C-art changed authority blocked cells")
    if scene.authored_sprites.has("lighthouse_landmark"):
        var artwork: Sprite2D=scene.authored_sprites["lighthouse_landmark"]
        check(artwork.texture!=null,"Lighthouse texture missing")
        check(artwork.scale.x<1.0,"Lighthouse authored scale missing")
    if errors.is_empty():
        print("SUCCESS: first six art map bundles and lighthouse scene wired; geometry untouched")
        quit(0)
        return
    for reason in errors:
        push_error(reason)
    quit(1)
