extends SceneTree
## Physically build and enter the authored Ch2/Ch4 harbor rooms.
## Check imported V14 images, real lighting, intact obstacles and V4 nodes.
## Does NOT claim commercial hand-painted identity has been approved.
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const World = preload("res://scripts/first_act_world.gd")
const GlobalArt = preload("res://scripts/c_act01_global_art_v14.gd")
const InteriorArt = preload("res://scripts/world_interior_art.gd")
const Overrides = preload("res://scripts/c_art_overrides.gd")
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _verify(ok: bool, reason: String) -> void:
    if not ok:
        errors.append(reason)

func _run() -> void:
    var game_state := State.new()
    game_state.new_game()
    var router := Registry.new()
    router.bind(game_state)
    var world := World.new()
    world.map_profile = router.profile("map_coast_02")
    root.add_child(world)
    for room in ["shelter","tavern"]:
        var chapter: int = 2 if room == "shelter" else 4
        world.build(chapter,2)
        var street: Vector2 = world.hero.position
        _verify(world.enter_building(room),"Cannot enter playable "+room)
        if world.interior_building != room:
            continue
        var layout: Dictionary = world.terrain_layout
        _verify(str(layout.get("art_profile","")) == "coast_act01_"+room+"_v1",
            room+" did not load the authored room art profile")
        var expected_floor: String = "res://assets/art/runtime/global_factory_v3/interiors/map_coast_02__shelter.png"
        if room == "tavern":
            expected_floor = RuntimeArt.slot_source("interior.tavern.tavern_wood_atlas")
        var assigned_floor: String = str(layout.get("art_tileset", ""))
        _verify(assigned_floor == expected_floor and ResourceLoader.exists(expected_floor),
            room+" is not using its own actual generated 2D room atlas")
        _verify(world.layer != null and world.layer.tile_set != null,
            room+" has no actual imported TileMap layer")
        _verify((layout.get("solid_regions",[]) as Array).size() == (6 if room == "shelter" else 7),
            room+" did not install its authored partitions")
        _verify(world.blocked.has(Vector2i(22,17)) if room == "shelter" else world.blocked.has(Vector2i(35,15)),
            room+" independent physical partition was not applied")
        _verify(not world.blocked.has(Vector2i(31,20)) if room == "shelter" else not world.blocked.has(Vector2i(22,17)),
            room+" still uses the other room's copied geometry")
        var targets: Array[Vector2i] = []
        for point in ["exit","service","storage"]:
            targets.append(layout.get("interact_cells",{}).get(point,Vector2i(-1,-1)))
        for investigation in layout.get("investigations",[]):
            targets.append(investigation.get("cell",Vector2i(-1,-1)))
        var starts: Array[Vector2i] = [layout.get("spawn",Vector2i(-1,-1))]
        _verify(world.geography.reachable(layout,starts,targets),
            room+" visual partitions blocked an authored interactive destination")
        _verify(world.camera != null and world.camera.zoom.x <= 1.10 and
            world.camera.position.y < -100.0,
            room+" camera still crops all correctly scaled story furniture")
        var room_art = world.root.get_node_or_null("InteriorArt")
        _verify(room_art != null,room+" did not instantiate layered interior rendering")
        if room_art != null:
            _verify(room_art.prop_nodes.size() == (11 if room == "shelter" else 20),
                room+" missing physically rendered room furnishings")
            _verify(room_art.active_lights.size() == (3 if room == "shelter" else 4),
                room+" lost authored lighting")
            for light in room_art.active_lights:
                _verify(light.texture != null and light.texture.get_width() == 64,
                    room+" still uses a mismatched furniture PNG as lamp falloff")
                if light.texture != null:
                    var glow_img: Image = light.texture.get_image()
                    _verify(glow_img != null and glow_img.get_pixel(0,0).a < 0.01 and
                        glow_img.get_pixel(32,32).a > 0.90,
                        room+" real light no longer has transparent radial falloff")
            _verify(room_art.occluder_count >= 2,
                room+" has no working partition occluders")
            if not ResourceLoader.exists("res://assets/art/interiors/morning_dew_inn/hearth_flames_6f.svg"):
                _verify(room_art.animated_fire == null,
                    room+" rendered deleted hearth strips from an unrelated paper-lantern image")
            _verify(room_art.detail_layer != null,
                room+" has no themed wall-edge TileMap")
            # Rendering clearance is stricter than collision reachability:
            # the doorway must not be visually hidden behind large furniture.
            if room == "tavern":
                for entry in layout.get("visuals", []):
                    if not entry is Dictionary or str(entry.get("layer", "")) in ["floor", "wall"]:
                        continue
                    var place: Array = entry.get("cell", [])
                    var raw_footprint: Array = entry.get("footprint", [])
                    if place.size() != 2 or raw_footprint.size() != 2:
                        continue
                    var half_width: float = float(raw_footprint[0]) / 64.0
                    var half_height: float = float(raw_footprint[1]) / 64.0
                    var left: float = float(place[0]) - half_width
                    var right: float = float(place[0]) + half_width
                    var top: float = float(place[1]) - half_height
                    var bottom: float = float(place[1]) + half_height
                    var overlaps_exit: bool = left <= 36.0 and right >= 34.0 and top <= 38.0 and bottom >= 29.0
                    _verify(not overlaps_exit, "Black Sail furniture obscures entry/exit: " + str(entry.get("id", "")))
            var unique_ids: Dictionary = {}
            var expected_by_id: Dictionary = {}
            for entry in layout.get("visuals", []):
                if entry is Dictionary:
                    expected_by_id[str(entry.get("id", ""))] = str(entry.get("asset", ""))
            var material_icons: int = 0
            for prop_id in room_art.prop_nodes.keys():
                var prop: Sprite2D = room_art.prop_nodes[prop_id]
                unique_ids[prop_id] = true
                if prop.has_meta("semantic_icon"):
                    material_icons += 1
                    _verify(prop.get_child_count() > 0,room+" material icon has no actual visible sprite")
                _verify(bool(prop.get_meta("act01_imported_furniture",false)),
                    room+" displayed a legacy wrong-image placeholder: "+str(prop_id))
                if room == "tavern":
                    var source: String = str(prop.get_meta("black_sail_v2_asset",""))
                    var semantic_id: String = "interior.tavern." + str(expected_by_id.get(prop_id, ""))
                    _verify(not source.is_empty() and source == RuntimeArt.slot_source(semantic_id)
                        and source.begins_with("res://assets/art/runtime/generated_gaps_v10/")
                        and ResourceLoader.exists(source),
                        "Tavern did not import exact-role generated furniture: "+str(prop_id))
                _verify(prop.texture != null and prop.texture.get_width() > 0,
                    room+" did not import the real furniture PNG: "+str(prop_id))
                # Every imported object must fit a plausible interior floor
                # footprint. This catches regression to 1000px furniture
                # stretching across the 32px grid.
                var footprint: Vector2=prop.get_meta("room_visual_footprint",Vector2.ZERO)
                var dimensions: Vector2=Vector2(prop.texture.get_size())*prop.scale
                _verify(footprint.x>0.0 and footprint.y>0.0 and
                    dimensions.x<=footprint.x+1.0 and dimensions.y<=footprint.y+1.0,
                    room+" oversized imported furniture: "+str(prop_id))
                _verify(float(prop.get_meta("room_art_scale",1.0))>0.0,
                    room+" zero-sized furniture: "+str(prop_id))
            if room == "shelter":
                # Every clinic fixture uses its own physical shelter image.
                var semantic_assets: Dictionary = {}
                for entry in layout.get("visuals", []):
                    if entry is Dictionary:
                        semantic_assets[str(entry.get("id", ""))] = str(entry.get("asset", ""))
                var expected_clinic: Dictionary = {
                    "admission_counter": "medical_registration_counter",
                    "treatment_prep": "treatment_bench",
                    "medicine_storage": "shelter_medicine_cabinet",
                    "medicine_reserve": "shelter_medicine_cabinet",
                    "bedside_medicine": "shelter_treatment_tray",
                    "linen_supply": "shelter_linen_cart",
                    "empty_bed_kit": "shelter_cot",
                }
                for placement in expected_clinic.keys():
                    var expected_asset: String = str(expected_clinic[placement])
                    var expected_path: String = RuntimeArt.slot_source("interior.shelter." + expected_asset)
                    _verify(semantic_assets.get(placement, "") == expected_asset,
                        "Shelter scene retained a wrong crate as medical furniture: "+str(placement))
                    _verify(room_art.prop_nodes.has(placement),
                        "Shelter dedicated clinic furniture not rendered: "+str(placement))
                    if room_art.prop_nodes.has(placement):
                        var medical_prop: Sprite2D = room_art.prop_nodes[placement]
                        _verify(not expected_path.is_empty() and
                            str(medical_prop.get_meta("shelter_medical_furniture_source", "")) == expected_path and
                            expected_path.begins_with("res://assets/art/runtime/generated_gaps_v10/") and
                            ResourceLoader.exists(expected_path),
                            "Shelter furniture did not load exact-role generated PNG: "+str(placement))
                _verify(semantic_assets.get("admission_counter", "") == "medical_registration_counter" and
                    semantic_assets.get("treatment_prep", "") == "treatment_bench",
                    "Shelter reception or treatment identity changed")
            _verify(unique_ids.size() == (11 if room == "shelter" else 20),room+" furniture IDs overlap")
            _verify(material_icons == 4,room+" is missing identifiable medical/ledger image labels")
            # Previous room test leaves the world clock at night.
            # Establish the daylight baseline explicitly for *each* room.
            world.sync_world_clock(1,660)
            var daylight: Color = room_art.color_grade.color
            world.sync_world_clock(1,1320)
            _verify(daylight != room_art.color_grade.color,
                room+" day/night color grade is not running")
        var found: int = 0
        for key in world.nodes.keys():
            if str(key).begins_with("homeinspect:"):
                found += 1
                var marker: Sprite2D = world.nodes[key]
                _verify(marker.self_modulate.a < 0.01,
                    room+" double-renders an old prop over approved room art")
        _verify(found == 4,room+" has lost one of the four real inspectable clues")
        _verify(world.nodes.has("interior_exit"),room+" has no physical return exit")
        var exit_cell: Vector2i = layout.get("interact_cells",{}).get("exit",Vector2i(-1,-1))
        _verify(not world.blocked.has(exit_cell),room+" return exit has collision")
        _verify(world.leave_building(),room+" cannot leave back to the outdoor map")
        _verify(not world._blocked(world.hero.position),room+" exit places hero inside a wall")
        _verify(world.hero.position == street,room+" exit changed the safe existing save point")
    # The 12 removed C2.1 signature SVGs must never be redrawn using the
    # migration's unrelated shrine wall tile, even when that PNG exists.
    var retired := "res://assets/art/interiors/morning_dew_signature/dew_inn_floor_motif.svg"
    _verify(not ResourceLoader.exists(retired) and Overrides.third_party_source(retired) == retired,
        "Retired signature was unexpectedly restored or redirected to mismatched shrine art")
    var signature_art := InteriorArt.new()
    var signature_stage := Node2D.new()
    root.add_child(signature_stage)
    root.add_child(signature_art)
    for room_key in ["inn","house","shop","guild","smith","shrine"]:
        signature_art.call("_install_dew_signature",signature_stage,{"tiles":{},"blocked":{}},"map_coast_01",room_key)
        _verify(signature_art.signature_nodes.is_empty(),
            "Unapproved shrine tile displayed as "+room_key+" decorative signature")
    signature_art.queue_free()
    signature_stage.queue_free()
    _verify(GlobalArt.texture_for_prop("fish_stall") != null,"Real harbor service counter asset unimportable")
    world.queue_free()
    if errors.is_empty():
        print("PASS Main2: shelter plus unique Black Sail tavern; 31 live furnishings, 7 lamps, 8 story clues and safe return exits")
        quit(0)
        return
    for err in errors:
        push_error(err)
    quit(1)
