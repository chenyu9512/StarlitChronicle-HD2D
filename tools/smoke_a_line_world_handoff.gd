extends SceneTree
## A-line deterministic contract tests; zero cheats, no full campaign run.
const Handoff = preload("res://scripts/battle_world_handoff.gd")
const Encounter = preload("res://scripts/encounter_registry.gd")
const State = preload("res://scripts/first_act_state.gd")
const RPG = preload("res://scripts/rpg_core.gd")
const Battle = preload("res://scripts/first_act_battle.gd")

class Hero:
    extends Node2D
    var facing: int = 2

class MockWorld:
    extends Node2D
    var hero: Hero
    var companion: Node2D
    var third: Node2D
    var fourth: Node2D
    var chapter: int = 8
    var map_profile: Dictionary = {"id":"map_coast_01","settlement":false}
    var interior_building: String = ""
    var terrain_layout: Dictionary = {"spawn":Vector2i(10,23)}
    var movement: Vector2 = Vector2(1,0)
    var encounter_meter: float = 300.0
    var next_encounter: float = 500.0
    var locked: bool = true
    var walls: Dictionary = {}
    var reveals: int = 0

    func _blocked(position: Vector2) -> bool:
        return walls.has(Vector2i(floori(position.x/32.0),floori(position.y/32.0)))

    func _reveal_nearby() -> void:
        reveals+=1

class MockController:
    extends Node
    var world: MockWorld
    var no_encounters: bool = false
    var finish_calls: int = 0
    func _battle_finished(_won: bool, _xp: int, _gold: int) -> void:
        finish_calls+=1

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)

func mock() -> MockWorld:
    var world := MockWorld.new()
    root.add_child(world)
    world.hero=Hero.new()
    world.add_child(world.hero)
    world.hero.position=Vector2(610,480)
    world.companion=Node2D.new()
    world.add_child(world.companion)
    return world

func context(world: MockWorld) -> Dictionary:
    return {"chapter":world.chapter,"trigger_id":"boss.ch008/crisis","width_tiles":72,"height_tiles":48}

func _run() -> void:
    var world := mock()
    var safe := context(world)
    safe["settlement"]=true
    check(not bool(Handoff.eligible("random",safe).get("ok",true)),"town must suppress random encounter")
    safe.erase("settlement")
    safe["interior_building"]="building_01"
    check(not bool(Handoff.eligible("random",safe).get("ok",true)),"interior must suppress encounter")
    safe.erase("interior_building")
    safe["dialogue_open"]=true
    check(not bool(Handoff.eligible("random",safe).get("ok",true)),"dialogue must suppress encounter")
    safe.erase("dialogue_open")
    safe["cinematic"]=true
    check(not bool(Handoff.eligible("boss",safe).get("ok",true)),"cutscene must suppress encounter")
    safe.erase("cinematic")
    safe["already_battling"]=true
    check(not bool(Handoff.eligible("boss",safe).get("ok",true)),"duplicate boss must be rejected")
    safe.erase("already_battling")
    safe["boss_resolved"]=true
    check(not bool(Handoff.eligible("boss",safe).get("ok",true)),"resolved boss must be rejected")
    safe.erase("boss_resolved")
    safe["no_encounters"]=true
    check(not bool(Handoff.eligible("random",safe).get("ok",true)),"encounters disabled must be honored")
    safe.erase("no_encounters")
    check(bool(Handoff.eligible("random",safe).get("ok",false)),"wilderness encounter blocked")
    check(bool(Handoff.eligible("boss",safe).get("ok",false)),"valid story boss blocked")
    var original := world.hero.position
    var transaction := Handoff.new()
    check(bool(transaction.begin(world,"random",safe).get("ok",false)),"begin random encounter")
    check(not bool(transaction.begin(world,"random",safe).get("ok",true)),"double begin must fail")
    var checkpoint: Dictionary=transaction.checkpoint()
    check(str(checkpoint.get("map_id",""))=="map_coast_01","map identity missing")
    check(int(checkpoint.get("facing",-1))==2,"facing not captured")
    world.hero.position+=Vector2(256,64)
    world.hero.facing=1
    check(bool(transaction.mark_result(true).get("ok",false)),"mark victory")
    check(not bool(transaction.mark_result(true).get("ok",true)),"double settlement accepted")
    var recovery: Dictionary=transaction.restore(world)
    check(bool(recovery.get("ok",false)),"victory restore rejected")
    check(world.hero.position.distance_to(original)<0.01,"victory did not restore exact position")
    check(world.hero.facing==2,"facing was not restored")
    check(world.movement==Vector2.ZERO,"pending directional input persisted")
    check(world.encounter_meter<=-Handoff.WIN_GRACE_PIXELS,"victory grace distance missing")
    check(world.locked,"handoff incorrectly unlocked controller input")
    check(not bool(transaction.restore(world).get("ok",true)),"duplicate restore accepted")
    var no_room := Handoff.new()
    var bad_world := mock()
    bad_world.map_profile["settlement"]=true
    check(not bool(no_room.begin(bad_world,"random",{"chapter":8,"settlement":true}).get("ok",true)),"settlement not rejected at begin")
    var defeat := Handoff.new()
    check(bool(defeat.begin(world,"boss",safe).get("ok",false)),"begin boss encounter")
    world.walls[Vector2i(10,23)]=true
    world.walls[Vector2i(9,23)]=true
    world.walls[Vector2i(10,22)]=true
    world.walls[Vector2i(11,23)]=true
    world.walls[Vector2i(10,24)]=true
    check(bool(defeat.mark_result(false,"nonlethal").get("ok",false)),"boss defeat settlement rejected")
    var defeat_result: Dictionary=defeat.restore(world)
    check(bool(defeat_result.get("ok",false)),"blocked spawn could not recover")
    check(not world._blocked(world.hero.position),"recovery spawned player in a wall")
    check(world.encounter_meter<=-Handoff.DEFEAT_GRACE_PIXELS,"defeat grace distance missing")
    check(world.companion.position.distance_to(world.hero.position)<60.0,"party did not regroup on defeat")
    check(world.hero.facing==2,"defeat facing was not restored")
    var move_map := Handoff.new()
    var new_context := context(world)
    check(bool(move_map.begin(world,"boss",new_context).get("ok",false)),"begin cross-map boss")
    var preserved := world.hero.position
    world.map_profile["id"]="map_forge_01"
    world.hero.position=Vector2(480,480)
    check(bool(move_map.mark_result(true,"rescued").get("ok",false)),"mark rescued")
    var moved_result: Dictionary=move_map.restore(world)
    check(bool(moved_result.get("ok",false)),"cross-map resolution rejected")
    check(not bool(moved_result.get("same_map",true)),"map change went unnoticed")
    check(world.hero.position==Vector2(480,480),"cross-map victory wrongly teleported to previous map")
    check(str(moved_result.get("boss_settlement",""))=="rescued","nonlethal settlement lost")
    world.map_profile["id"]="map_coast_01"
    var reg := Encounter.new()
    var state := State.new()
    state.new_game()
    var rpg := RPG.new()
    rpg.bind(state)
    var battle := Battle.new()
    root.add_child(battle)
    battle.game_core=rpg
    battle.encounter_registry=reg
    var session: Dictionary=battle.prepare_world_handoff(world,{"chapter":2,"trigger_id":"boss.ch002/crisis"},true)
    check(bool(session.get("ok",false)),"battle rejected valid handoff")
    battle.encounter_data={"enemy_id":"boss.ch002","display_name":"雾潮寄生体"}
    battle.start(state,2,true)
    battle._finish(true)
    check(bool(battle.last_world_handoff_result.get("ok",false)),"battle did not settle world handoff")
    check(not bool(battle.world_handoff.mark_result(true).get("ok",true)),"battle settlement counted twice")
    check(bool(battle.handoff_to_world(world).get("ok",false)),"battle world restore failed")
    check(not bool(battle.handoff_to_world(world).get("ok",true)),"battle world restore counted twice")
    check(state.gold==80,"handoff changed player economy")
    var parent := MockController.new()
    root.add_child(parent)
    var auto_world := MockWorld.new()
    parent.add_child(auto_world)
    parent.world=auto_world
    auto_world.hero=Hero.new()
    auto_world.add_child(auto_world.hero)
    auto_world.hero.position=Vector2(512,512)
    auto_world.hero.facing=3
    auto_world.companion=Node2D.new()
    auto_world.add_child(auto_world.companion)
    var automatic := Battle.new()
    parent.add_child(automatic)
    automatic.game_core=rpg
    automatic.encounter_registry=reg
    automatic.encounter_data={"enemy_id":"boss.ch002","display_name":"雾潮寄生体"}
    automatic.start(state,2,true)
    check(automatic.world_handoff!=null and automatic.world_handoff.active,"automatic host snapshot was not taken")
    auto_world.hero.position=Vector2(700,600)
    auto_world.hero.facing=1
    automatic.completed.connect(parent._battle_finished)
    automatic._finish(true)
    check(parent.finish_calls==1,"host completion was not called exactly once")
    check(auto_world.hero.position==Vector2(512,512),"automatic integration did not restore position before completion")
    check(auto_world.hero.facing==3,"automatic integration did not restore facing")
    check(bool(automatic.last_world_handoff_result.get("ok",false)),"automatic integration did not finalize handoff")
    if failures.is_empty():
        print("PASS: battle/world eligibility, snapshot, idempotency, spawn fallback, cooldown, map change, boss settlement")
        quit(0)
    for problem in failures:
        push_error(problem)
    quit(1)
