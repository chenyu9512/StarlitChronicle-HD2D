extends SceneTree
## Opt-in headless D regression. Test no cheats, no actual player save and no map mutation.
const Router = preload("res://scripts/d_world_interaction/interaction_router.gd")
const Transition = preload("res://scripts/d_world_interaction/scene_transition.gd")
const Sync = preload("res://scripts/d_world_interaction/world_state_sync.gd")
const NPC = preload("res://scripts/d_world_interaction/npc_behavior_controller.gd")
const Executor = preload("res://scripts/d_world_interaction/world_interaction_executor.gd")
var errors: Array[String] = []

class FakeState:
    extends RefCounted
    var rpg: Dictionary={"world":{}}
    var flags: Dictionary={}
    var inventory: Dictionary={}
    var gold: int=10
    var fail_save: bool=false
    func _pack() -> Dictionary:
        return {"rpg":rpg.duplicate(true),"flags":flags.duplicate(true),
            "inventory":inventory.duplicate(true),"gold":gold}
    func save() -> bool:
        return not fail_save
    func restore_snapshot(data: Dictionary) -> bool:
        rpg=data["rpg"].duplicate(true)
        flags=data["flags"].duplicate(true)
        inventory=data["inventory"].duplicate(true)
        gold=int(data["gold"])
        return true

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, description: String) -> void:
    if not value:
        errors.append(description)

func _run() -> void:
    var origin: Vector2=Vector2(16,48)
    var walls: Dictionary={Vector2i(1,1):true}
    var options: Array=[
        {"id":"building:inn","position":Vector2(32,48),"kind":"door"},
        {"id":"key_npc","position":Vector2(46,48),"kind":"main"}]
    check(Router.select_target(options,origin,Vector2.RIGHT,{}).get("id","")=="key_npc",
        "main objective must beat neighboring door")
    check(Router.select_target([{"id":"citizen:abc","position":Vector2(80,48),"kind":"npc"}],
        origin,Vector2.RIGHT,walls).is_empty(),"wall cannot be talked through")
    check(Router.select_target([{"id":"citizen:abc","position":Vector2(44,48),"kind":"npc"}],
        origin,Vector2.LEFT,{}).is_empty(),"NPC behind facing cannot grab input")
    check(Router.select_target([{"id":"building:inn","position":Vector2(40,48),"kind":"door"}],
        origin,Vector2.RIGHT,{}).get("id","")=="building:inn","front door not selectable")
    var t=Transition.new()
    var request: Dictionary={"id":"enter:inn","mode":"enter","to_map":"map_coast_01","indoor_id":""}
    check(bool(t.begin(request,1000).get("handled",false)),"first enter denied")
    check(not bool(t.begin(request,1001).get("handled",false)),"transition double-trigger")
    check(bool(t.complete(1100).get("handled",false)),"transition cannot finish")
    check(not bool(t.begin(request,1120).get("handled",false)),"cooldown bypass")
    check(bool(t.begin(request,1500).get("handled",false)),"cooldown never released")
    t.abort()
    check(not bool(t.begin({"id":"badgate","mode":"gate","to_map":"map_coast_02",
        "neighbors":["map_coast_03"],"unlocked":true},2000).get("handled",false)),
        "non-neighbor traversal permitted")
    var landing: Dictionary=Transition.safe_spawn(Vector2(48,48),{Vector2i(1,1):true},
        Vector2i(14,14),{})
    check(bool(landing.get("valid",false)) and landing.get("cell",Vector2i.ZERO)!=Vector2i(1,1),
        "blocked respawn not relocated")
    check(NPC.safe_follower_position(Vector2(48,48),Vector2(80,48),
        {Vector2i(2,1):true},{},Vector2i(14,14),1.0)==Vector2(48,48),
        "follower stepped into occupied furniture")
    var s=FakeState.new()
    var stored: Dictionary=Sync.capture(s,"map_coast_01",2,"",Vector2(110,100),
        Vector2.DOWN,680,Vector2(50,50),"inn")
    var restored: Dictionary=Sync.restore(stored,"map_coast_01",2,"",{},
        Vector2i(20,20),Vector2(144,144))
    check(bool(restored.get("valid",false)) and restored.get("source","")=="v1",
        "D snapshot not restored")
    var old: Dictionary={"player_checkpoint":{"map_id":"map_coast_01",
        "chapter":2,"indoor_building":"","xy":[110.0,100.0]}}
    check(Sync.restore(old,"map_coast_01",2,"",{},Vector2i(20,20),
        Vector2(144,144)).get("source","")=="legacy","legacy V3 checkpoint broken")
    var reward: Dictionary={"handled":true,"event_id":"d.test.001","effects":[
        {"type":"add_gold","amount":20}],"message":"Found coins"}
    check(bool(Executor.commit(s,reward).get("applied",false)) and s.gold==30,
        "first reward not committed")
    check(not bool(Executor.commit(s,reward).get("applied",true)) and s.gold==30,
        "same reward paid twice")
    s.fail_save=true
    var reward2: Dictionary={"handled":true,"event_id":"d.test.002","effects":[
        {"type":"add_item","item_id":"item_herb_01","count":2}]}
    check(not bool(Executor.commit(s,reward2).get("handled",true)) and s.inventory.is_empty(),
        "failed save did not roll back inventory")
    s.fail_save=false
    check(bool(Executor.commit(s,reward2).get("applied",false))
        and int(s.inventory.get("item_herb_01",0))==2,
        "retry after save failure did not commit exactly once")
    if errors.is_empty():
        print("PASS D world interaction: arbitration, LOS, transitions, respawn, legacy saves, one-shot rewards")
        quit(0)
    else:
        for problem in errors:
            push_error(problem)
        quit(1)
