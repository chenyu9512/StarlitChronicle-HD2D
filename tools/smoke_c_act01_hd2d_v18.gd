extends SceneTree
const Geography=preload("res://scripts/world_geography.gd")
const Dressing=preload("res://scripts/c_act01_hd2d_dressing.gd")
const World=preload("res://scripts/first_act_world.gd")
const Coastal=preload("res://scripts/world_coastal_scene.gd")
const ROOT: String="res://assets/art/runtime/act01_hd2d_v18/materials/"
var issues: Array[String]=[]

func verify(ok: bool,message: String) -> void:
    if not ok:
        issues.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _check_live_vegetation(scene: Node2D, layout: Dictionary, map_id: String) -> void:
    var occupied: Dictionary={}
    var inspected: int=0
    for item in scene.authored_sprites.values():
        if not item is Sprite2D or not item.has_meta("vegetation_cell"):
            continue
        var cell: Vector2i=item.get_meta("vegetation_cell")
        inspected+=1
        verify(layout.get("tiles",{}).has(cell),map_id+" tree painted outside ground")
        verify(not layout.get("water_mask",{}).has(cell),map_id+" tree placed in water")
        verify(not layout.get("blocked",{}).has(cell),map_id+" tree placed on collision")
        verify(not occupied.has(cell),map_id+" duplicate tree footprint")
        occupied[cell]=true
        var spawn: Vector2i=layout.get("spawn",Vector2i(-999,-999))
        verify(absi(cell.x-spawn.x)>2 or absi(cell.y-spawn.y)>2,
            map_id+" tree hiding player spawn")
        for section in ["features","gates"]:
            for event in layout.get(section,[]):
                if not event is Dictionary:
                    continue
                var anchor: Variant=event.get("cell",null)
                if anchor is Vector2i:
                    verify(absi(cell.x-anchor.x)>2 or absi(cell.y-anchor.y)>2,
                        map_id+" tree hiding "+section+" event")
    if map_id!="map_coast_04":
        verify(inspected>0,map_id+" lost all distinct live vegetation")


func _run() -> void:
    var geo=Geography.new()
    for map_id in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04","map_coast_05"]:
        var layout: Dictionary=geo.layout(map_id,1)
        var base_row: int=1 if map_id=="map_coast_01" else (0 if map_id in ["map_coast_02","map_coast_03"] else 2)
        var checked_floor: int=0
        var checked_cave_routes: int=0
        for raw in layout.get("tiles",{}).keys():
            var existing: Vector2i=layout["tiles"][raw]
            var painted: Vector2i=World.first_act_visual_ground(map_id,existing)
            if map_id=="map_coast_04":
                if existing.y==3:
                    verify(painted==Vector2i(existing.x,6),
                        "Cavern route still draws urban cobbles")
                    checked_cave_routes+=1
                elif existing.y in [0,1,5]:
                    verify(painted==Vector2i(existing.x,2),
                        "Cavern ground still draws sand, grass or wooden floor")
                    checked_floor+=1
                else:
                    verify(painted==existing,"Cavern changed unrelated tile role")
            elif existing.y in [0,1]:
                var expected_row: int=existing.y if map_id=="map_coast_01" else base_row
                verify(painted.y==expected_row,map_id+" has mixed grass/sand checkerboard")
                checked_floor+=1
            else:
                verify(painted==existing,map_id+" changed authored road/feature row")
        verify(checked_floor>10 or map_id=="map_coast_04",
            map_id+" lacks authored ground to review")
        if map_id=="map_coast_04":
            verify(checked_cave_routes>20,"Cavern lacks a tested stone route")
        var collision: Dictionary=layout.get("blocked",{}).duplicate(true)
        var ground: Dictionary=layout.get("tiles",{}).duplicate(true)
        var host:=Node2D.new()
        host.y_sort_enabled=true
        root.add_child(host)
        var dressing=Dressing.new()
        host.add_child(dressing)
        dressing.configure(map_id,layout,host)
        verify(dressing.placed.size()>=2,map_id+" fewer than two imported scenery objects")
        for sprite in dressing.placed.values():
            var point: Vector2i=sprite.get_meta("map_cell")
            # Cavern props may sit ON the already-solid rock perimeter,
            # which is correct; no new collision cell may be created.
            verify(not collision.has(point) or map_id=="map_coast_04",
                map_id+" non-cavern scenery placed on collision")
            verify(not layout.get("water_mask",{}).has(point),map_id+" scenery placed in water")
            verify(bool(sprite.get_meta("visual_only",false)),map_id+" invalid nonvisual art")
            verify(sprite.texture!=null,map_id+" texture did not import")
            if map_id=="map_coast_04" and collision.has(point) and str(sprite.get_meta("art_kind","")) in ["rock-bank","cliff-ledge"]:
                verify(bool(sprite.get_meta("wall_backdrop",false)) and sprite.z_index<3,
                    "Cavern wall rock now obscures the playable actor")
        verify(collision==layout.get("blocked",{}),map_id+" modified collision")
        verify(ground==layout.get("tiles",{}),map_id+" modified ground geometry")
        host.free()
    # Chapter 1's canonical town landmark is a broad old oak.
    # A cherry blossom looked superficially pretty but mismatched the
    # authored "dew_round_square_oak" site identity.
    var village:=Coastal.new()
    root.add_child(village)
    village.configure("map_coast_01",geo.layout("map_coast_01",1))
    var village_props: Dictionary=village.hd2d_dressing.placed
    var oak_found: bool=false
    for prop in village_props.values():
        if str(prop.get_meta("art_kind",""))=="great-oak":
            var src: String=str(prop.get_meta("source_path",""))
            verify(src.ends_with("/great-oak.png"),"Dew Village oak source role drift")
            verify(prop.texture!=null,"Dew Village oak has no imported artwork")
            oak_found=true
        verify(str(prop.get_meta("art_kind",""))!="cherry-tree",
            "Cherry tree was reintroduced in canonical oak plaza")
    verify(oak_found,"Dew Village great oak not actually placed in game")
    village.free()
    for mat in ["beach-sand","town-grass","cliff-rock","cobbles","planks","marsh","harbor-ground","water-sea","water-shallow","water-foam","water-brine"]:
        verify(ResourceLoader.exists(ROOT+mat+".png"),"missing runtime material "+mat)
    var stage=Coastal.new()
    root.add_child(stage)
    stage.configure("map_coast_01",geo.layout("map_coast_01",1))
    verify(stage.hd2d_dressing!=null and stage.hd2d_dressing.placed.size()>=2,"Live CoastalScene not wired to V18")
    stage.free()
    # Inspect the ACTUAL display scale produced by CoastalScene, not just
    # the file path: previously a 337x522 genuine lighthouse was shrunk
    # to an unreadable street-lamp-sized sprite in real screenshots.
    var lighthouse:=Coastal.new()
    root.add_child(lighthouse)
    lighthouse.configure("map_coast_05",geo.layout("map_coast_05",6))
    var beacon: Sprite2D=lighthouse.authored_sprites.get("lighthouse_landmark") as Sprite2D
    verify(beacon!=null,"Ch6 canonical lighthouse art absent")
    if beacon!=null and beacon.texture!=null:
        var real_size: Vector2=Vector2(beacon.texture.get_size())*beacon.scale
        verify(real_size.x>=190.0 and real_size.y>=250.0,
            "Ch6 lighthouse is still a tiny prop rather than a story landmark")
    lighthouse.free()
    # Inspect the instantiated map artwork in each region: a source path alone
    # cannot prove the tree stays out of deep water or off a story trigger.
    for map_id in ["map_coast_01","map_coast_02","map_coast_03","map_coast_04","map_coast_05"]:
        var live_layout: Dictionary=geo.layout(map_id,1)
        var live_scene:=Coastal.new()
        root.add_child(live_scene)
        live_scene.configure(map_id,live_layout)
        _check_live_vegetation(live_scene,live_layout,map_id)
        if map_id=="map_coast_05":
            var oak: Sprite2D=live_scene.authored_sprites.get("lighthouse_oak") as Sprite2D
            verify(oak!=null and str(oak.get_meta("art_kind",""))=="saltwind_oak",
                "Ch6 lighthouse oak still uses a pine or unrelated image")
        live_scene.free()
    if issues.is_empty():
        print("PASS V18: five maps load genuine Golden Horizon HD-2D resources, roads and collision immutable")
        quit(0)
    else:
        for failure in issues:
            push_error(failure)
        quit(1)
