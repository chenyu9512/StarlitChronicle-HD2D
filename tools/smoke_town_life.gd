extends SceneTree
## Engine integration: 40 authored citizens; shops, inns, guilds, lighting and durable saves.
const Game = preload("res://scripts/first_act.gd")
const TownLife = preload("res://scripts/world_town_life.gd")
const State = preload("res://scripts/first_act_state.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,description: String) -> void:
    if not ok:
        errors.append(description)

func _verify() -> void:
    var life = TownLife.new()
    var total: int = 0
    for region in TownLife.REGIONS:
        check(life.residents(region).size()==5,"Each regional settlement must use 5 real catalog NPCs: "+region)
        total+=life.residents(region).size()
    check(total==40,"Expected 40 authored inhabitants")
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    game.progress.chapter=1
    game.world_router.sync_chapter(1)
    game._enter_location()
    check(game.world.nodes.has("citizen:npc_coast_01"),"NPC resident did not spawn in playable village")
    check(game.world.nodes.has("citizen:npc_coast_03"),"Village lore NPC did not spawn")
    check(str(life.citizen("npc_coast_05").get("map_id",""))=="map_coast_02"
        and not game.world.nodes.has("citizen:npc_coast_05"),
        "Port rumor citizen must be authored only in harbor, not duplicated in village")
    check(game.world.ambience!=null and game.world.ambience.weather in ["rain","mist","clear"],"Coastal ambient weather profile not initialized")
    var resident_id: String="citizen:npc_coast_03"
    var old_flags: Dictionary=game.progress.rpg.get("talked_to",{}).duplicate(true)
    game._interact(resident_id)
    check(game.progress.rpg.get("talked_to",{}).has("npc_coast_03"),"NPC conversation not saved in RPG state")
    check(game.ui.dialog_layer.visible,"Resident dialogue portrait window must open")
    check(game.ui.dialog_portrait.texture == null or game.ui.dialog_portrait.visible == false,"Unfinished coast NPC portrait must not impersonate B02 characters")
    game.ui._next()  # Dismiss the one-line interaction before continuing.
    check(not game.busy,"Resident dialogue must unlock exploration")
    var met: int=int(game.progress.rpg["event_counters"].get("resident_met",0))
    game._interact(resident_id)
    check(int(game.progress.rpg["event_counters"].get("resident_met",0))==met,"Repeat NPC conversations awarded duplicate first-visit event")
    if game.ui.dialog_layer.visible:
        game.ui._next()
    check(not old_flags.has("npc_coast_03"),"NPC first interaction was already marked")
    check(game.world.enter_building("shop"),"Village shop is not enterable")
    game._interact("interior_service")
    check(game.service_menu.is_open(),"Shop command menu was not displayed")
    var stock: Array[String] = life.town_shop_ids("region_coast",game.game_core)
    check(not stock.is_empty(),"Coastal shop catalog missing")
    var item_id: String=stock[0]
    var original_stock: int=game.game_core.count(item_id)
    var before_gold: int=game.progress.gold
    game._service_action("buy:"+item_id)
    check(game.game_core.count(item_id)==original_stock+1,"Shop purchase did not add a real item")
    check(game.progress.gold<before_gold,"Shop purchase did not charge catalog price")
    game.service_menu.close_service()
    check(not game.service_menu.is_open(),"Service menu did not close")
    check(game.world.leave_building(),"Shop indoor exit failed")
    check(game.world.enter_building("inn"),"Inn entry missing")
    game.progress.actors[0]["hp"]=20
    var inn_cost: int=game.progress.gold
    game._interact("interior_service")
    game._service_action("rest")
    check(game.progress.gold==inn_cost-30,"Inn rest did not charge exactly thirty G")
    check(int(game.progress.actors[0]["hp"])==int(game.progress.actors[0]["max_hp"]),"Inn did not heal actual party data")
    game.service_menu.close_service()
    game.world.leave_building()
    check(game.world.enter_building("guild"),"Regional guild entry missing")
    game._interact("interior_service")
    game._service_action("guild")
    check(str(life.guild_progress("region_coast",game.progress).get("state",""))=="active","Guild commission was not accepted")
    for i in range(3):
        game.game_events.record("battle_victory",{"xp":10})
    check(str(life.guild_progress("region_coast",game.progress).get("state",""))=="ready","Guild battle counter did not advance")
    var guild_gold: int=game.progress.gold
    game._service_action("guild")
    check(game.progress.gold>guild_gold,"Guild completion did not pay reward")
    check(str(life.guild_progress("region_coast",game.progress).get("state",""))=="claimed","Guild claim did not persist completion status")
    var claimed: int=game.progress.gold
    game._service_action("guild")
    check(game.progress.gold==claimed,"Completed guild commission paid reward more than once")
    check(game.progress.save(),"Could not write a save with new town interactions")
    var restored=State.new()
    check(restored.load_saved(),"Town-interaction save could not be reloaded")
    check((restored.rpg.get("guild_contracts",{}) as Dictionary).has("region_coast"),"Guild commissions were lost on load")
    check((restored.rpg.get("talked_to",{}) as Dictionary).has("npc_coast_03"),"NPC acquaintance was lost on load")
    game.service_menu.close_service()
    check(game.world.leave_building(),"Guild indoor exit failed")
    check(game.world.interior_building.is_empty(),"Guild exit did not restore outdoors")
    var night_resident: String = "citizen:npc_coast_03"
    # A missing resident is a hard QA failure, not a dictionary-key script
    # exception that leaves SceneTree running until the CI watchdog expires.
    check(game.world.nodes.has(night_resident),
        "Outdoor resident absent after guild return; map="+str(game.world.map_profile.get("id",""))
        +" indoor="+game.world.interior_building)
    var resident_before: Vector2 = Vector2.ZERO
    if game.world.nodes.has(night_resident):
        resident_before = game.world.nodes[night_resident].position
    game.world.sync_world_clock(2,22*60)
    check(game.world.ambience.day==2 and game.world.ambience.minutes==1320,"Real-time lighting clock did not update")
    if game.world.nodes.has(night_resident):
        var resident_after: Vector2 = game.world.nodes[night_resident].position
        check(resident_before != resident_after,"Town residents did not move between daytime and nighttime schedules")
    if errors.is_empty():
        print("PASS: 40 authored inhabitants, social persistence, functional shops/inns/guild, no duplicate rewards, day/night NPC schedules and saved transactions")
        quit(0)
    else:
        for failure in errors:
            push_error(failure)
        quit(1)
