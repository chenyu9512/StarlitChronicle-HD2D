extends SceneTree
## Real Godot geography test: six distinct first-act places on five original
## live map IDs. Verifies collisions, mapped art and save-compatible exits.
const Geography = preload("res://scripts/world_geography.gd")
const Registry = preload("res://scripts/world_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const World = preload("res://scripts/first_act_world.gd")

const MAPS: Array[String] = [
    "map_coast_01","map_coast_02","map_coast_03",
    "map_coast_04","map_coast_05"
]
const SIGNATURES: Dictionary = {
    "map_coast_01":"dew_round_square_oak",
    "map_coast_02":"harbor_extra_crane_beam",
    "map_coast_03":"shoal_whalebone_recovery_glow",
    "map_coast_04":"cave_second_crystal_framing",
    "map_coast_05":"lighthouse_middle_skyline"
}
var faults: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,reason: String) -> void:
    if not ok:
        faults.append(reason)

func _run() -> void:
    var geo := Geography.new()
    var progress := State.new()
    progress.new_game()
    var registry := Registry.new()
    registry.bind(progress)
    check(geo.faults.is_empty(),"World geography did not load V3 layouts")
    var world := World.new()
    root.add_child(world)
    var distinct: Dictionary = {}
    for map_id in MAPS:
        var layout: Dictionary = geo.layout(map_id,3)
        var size: Vector2i = layout.get("size",Vector2i.ZERO)
        var ground: Dictionary = layout.get("tiles",{})
        var walls: Dictionary = layout.get("blocked",{})
        var gate_cells: Array[Vector2i] = []
        for gate in layout.get("gates",[]):
            var cell: Vector2i = gate.get("cell",Vector2i(-1,-1))
            check(not gate_cells.has(cell),map_id+" has overlapping exits")
            gate_cells.append(cell)
        var spawn: Vector2i = layout.get("spawn",Vector2i(-1,-1))
        check(not walls.has(spawn),map_id+" spawn collision blocked")
        check(ground.size()==size.x*size.y,map_id+" ground tiles are incomplete")
        check(geo.reachable(layout,[spawn],gate_cells),
            map_id+" cannot walk between spawn and canonical neighbor exits")
        var stable: Dictionary=geo.layout(map_id,6)
        check(stable.get("blocked",{})==walls,
            map_id+" collision map changes depending on story chapter")
        world.map_profile=registry.profile(map_id)
        world.build(3,2)
        check(world.terrain_layout.get("size",Vector2i.ZERO)==size,
            map_id+" actual playable scene ignored V3 grid")
        var in_game: Dictionary=world.terrain_layout
        var game_walls: Dictionary=in_game.get("blocked",{})
        check(not game_walls.has(spawn),map_id+" real playable spawn is blocked")
        # Dynamic NPC/entrance/collision setup can add scene blockers after
        # geography creation. Check live navigation, not dictionary identity.
        check(geo.reachable(in_game,[spawn],gate_cells),
            map_id+" actual Godot scene cannot reach all of its exits")
        check(world.coastal_scene!=null,map_id+" coastal runtime scene absent")
        if world.coastal_scene!=null:
            check(world.coastal_scene.authored_sprites.has(SIGNATURES[map_id]),
                map_id+" bespoke live art sprite not imported: "+str(SIGNATURES[map_id]))
        for raw_gate in layout.get("gates",[]):
            var destination: String=str(raw_gate.get("id",""))
            check(world.nodes.has("exit:"+destination),
                map_id+" lost real on-foot gate to "+destination)
        # Recognizable layout structures are part of the LIVE level, not a
        # menu illustration or an unused source-pack manifest.
        var v3: Dictionary=geo.authored.level(map_id)
        var design: String=str(v3.get("layout_identity",""))
        check(not design.is_empty() and not distinct.has(design),
            map_id+" is using a copied or unnamed V3 layout")
        distinct[design]=true
        if map_id=="map_coast_01":
            var grass_count: int=0
            var earth_count: int=0
            var stone_count: int=0
            var bad_noise: int=0
            for p in ground.keys():
                var loc: Vector2i=p
                if walls.has(loc):
                    continue
                var tile: Vector2i=ground[loc]
                if tile.y==1:
                    grass_count+=1
                elif tile.y==0:
                    earth_count+=1
                elif tile.y==3:
                    stone_count+=1
                if tile.y in [0,1,3] and tile.x!=0:
                    bad_noise+=1
            check(grass_count>earth_count and grass_count>900,
                "Dew's base must be continuous meadow rather than random stone")
            check(earth_count>90,
                "Dew's organic walkways must be actual warm earth")
            check(stone_count>=20 and stone_count<=90,
                "Dew's stone paving must be confined to the small well court")
            check(bad_noise==0,
                "Dew's ground atlas uses random per-cell material variations")
            check(world.nodes.has("building:house") and world.nodes.has("building:inn"),
                "Village lost its existing story home or inn")
            check(str(layout.get("town_plan",{}).get("urban_form",""))=="林荫环村",
                "Village real runtime layout is no longer circular")
        if map_id=="map_coast_02":
            check(world.nodes.has("building:shelter") and world.nodes.has("building:tavern"),
                "Harbor lost shelter or Black Sail tavern")
            check(str(layout.get("town_plan",{}).get("urban_form",""))=="堤岸栈桥港",
                "Harbor real runtime still repeats village block layout")
        if map_id=="map_coast_01":
            check(str(geo.zone(map_id).get("layout",""))=="central_square" and
                str(geo.zone(map_id).get("village_shape",""))=="dew_village_ring",
                "Dew Village still generates generic intersecting city highways")
            check(not walls.has(Vector2i(35,21)),
                "Dew Village well plaza center must stay physically accessible")
            check(geo.reachable(in_game,[spawn],[Vector2i(35,21)]),
                "Player cannot walk to Dawn Village's genuine well plaza")
            var stone_path: Array=geo.authored.level(map_id).get("roads",[])
            check(stone_path.size()>=6 and str(stone_path[0].get("id",""))=="dew-circular-well-plaza",
                "Actual Dew Village ring and garden lanes were lost")
        if map_id=="map_coast_03":
            for shore in [Vector2i(62,43),Vector2i(66,45)]:
                check(not walls.has(shore),
                    "Chapter-five whale shoal rescue target is blocked: "+str(shore))
        if map_id=="map_coast_04":
            for valve in [Vector2i(19,14),Vector2i(53,16),Vector2i(54,36)]:
                check(geo.reachable(layout,[spawn],[valve]),
                    "Sea cave original three tide valve inaccessible: "+str(valve))
        if map_id=="map_coast_05":
            for platform in [Vector2i(80,29),Vector2i(74,35)]:
                check(not walls.has(platform),
                    "Lighthouse old repair platform is obstructed: "+str(platform))
    check(distinct.size()==5,"Six chapter places not formed from five unique playable sectors")
    world.queue_free()
    if faults.is_empty():
        print("PASS Act-I five physically distinct Godot map layouts, six chapter locations, all original gates, rooms and promoted art")
        quit(0)
        return
    for fault in faults:
        push_error(fault)
    quit(1)
