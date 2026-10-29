extends SceneTree
## A7-A11 runtime acceptance: actual sprites and routes, not reference boards.
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
var faults: Array[String]=[]
func _initialize() -> void:
    call_deferred("_run")
func verify(test: bool,why: String) -> void:
    if not test:
        faults.append(why)
func _run() -> void:
    var registry=Registry.new()
    registry.bind(State.new())
    var world=World.new()
    root.add_child(world)
    var checked: int=0
    for area in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04"]:
        world.map_profile=registry.profile(area)
        world.build(3,2)
        var scene=world.root.get_node_or_null("FirstActLocation")
        verify(world.coastal_scene!=null,"No coast renderer: "+area)
        if world.coastal_scene!=null:
            verify(world.coastal_scene.authored_sprites.size()>=6,"Missing independent scenery pieces: "+area)
            for child in world.coastal_scene.authored_sprites.values():
                verify(child.texture!=null,"Failed to import coastal art: "+area)
            # A14 SVG foreground silhouettes were retired. Inspect genuine
            # V18 individually assigned art sprites in the live y-sorted stage.
            var golden=world.coastal_scene.hd2d_dressing
            verify(is_instance_valid(golden) and golden.placed.size()>=1,
                "No actual reviewed V18 scene props in world: "+area)
            if is_instance_valid(golden):
                for depth_prop in golden.placed.values():
                    verify(depth_prop is Sprite2D and depth_prop.texture!=null,
                        "V18 prop did not import: "+area)
                    verify(depth_prop.get_parent()==world.scenery,
                        "Approved V18 depth prop escaped y-sort: "+area)
                    verify(bool(depth_prop.get_meta("visual_only",false)),
                        "V18 presentation prop incorrectly changes collision: "+area)
            verify(world.coastal_scene.reflection_frames.size()==4,"Sea glimmer spritesheet not imported: "+area)
            verify(world.coastal_scene.reflection_count<=32,"Reflections exceed mobile draw budget: "+area)
            if world.coastal_scene.reflection_count>0:
                var light_sprite: Sprite2D=world.coastal_scene.reflections[0]
                var first_frame: Texture2D=light_sprite.texture
                world.coastal_scene._process(0.21)
                verify(light_sprite.texture!=first_frame,"Reflections have no frame animation: "+area)
        verify(world.coastal_audio!=null and world.coastal_audio.player!=null,"Missing original ambient loop: "+area)
        if world.coastal_audio!=null and world.coastal_audio.player!=null:
            verify(world.coastal_audio.player.stream.data.size()==16000,"Incorrect native PCM data: "+area)
        verify(not world._blocked(world.hero.position),"Scenery accidentally blocked spawn: "+area)
        verify(world.coastal_scene.surface_detail!=null,"No batched shoreline and surface detail atlas: "+area)
        verify(world.coastal_scene.detail_count>=20,"Surface embellishment sparse or missing: "+area)
        verify(world.ambience.map_pixels==Vector2(world.WIDTH*32,world.HEIGHT*32),"Expanded-area weather incorrectly clipped: "+area)
        if area in ["map_coast_03","map_coast_04"]:
            # The old named SVG tilesets were deleted and redirected to
            # non-matching third-party sources. Current live imported material
            # must instead be a complete real 8x8 atlas, never a naked 32px tile.
            var floor_source: TileSetAtlasSource=world.layer.tile_set.get_source(0)
            verify(floor_source!=null and floor_source.texture!=null and
                floor_source.texture.get_width()>=256 and
                floor_source.texture.get_height()>=256,
                "Missing complete physically imported coastal terrain atlas: "+area)
        if area=="map_coast_04":
            verify(world.coastal_scene.cavern_grade!=null,"Cave still uses outdoor brightness")
            verify(world.coastal_scene.cavern_lights.size()==3,"Boss chamber missing authored light sources")
            var sea_atlas: TileSetAtlasSource=world.layer.tile_set.get_source(1)
            var atlas_registry=load("res://scripts/world_terrain_atlas_registry.gd")
            var approved: Array[String]=atlas_registry.atlas_sources("region_coast",area)
            verify(approved.size()==2 and approved[1]=="res://assets/art/runtime/act01_global_v14/surfaces/surface_map_coast_04_water.png",
                "Cavern still points to unrelated desert art instead of real cave water")
            verify(sea_atlas!=null and sea_atlas.texture!=null and
                sea_atlas.texture.get_width()>=256,
                "Cavern water atlas is not a real imported 8x8 source")
        if area in ["map_coast_01","map_coast_02"]:
            var count: int=0
            var drawn: int=0
            for feature in world.terrain_layout.get("features",[]):
                if feature.has("building"):
                    count+=1
            for prop in world.scenery.get_children():
                if prop.get_script()!=null and prop.get_script().resource_path=="res://scripts/world_structure.gd":
                    if is_instance_valid(prop.facade):
                        drawn+=1
            # Genuine 256px facades are preferred. Where rejected third-
            # party substitutions remain, WorldStructure draws the full native
            # roof, gables, doorway and shadow at the actual collision bounds.
            var structures: int=0
            for roof in world.scenery.get_children():
                if roof.get_script()!=null and roof.get_script().resource_path=="res://scripts/world_structure.gd":
                    structures+=1
                    verify(roof.visible and roof.cells.x>=5 and roof.cells.y>=4,
                        "Town exterior missing actual drawn facade geometry: "+area)
                    verify(not str(roof.exterior_identity).is_empty(),
                        "Town architecture lost its semantic district identity: "+area)
            verify(count>=5 and structures>=5,
                "Town lacks live distinct building objects: "+area)
            for roof in world.scenery.get_children():
                if roof.get_script()!=null and roof.get_script().resource_path=="res://scripts/world_structure.gd" and is_instance_valid(roof.facade):
                    verify(roof.z_index==world.hero.z_index,"Architecture not ground Y-sorted with hero: "+area)
                    verify(roof.facade.z_index==0,"Facade uses absolute Z and breaks Y-sort: "+area)
                    verify(is_instance_valid(roof.ground_shadow) and roof.ground_shadow.z_index==-1,"Missing building footprint shadow: "+area)
            var lamps: int=0
            for building_node in world.scenery.get_children():
                if building_node.get_script()!=null and building_node.get_script().resource_path=="res://scripts/world_structure.gd":
                    if is_instance_valid(building_node.door_lamp):
                        lamps+=1
            verify(lamps>=5,"Real town door lanterns are missing: "+area)
            world.sync_world_clock(3,1260)
            for building_node in world.scenery.get_children():
                if building_node.get_script()!=null and building_node.get_script().resource_path=="res://scripts/world_structure.gd" and is_instance_valid(building_node.door_lamp):
                    verify(building_node.door_lamp.energy>0.6,"Night lighting did not change with game clock: "+area)
            world.sync_world_clock(3,660)
        else:
            verify(world.nodes.has("dungeon_switch_a") if area=="map_coast_04" else world.nodes.has("wild_camp"),"Original geography interactions missing: "+area)
        verify(is_instance_valid(world.hero.sprite),"Playable actor sprite missing: "+area)
        world.hero.react()
        verify(world.hero.reacting,"Actor interaction lacks responsive animation: "+area)
        checked+=1
    verify(checked==4,"All first-act exploration stage renderers must build")
    if faults.is_empty():
        print("PASS: live facades/fallbacks, four V18 coast stages, distinct real cavern water, waves, lighting, audio and actor reaction")
        quit(0)
    else:
        for failure in faults:
            push_error(failure)
        quit(1)
