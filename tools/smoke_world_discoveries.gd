extends SceneTree
## One-time authored discoveries: forty valid maps, 120 distinct events, and save-safe in-game rewards.
const Geo = preload("res://scripts/world_geography.gd")
const Discovery = preload("res://scripts/world_discoveries.gd")
const Game = preload("res://scripts/first_act.gd")
const State = preload("res://scripts/first_act_state.gd")
var errors: Array[String] = []

func expect(value: bool,message: String) -> void:
    if not value:
        errors.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var atlas = Geo.new()
    var discovery = Discovery.new()
    expect(discovery.issues.is_empty(),"Discovery registry validation: "+str(discovery.issues))
    expect(discovery.maps.size()==40,"Missing one or more independent discovery maps")
    var event_count: int = 0
    var text_signatures: Dictionary = {}
    for map_id in discovery.maps.keys():
        var records: Array = discovery.entries(str(map_id))
        expect(records.size()==3,"Expected three authored encounters on "+str(map_id))
        var spatial: Dictionary = atlas.layout(str(map_id),3)
        var stops: Array[Vector2i] = []
        for record in records:
            event_count += 1
            var cell: Array = record.get("cell",[])
            if cell.size()!=2:
                continue
            var pos: Vector2i = Vector2i(int(cell[0]),int(cell[1]))
            stops.append(pos)
            expect(not text_signatures.has(str(record.get("text",""))),"Repeated event writing: "+str(map_id))
            text_signatures[str(record.get("text",""))]=true
            expect(not (spatial.get("blocked",{}) as Dictionary).has(pos),"Discovery marker occupies impassable terrain: "+str(map_id)+":"+str(record.get("id","")))
        expect(atlas.reachable(spatial,[spatial.get("spawn",Vector2i.ZERO)],stops),"Unreachable staged discovery: "+str(map_id))
    expect(event_count==120,"Expected 120 inspect/unlock/reward interactions")
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.progress.chapter=1
    game.world_router.sync_chapter(1)
    game._enter_location()
    game.busy=false
    game.world.locked=false
    var map_id: String = game.world_router.current_map()
    expect(map_id=="map_coast_01","Starter exploration map changed")
    for name in ["trace","mechanism","cache"]:
        expect(game.world.nodes.has("discovery:"+name),"Playable map missing discovery world node "+name)
    var cache: Dictionary = discovery.event(map_id,"cache")
    var reward: Dictionary = cache.get("reward",{})
    var old_gold: int = game.progress.gold
    var item_id: String = str(reward.get("item_id",""))
    var old_inventory: int = int(game.progress.inventory.get(item_id,0))
    game._interact("discovery:cache")
    expect(game.progress.gold==old_gold,"Cache was opened without both prior investigations")
    game._interact("discovery:mechanism")
    expect(not bool(game.progress.flags.get(discovery.flag(map_id,"mechanism"),false)),"Mechanism bypassed clue discovery")
    game._interact("discovery:trace")
    expect(bool(game.progress.flags.get(discovery.flag(map_id,"trace"),false)),"Investigation was not recorded")
    game._interact("discovery:trace")
    expect(int(game.progress.rpg.get("event_counters",{}).get("world_discovery",0))==1,"Repeated clue generated a duplicate event")
    game._interact("discovery:mechanism")
    game._interact("discovery:cache")
    expect(game.progress.gold==old_gold+int(reward.get("gold",0)),"Cache grant missing or incorrect")
    expect(int(game.progress.inventory.get(item_id,0))==old_inventory+int(reward.get("amount",0)),"Cache reward not in party inventory")
    var once_gold: int = game.progress.gold
    game._interact("discovery:cache")
    expect(game.progress.gold==once_gold,"One-time cache could be farmed")
    var saved = State.new()
    expect(saved.restore_snapshot(game.progress._pack()),"Discovery save format rejected")
    expect(bool(saved.flags.get(discovery.flag(map_id,"cache"),false)),"Completed discovery missing after restoring save")
    if errors.is_empty():
        print("PASS: 40 unique-map discovery chains, 120 walkable authored events, ordering, inventory reward, anti-farming, save restore")
        quit(0)
    else:
        for problem in errors:
            push_error(problem)
        quit(1)
