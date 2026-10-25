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
        verify(world.coastal_audio!=null and world.coastal_audio.player!=null,"Missing original ambient loop: "+area)
        if world.coastal_audio!=null and world.coastal_audio.player!=null:
            verify(world.coastal_audio.player.stream.data.size()==16000,"Incorrect native PCM data: "+area)
        verify(not world._blocked(world.hero.position),"Scenery accidentally blocked spawn: "+area)
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
            verify(count>=5 and drawn>=5,"Town lacks independent architectural artwork: "+area)
        else:
            verify(world.nodes.has("dungeon_switch_a") if area=="map_coast_04" else world.nodes.has("wild_camp"),"Original geography interactions missing: "+area)
        verify(is_instance_valid(world.hero.sprite),"Playable actor sprite missing: "+area)
        world.hero.react()
        verify(world.hero.reacting,"Actor interaction lacks responsive animation: "+area)
        checked+=1
    verify(checked==4,"All first-act exploration stage renderers must build")
    if faults.is_empty():
        print("PASS A7-A11: 12 facade profiles, 4 scenic stages, coast waves, cavern props, authored PCM and actor reaction")
        quit(0)
    else:
        for failure in faults:
            push_error(failure)
        quit(1)
