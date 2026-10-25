extends SceneTree
## V7 towns: eleven authored neighborhoods with real schedules, playable sites and persistent participation.
const TownEcology = preload("res://scripts/world_town_ecology.gd")
const Geography = preload("res://scripts/world_geography.gd")
const TownDirector = preload("res://scripts/town_director.gd")
const World = preload("res://scripts/first_act_world.gd")
const State = preload("res://scripts/first_act_state.gd")
const Game = preload("res://scripts/first_act.gd")
var errors: Array[String] = []

func check(value: bool,message: String) -> void:
    if not value:
        errors.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var towns = TownEcology.new()
    var director = TownDirector.new()
    var geo = Geography.new()
    check(towns.issues.is_empty(),"Invalid authored neighborhood events: "+str(towns.issues))
    check(towns.towns.size()==11,"Missing at least one settlement")
    var total: int = 0
    var titles: Dictionary = {}
    for map_id in towns.towns.keys():
        var id: String = str(map_id)
        var spec: Dictionary = towns.config(id)
        var entry: Dictionary = director.plan(id)
        check(not entry.is_empty(),"Ecology town lacks a local street plan: "+id)
        check(not titles.has(str(spec.get("activity",""))),"Community event repeats another town: "+id)
        titles[str(spec.get("activity",""))]=true
        var layout: Dictionary = geo.layout(id,5)
        var town_scene = World.new()
        root.add_child(town_scene)
        town_scene.map_profile = {"id":id,"region_id":"region_"+id.split("_")[1],"kind":"town","settlement":true}
        town_scene.build(5,3)
        var targets: Array[Vector2i] = []
        for event in towns.entries(id):
            total += 1
            var name: String = "townlife:"+str(event.get("id",""))
            check(town_scene.nodes.has(name),"Missing site in actual world map: "+id+"/"+name)
            if town_scene.nodes.has(name):
                var pos: Vector2i = Vector2i(town_scene.nodes[name].position/32.0)
                targets.append(pos)
                check(not (layout.get("blocked",{}) as Dictionary).has(pos),"Site is on a wall: "+id+"/"+name)
            check(towns.is_open(event,int(event.get("open",6))),"Site closed at its scheduled start: "+id)
            check(not towns.is_open(event,int(event.get("close",24))%24),"Site remained open after closing: "+id)
        check(geo.reachable(layout,[layout.get("spawn",Vector2i.ZERO)],targets),"One or more town activity sites unreachable: "+id)
        check(town_scene.nodes.has("key_npc"),"Town activity removed canonical story NPC: "+id)
        var state = State.new()
        state.new_game()
        var premature: Dictionary = towns.interact(id,"handoff",state,20)
        check(not premature.get("changed",false) and not premature.has("reward"),"Could bypass neighborhood cooperation: "+id)
        var closed: Dictionary = towns.interact(id,"prepare",state,23)
        check(not bool(closed.get("changed",false)),"Nighttime should close the morning event: "+id)
        var first: Dictionary = towns.interact(id,"prepare",state,8)
        check(bool(first.get("changed",false)),"Morning activity not registered: "+id)
        var second: Dictionary = towns.interact(id,"coordinate",state,14)
        check(bool(second.get("changed",false)),"Afternoon activity blocked: "+id)
        var third: Dictionary = towns.interact(id,"handoff",state,20)
        check(bool(third.get("changed",false)) and not (third.get("reward",{}) as Dictionary).is_empty(),"Evening participation reward unavailable: "+id)
        var duplicate: Dictionary = towns.interact(id,"handoff",state,21)
        check(not bool(duplicate.get("changed",false)) and not duplicate.has("reward"),"Repeatable town payout: "+id)
        check(towns.completion_count(state,id)==3,"Did not record all three activities: "+id)
        var restored = State.new()
        check(restored.restore_snapshot(state._pack()),"Failed to reload town activity save: "+id)
        check(towns.completion_count(restored,id)==3,"Town activity was not saved: "+id)
        town_scene.queue_free()
        await process_frame
    check(total==33,"Expected 33 unique community activities, not "+str(total))
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.progress.chapter=1
    game.world_router.sync_chapter(1)
    game._enter_location()
    game.busy=false
    game.world.locked=false
    check(game.world.nodes.has("townlife:prepare"),"Live new-game village lacks community interactions")
    var original_gold: int = game.progress.gold
    for entry in [{"step":"prepare","time":8},{"step":"coordinate","time":14},{"step":"handoff","time":20}]:
        game.progress.rpg["game_clock"]["minutes"]=int(entry["time"])*60
        game._interact("townlife:"+str(entry["step"]))
    check(game.progress.gold>original_gold,"Player's real inventory/gold wasn't credited")
    var once: int = game.progress.gold
    game._interact("townlife:handoff")
    check(game.progress.gold==once,"Town ecology can generate duplicated gold")
    check(game.progress.rpg.get("town_ecology_v7",{}).has("map_coast_01"),"End-to-end town status not saved")
    if errors.is_empty():
        print("PASS: 11 independent settlement activities, 33 real reachable stations, daily opening hours, stage ordering, original quest anchors, saved state, payouts and anti-farming")
        quit(0)
        return
    for issue in errors:
        push_error(issue)
    quit(1)
