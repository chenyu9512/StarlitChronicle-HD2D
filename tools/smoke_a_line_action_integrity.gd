extends SceneTree
## A-line: actual battle input integrity; one future Godot batch, no cheats.
## Regressions: consumed herb overwritten by stale actor copy; forged/expired ally targets.
const Battle = preload("res://scripts/first_act_battle.gd")
const State = preload("res://scripts/first_act_state.gd")
const Core = preload("res://scripts/rpg_core.gd")
const Encounters = preload("res://scripts/encounter_registry.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, description: String) -> void:
    if not condition:
        failures.append(description)

func setup_battle() -> Dictionary:
    var state = State.new()
    state.chapter = 2
    # Healer must take the first legitimate command, independent of random foe speed.
    var healer: Dictionary = state.actors[1]
    healer["speed"] = 140
    healer["mp"] = 40
    state.actors[1] = healer
    # Keep the other ally ahead of enemies so a normal enemy hit cannot
    # obscure the exact after-potion HP assertion before the next input.
    var fighter: Dictionary = state.actors[0]
    fighter["speed"] = 80
    state.actors[0] = fighter
    var core = Core.new()
    core.bind(state)
    var battle = Battle.new()
    root.add_child(battle)
    battle.game_core = core
    battle.encounter_registry = Encounters.new()
    battle.dice.seed = 9104
    battle.encounter_registry.rng.seed = 9104
    battle.start(state,2,false)
    return {"state":state,"core":core,"battle":battle}

func _run() -> void:
    var fixture: Dictionary = setup_battle()
    var state = fixture["state"]
    var core = fixture["core"]
    var battle = fixture["battle"]
    check(battle.hero_turn == 1,"Healer did not get the first command")
    var hp_before: int = maxi(1,int(state.actors[1]["max_hp"])-48)
    var healer: Dictionary = state.actors[1]
    healer["hp"] = hp_before
    state.actors[1] = healer
    var herbs_before: int = core.count("item_herb_01")
    var cursor_before: int = battle.turn_cursor
    battle._act("potion")
    check(int(state.actors[1].get("hp",0)) == int(state.actors[1].get("max_hp",0)),
        "Potion restored HP then stale local actor overwrote it")
    check(core.count("item_herb_01") == herbs_before-1 and state.potions==herbs_before-1,
        "Potion must consume exactly one herb with consistent inventory")
    check(battle.turn_cursor > cursor_before or battle.current_round>1,
        "Successful potion did not spend the actor turn")
    battle.free()

    fixture = setup_battle()
    state = fixture["state"]
    core = fixture["core"]
    battle = fixture["battle"]
    check(battle.hero_turn == 1,"Healer initiative changed unexpectedly")
    var wounded: Dictionary = state.actors[0]
    wounded["hp"] = int(wounded["max_hp"])-50
    state.actors[0] = wounded
    var initial_hp: int = int(state.actors[0]["hp"])
    var initial_mp: int = int(state.actors[1]["mp"])
    var initial_inventory: Dictionary = state.inventory.duplicate(true)
    var initial_cursor: int = battle.turn_cursor
    for enemy_token in ["hello","-1"]:
        battle._act("attack#"+enemy_token)
        check(battle.turn_cursor==initial_cursor and battle.hero_turn==1
            and int(battle.formation.units[0]["hp"])>0,
            "Malformed enemy token spent a player turn: "+enemy_token)
    for invalid_token in ["999","-1","hello"]:
        battle._act("skill:skill_tidecaller_01@"+invalid_token)
        check(battle.turn_cursor==initial_cursor and battle.hero_turn==1,
            "Invalid ally target spent the command: "+invalid_token)
        check(int(state.actors[0]["hp"])==initial_hp and int(state.actors[1]["mp"])==initial_mp
            and state.inventory==initial_inventory,
            "Invalid ally target changed combat or economic state: "+invalid_token)
    # Direct commands and UI both pass through the same legal target guard.
    battle._act("skill:skill_tidecaller_01@0")
    check(int(state.actors[0]["hp"])>initial_hp,
        "Valid ally target did not receive a healing spell")
    check(battle.turn_cursor>initial_cursor or battle.current_round>1,
        "Valid ally skill did not advance the battle")
    battle.free()

    if failures.is_empty():
        print("PASS: potion heals without stale overwrite, single consumption, invalid target isolation and valid healer actions")
        quit(0)
    else:
        for issue in failures:
            push_error(issue)
        quit(1)
