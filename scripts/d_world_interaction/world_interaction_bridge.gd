extends RefCounted
## Opt-in D integration facade; reads existing world.nodes without changing B/C files.
const Router = preload("res://scripts/d_world_interaction/interaction_router.gd")
const NPC = preload("res://scripts/d_world_interaction/npc_behavior_controller.gd")
const Interior = preload("res://scripts/d_world_interaction/interior_interaction.gd")
const Transition = preload("res://scripts/d_world_interaction/scene_transition.gd")
const Sync = preload("res://scripts/d_world_interaction/world_state_sync.gd")
const Executor = preload("res://scripts/d_world_interaction/world_interaction_executor.gd")
const Presentation = preload("res://scripts/d_world_interaction/world_presentation_adapter.gd")
var npc = NPC.new()
var interiors = Interior.new()
var transitions = Transition.new()
var last_facing: Vector2 = Vector2.DOWN

func set_actor_direction(motion: Vector2) -> void:
    if motion.length_squared()>0.001:
        last_facing=motion.normalized()

func collect(world) -> Array:
    var targets: Array=[]
    if world==null or not is_instance_valid(world):
        return targets
    var main_id: String=str(world.focus_name)
    var side_id: String=str(world.side_focus_name)
    for key in world.nodes:
        var target_id: String=str(key)
        var point: Node=world.nodes[key]
        if not is_instance_valid(point) or not (point is Node2D):
            continue
        var item: Dictionary={"id":target_id,"position":(point as Node2D).position,
            "visible":(point as Node2D).visible,
            "kind":Router.kind_of(target_id,main_id,side_id),
            "range":45.0}
        if target_id==main_id:
            item["range"]=45.0
        elif target_id==side_id:
            item["range"]=38.0
        elif target_id.begins_with("questdoor:"):
            item["range"]=38.0
        elif target_id.begins_with("story_stage_"):
            item["range"]=34.0
        elif target_id.begins_with("building:"):
            item["range"]=55.0
        targets.append(item)
    return targets

func select(world, progress, actor_id: String = "hero") -> Dictionary:
    if world==null or not is_instance_valid(world) or world.locked or not is_instance_valid(world.hero):
        return {}
    var selected: Dictionary=Router.select_target(collect(world),world.hero.position,
        last_facing,world.blocked,str(world.focus_name),str(world.side_focus_name))
    if selected.is_empty():
        return {}
    var saved_world: Dictionary=progress.rpg.get("world",{}) if progress!=null else {}
    var clock: Dictionary=progress.rpg.get("game_clock",{}) if progress!=null else {}
    var map_id: String=str(world.map_profile.get("id",saved_world.get("current_map","")))
    selected["context"]=Router.context(map_id,int(world.chapter),str(selected["id"]),
        str(selected["kind"]),actor_id,int(clock.get("minutes",480)),
        progress.flags if progress!=null else {},str(world.interior_building))
    return selected

## Compatibility bridge: legacy first_act._interact remains sole owner of B/A effects.
## Caller should replace ONLY world.interact() input site after freeze; never call both.
func dispatch_legacy(world, progress) -> Dictionary:
    var chosen: Dictionary=select(world,progress)
    if chosen.is_empty():
        return {"handled":false,"message":"附近没有可以安全互动的目标。"}
    if world.hero.has_method("react"):
        world.hero.call("react")
    world.interacted.emit(str(chosen["id"]))
    return {"handled":true,"target_id":chosen["id"],"context":chosen["context"],
        "delegated_to_legacy":true}

func inspect_home(progress, context: Dictionary, building_id: String, object_id: String,
        owner_present: bool = false) -> Dictionary:
    var preview: Dictionary=interiors.inspect(context,building_id,object_id,progress,owner_present)
    return Executor.commit(progress,preview)

func save_world_snapshot(progress, world) -> bool:
    if progress==null or world==null or not is_instance_valid(world.hero):
        return false
    var map_id: String=str(world.map_profile.get("id",""))
    var clock: Dictionary=progress.rpg.get("game_clock",{})
    var updated: Dictionary=Sync.capture(progress,map_id,int(world.chapter),
        str(world.interior_building),world.hero.position,last_facing,
        int(clock.get("minutes",480)),world.exterior_position,"")
    if updated.is_empty():
        return false
    var previous: Dictionary=progress.rpg.get("world",{}).duplicate(true)
    progress.rpg["world"]=updated
    if not progress.save():
        progress.rpg["world"]=previous
        return false
    return true

## This is a staged transition request, not an automatic B-line scene rewrite.
## D owns the in-flight input lock; B game code still owns actual map loading.
func begin_transition(world, request: Dictionary, now_ms: int) -> Dictionary:
    if world==null or not is_instance_valid(world) or bool(world.locked):
        return {"handled":false,"reason":"world_busy"}
    var result: Dictionary=transitions.begin(request,now_ms)
    if bool(result.get("handled",false)):
        world.locked=true
    return result

func finish_transition(world, now_ms: int, succeeded: bool,
        sound: Node = null) -> Dictionary:
    if world==null or not is_instance_valid(world):
        transitions.abort()
        return {"handled":false,"reason":"world_missing"}
    if not succeeded:
        transitions.abort()
        world.locked=false
        return {"handled":false,"reason":"scene_load_failed"}
    var result: Dictionary=transitions.complete(now_ms)
    world.locked=false
    if bool(result.get("handled",false)) and sound!=null:
        var request: Dictionary=result.get("transition",{})
        var destination: String=str(request.get("to_map",""))
        Presentation.crossfade(sound,destination,str(request.get("mode",""))=="enter")
    return result

func restore_position(progress, world, protected: Dictionary = {}) -> Dictionary:
    if progress==null or world==null or not is_instance_valid(world.hero):
        return {"valid":false,"reason":"invalid_game_state"}
    var map_id: String=str(world.map_profile.get("id",""))
    var layout: Dictionary=world.terrain_layout
    var extent: Vector2i=layout.get("size",Vector2i(72,48))
    var fallback: Vector2=(Vector2(layout.get("spawn",Vector2i(10,23)))+Vector2(0.5,0.5))*32.0
    var outcome: Dictionary=Sync.restore(progress.rpg.get("world",{}),
        map_id,int(world.chapter),str(world.interior_building),
        world.blocked,extent,fallback,protected)
    if bool(outcome.get("valid",false)):
        world.hero.position=outcome["position"]
        if world.has_method("_reveal_nearby"):
            world.call("_reveal_nearby")
    return outcome
