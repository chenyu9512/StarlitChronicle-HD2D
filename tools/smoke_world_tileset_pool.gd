extends SceneTree
## D/C rendering batch: atlas identity, 32px grid, bounded eviction,
## world reentry and no changes to authoritative map cells or save flags.
const Pool = preload("res://scripts/world_tileset_pool.gd")
const World = preload("res://scripts/first_act_world.gd")
const State = preload("res://scripts/first_act_state.gd")
const Registry = preload("res://scripts/world_registry.gd")
const GROUND: String = "res://assets/art/tilesets/coast_ground.png"
const WATER: String = "res://assets/art/tilesets/coast_water.png"
const WALL: String = "res://assets/art/interiors/morning_dew_inn/inn_tileset.svg"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)

func _run() -> void:
    Pool.reset()
    var paths: Array[String] = [GROUND,WATER]
    var first: TileSet = Pool.shared(paths)
    var repeat: TileSet = Pool.shared(paths)
    check(first!=null and first==repeat,"Identical source pairing rebuilt a TileSet")
    if first!=null:
        check(first.tile_size==Vector2i(32,32),"Tile dimension changed")
        check(first.get_source_count()==2,"Land and water source IDs changed")
        check(first.has_source(0) and first.has_source(1),"Source 0/1 absent")
        var ground: TileSetAtlasSource=first.get_source(0) as TileSetAtlasSource
        var sea: TileSetAtlasSource=first.get_source(1) as TileSetAtlasSource
        check(ground!=null and sea!=null,"Atlas source types invalid")
        if ground!=null:
            check(ground.has_tile(Vector2i(7,7)),"Last ground tile missing")
        if sea!=null:
            check(sea.has_tile(Vector2i(7,7)),"Last water tile missing")
    var wall_paths: Array[String]=[WALL]
    var walls: TileSet=Pool.shared(wall_paths,8,7,1)
    check(walls!=null,"Wall-edge atlas not created")
    if walls!=null:
        var source: TileSetAtlasSource=walls.get_source(0) as TileSetAtlasSource
        check(source!=null and source.has_tile(Vector2i(7,7)),
            "Wall edging lost row-seven address")
        check(not source.has_tile(Vector2i(0,0)),
            "Wall edging unexpectedly exposed the whole source atlas")
    check(int(Pool.stats().get("hits",0))>=1,"TileSet reuse hit was not recorded")

    var state=State.new()
    state.new_game()
    var router=Registry.new()
    router.bind(state)
    var world=World.new()
    world.map_profile=router.profile()
    root.add_child(world)
    var old_flags: Dictionary=state.flags.duplicate(true)
    world.build(1,2)
    var active: TileSet=world.layer.tile_set
    var initial_count: int=world.layer.get_used_cells().size()
    world.build(1,2)
    check(world.layer.tile_set==active,"Reentering identical map rebuilt its TileSet")
    check(world.layer.get_used_cells().size()==initial_count,
        "Reuse changed actual TileMapLayer cell count")
    check(state.flags==old_flags,"Visual cache altered story flags")

    # Evict atlas definitions in this process, but the active TileMapLayer
    # must still retain its own reference to the resource and remain usable.
    for columns in range(1,9):
        for rows in range(1,3):
            Pool.shared(wall_paths,columns,0,rows)
    check(int(Pool.stats().get("entries",100))<=Pool.MAX_ENTRIES,
        "Texture atlas cache is unbounded")
    check(int(Pool.stats().get("evictions",0))>0,"LRU did not evict")
    check(world.layer.tile_set!=null and world.layer.get_used_cells().size()==initial_count,
        "LRU eviction destroyed an active world map")
    if failures.is_empty():
        print("PASS rendering: immutable reused TileSets, 32px atlas, bounded LRU, stable map and save")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
