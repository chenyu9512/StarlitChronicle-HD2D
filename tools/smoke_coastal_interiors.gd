extends SceneTree
## A6: twelve real indoor stages retain authored collision & service targets.
const World = preload("res://scripts/first_act_world.gd")
const Geography = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func verify(ok: bool,why: String) -> void:
    if not ok:
        failures.append(why)
func _run() -> void:
    var geography = Geography.new()
    var registry = Registry.new()
    var state = State.new()
    registry.bind(state)
    var world = World.new()
    root.add_child(world)
    var atlases: Dictionary = {}
    var count: int = 0
    for town in ["map_coast_01","map_coast_02"]:
        for kind in ["inn","shop","guild","smith","house","shrine"]:
            var label: String=town+"#"+kind
            var layout: Dictionary=geography.interior(kind,kind,town)
            verify(str(layout.get("authored_source",""))=="v4",label+" lost authored layout")
            verify(not str(layout.get("art_profile","")).is_empty(),label+" missing art profile")
            var origins: Array[Vector2i]=[layout.get("spawn",Vector2i.ZERO)]
            var targets: Array[Vector2i]=[]
            for key in ["exit","service","storage"]:
                targets.append(layout.get("interact_cells",{}).get(key,Vector2i.ZERO))
            verify(geography.reachable(layout,origins,targets),label+" story/service destinations blocked")
            # Retired original 12 SVG atlases are no longer an allowed
            # identity source. Verify twelve different *real* V4 room plans,
            # together with the textures the running TileMap actually loads.
            var identity: String=JSON.stringify(layout.get("visuals",[]))
            verify(not identity.is_empty() and identity!="[]",
                label+" has no individual furniture composition")
            verify(not atlases.has(identity),
                label+" duplicated another room's actual visual arrangement")
            atlases[identity]=true
            world.map_profile=registry.profile(town)
            world.build(1,2)
            var exterior: Vector2=world.hero.position
            verify(world.enter_building(kind),label+" entrance broken")
            var art=world.root.get_node_or_null("InteriorArt")
            verify(art!=null,label+" did not instantiate layered 2D artwork")
            if art!=null:
                verify(art.prop_nodes.size()>=7,label+" has incomplete scenery sprites")
                verify(art.active_lights.size()>=2,label+" missing warm lights")
                verify(art.occluder_count>=2,label+" wall occlusion missing")
                verify(art.detail_layer!=null and art.detail_layer.get_used_cells().size()>0,label+" wall edging missing")
                for item in art.prop_nodes.values():
                    verify(item.texture!=null,label+" failed a sprite texture import")
            var ground_source: TileSetAtlasSource=world.layer.tile_set.get_source(0)
            var sea_source: TileSetAtlasSource=world.layer.tile_set.get_source(1)
            verify(ground_source!=null and ground_source.texture!=null and
                ground_source.texture.get_width()>=256 and
                ground_source.texture.get_height()>=256,
                label+" cannot render imported 32px physical floor atlas")
            verify(sea_source!=null and sea_source.texture!=null,
                label+" does not retain the compatible second atlas")
            verify(world.layer.get_used_cells().size()>100,
                label+" has no tile-level installed indoor floor")
            for key in ["interior_exit","interior_service","interior_storage"]:
                verify(world.nodes.has(key) and world.nodes[key].visible,label+" lost "+key)
            verify(not world.ambience.visible,label+" outdoor rain leaked inside")
            verify(world.leave_building(),label+" exit failed")
            verify(world.hero.position==exterior,label+" save-compatible street return failed")
            count+=1
    verify(count==12 and atlases.size()==12,"Expected 12 independent authored art rooms")
    if failures.is_empty():
        print("PASS: 12 unique authored indoor scenes, actually imported tile atlases, furniture, light/shadow, reachable service/exit and return")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
