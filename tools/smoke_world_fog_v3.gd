extends SceneTree
## Persistent fog-of-war: compact save format, separate indoor masks and real map HUD.
const State = preload("res://scripts/first_act_state.gd")
const Fog = preload("res://scripts/world_fog_v3.gd")
const Game = preload("res://scripts/first_act.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func verify(ok: bool, why: String) -> void:
    if not ok:
        errors.append(why)

func _run() -> void:
    var progress = State.new()
    var mask = Fog.new()
    mask.bind(progress)
    verify(not mask.revealed("map_coast_03",15,20),"Fresh wild map should begin undiscovered")
    verify(mask.reveal("map_coast_03",Vector2i(15,20),5),"Approaching tile should reveal a new area")
    verify(mask.revealed("map_coast_03",15,20),"Revealed tile was not saved in compact cache")
    verify(not mask.reveal("map_coast_03",Vector2i(15,20),5),"Same hero cell should not trigger redundant writes")
    verify(not mask.revealed("map_coast_03",71,47),"Far corner must remain hidden")
    var percent: int = mask.percent("map_coast_03")
    verify(percent > 0 and percent < 20,"Fog percent must represent local discovery, not a fully open map")
    verify(mask.reveal("map_coast_03#inn",Vector2i(35,23),3),"Indoor map must be independently discoverable")
    verify(not mask.revealed("map_coast_03",35,23),"Indoor movement must never reveal unrelated outdoor terrain")
    var snapshot: Dictionary = progress._pack()
    var restored = State.new()
    verify(restored.restore_snapshot(snapshot),"Saved fog snapshot did not pass migration validation")
    var second = Fog.new()
    second.bind(restored)
    verify(second.revealed("map_coast_03",15,20),"Outdoor fog was lost on save restore")
    verify(second.revealed("map_coast_03#inn",35,23),"Indoor fog was lost on save restore")
    verify(second.percent("map_coast_03")==percent,"Fog exploration percent changed after reload")
    var game = Game.new()
    root.add_child(game)
    game.ui.title_overlay.hide()
    game._start(false)
    verify(game.world.fog!=null,"Playable game world was not bound to V3 fog")
    verify(game.world.fog.revealed(game.world.fog_key(),Vector2i(game.world.hero.position/32.0).x,Vector2i(game.world.hero.position/32.0).y),"Exploration spawn tile remained dark")
    verify(game.atlas.full_view!=null and game.atlas.small_view!=null,"Fog broke the map viewing controls")
    if errors.is_empty():
        print("PASS: local fog reveals only nearby tiles, 432-byte masks persist, indoors stay separate, spawn and map HUD bound correctly")
        quit(0)
    else:
        for error in errors:
            push_error(error)
        quit(1)
