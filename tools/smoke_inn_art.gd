extends SceneTree
## CI proof: the pictured room actually loads in the player's world and
## respects existing physical travel, service, and save-capable map interfaces.
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const Art = preload("res://scripts/world_interior_art.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool,reason: String) -> void:
    if not ok:
        failures.append(reason)

func _run() -> void:
    var state = State.new()
    var registry = Registry.new()
    registry.bind(state)
    var world = World.new()
    root.add_child(world)
    world.map_profile=registry.profile("map_coast_01")
    world.build(1,2)
    var street: Vector2=world.hero.position
    verify(world.enter_building("inn"),"Cannot enter authored Morning Dew inn")
    verify(str(world.terrain_layout.get("art_profile",""))=="coast_inn_v1","Gameplay did not receive authored art profile")
    verify(not world._blocked(world.hero.position),"Inn spawn blocked by art")
    verify(world.blocked.has(Vector2i(38,16)),"Authored fireplace has no collision")
    verify(not world.blocked.has(Vector2i(35,32)),"Art blocked the player spawn")
    var art = world.root.get_node_or_null("InteriorArt")
    verify(art!=null,"Playable room scene has no InteriorArt")
    if art!=null:
        verify(art is Art,"Invalid interior art runtime")
        verify(art.detail_layer!=null and art.detail_layer.get_used_cells().size()>0,"Missing authored wall decoration layer")
        verify(art.prop_nodes.size()>=12,"Individual furniture textures not integrated")
        verify(art.active_lights.size()>=3,"Indoor point lights not integrated")
        verify(art.occluder_count>=3,"Existing architectural partitions lack light occluders")
        var day_grade: Color = art.color_grade.color
        world.sync_world_clock(2,1320)
        verify(art.color_grade.color!=day_grade,"World clock did not update indoor day/night grade")
        var night_grade: Color = art.color_grade.color
        world.sync_world_clock(2,660)
        verify(art.color_grade.color!=night_grade,"World clock did not restore daytime light color")
        for id in art.prop_nodes.keys():
            verify(art.prop_nodes[id].texture!=null,"Furniture texture missing: "+str(id))
    var floor_atlas: TileSetAtlasSource=world.layer.tile_set.get_source(0)
    verify(floor_atlas.texture.resource_path.ends_with("inn_tileset.svg"),"Inn still renders generic wilderness tiles")
    for key in ["interior_exit","interior_service","interior_storage"]:
        verify(world.nodes.has(key) and world.nodes[key].visible,"Legacy indoor gameplay interaction lost: "+key)
    verify(world.leave_building(),"Inn exit failed")
    verify(world.hero.position==street,"Saved exterior return location changed")
    verify(world.enter_building("shop"),"Neighbor shop no longer accessible")
    verify(world.root.get_node_or_null("InteriorArt")==null,"Inn artwork spilled into unrelated buildings")
    verify(world.leave_building(),"Shop roundtrip failed")
    if failures.is_empty():
        print("PASS: live authored inn floor/walls/furniture/lights, player collision, original interaction IDs and building roundtrip")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
