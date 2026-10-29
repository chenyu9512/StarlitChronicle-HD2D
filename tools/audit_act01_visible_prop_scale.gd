extends SceneTree
## Inspect the TRUE world-scale dimensions of every instantiated Sprite2D.
## This must inspect live Godot nodes, not asset file sizes or placeholder art.
const World = preload("res://scripts/first_act_world.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const MAPS: Array[String]=["map_coast_01","map_coast_02","map_coast_03","map_coast_04","map_coast_05"]

func _initialize() -> void:
    call_deferred("_run")

func _inspect(node: Node,map_id: String,path: String) -> int:
    var total: int=0
    if node is Sprite2D:
        var sprite: Sprite2D=node as Sprite2D
        # Four/eight-frame actor strips are Texture2D atlases and may be
        # 240px wide, while their individual world frames are only 32px.
        # Require a world-decoration semantic marker to avoid false positives.
        if sprite.texture!=null and (sprite.has_meta("prop_kind") or
                sprite.has_meta("art_kind") or sprite.has_meta("visual_only")
                or sprite.has_meta("act01_global_art_v14")):
            var size: Vector2=Vector2(sprite.texture.get_size())*sprite.global_scale.abs()
            # A large 32px-world sprite painted from a gigantic environmental
            # illustration is a high-confidence mismatch, not scenic detail.
            # The chapter-six lighthouse itself is a genuine, purpose-built
            # main landmark. It MUST be larger than a barrel or shrubs.
            var intended_lighthouse: bool = (map_id=="map_coast_05"
                and str(sprite.get_meta("art_kind",""))=="tide_lighthouse_landmark")
            var max_w: float=320.0 if intended_lighthouse else 230.0
            var max_h: float=430.0 if intended_lighthouse else 250.0
            if size.x>max_w or size.y>max_h:
                print("VISUAL_OVERSIZE "+map_id+" "+path+"/"+str(sprite.name)+
                    " width="+str(roundf(size.x))+" height="+str(roundf(size.y))+
                    " texture="+str(sprite.texture.resource_path)+
                    " kind="+str(sprite.get_meta("prop_kind",sprite.get_meta("art_kind","-")))+
                    " cell="+str(Vector2i(floori(sprite.global_position.x/32.0),floori(sprite.global_position.y/32.0))))
                total+=1
    for child in node.get_children():
        total+=_inspect(child,map_id,path+"/"+str(node.name))
    return total

func _run() -> void:
    var progress:=State.new()
    progress.new_game()
    var registry:=Registry.new()
    registry.bind(progress)
    var world:=World.new()
    root.add_child(world)
    var total: int=0
    for map_id in MAPS:
        world.map_profile=registry.profile(map_id)
        world.build(3,2)
        var n: int=_inspect(world.root,map_id,"World")
        print("VISUAL_OVERSIZE_COUNT "+map_id+" "+str(n))
        total+=n
    print("VISUAL_OVERSIZE_TOTAL "+str(total))
    world.queue_free()
    if total>0:
        push_error("First-act art scale acceptance failed: "+str(total)+" oversized scene sprites")
        quit(1)
    else:
        print("PASS Act-I live art scale guard: no gigantic props")
        quit(0)
