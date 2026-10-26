extends RefCounted
## D adapter invokes existing C visuals/sounds without touching authored B/C data.
static func show_actor_action(actor: Node, action: String, player_position: Vector2) -> bool:
    if actor==null or not is_instance_valid(actor):
        return false
    if action=="talk" and actor.has_method("face_player"):
        actor.call("face_player",player_position)
        return true
    if action=="inspect" and actor.has_method("perform_life_action"):
        actor.call("perform_life_action","observe")
        return true
    return false

static func trigger_fx(fx: Node, result: Dictionary, local_point: Vector2,
        reduced_motion: bool = false) -> bool:
    if fx==null or not is_instance_valid(fx) or not fx.has_method("trigger"):
        return false
    var requested: String=str(result.get("animation",""))
    var supported: String="door_open" if requested=="open" else requested
    if supported not in ["door_open","door_close","chest_open","lantern_on","inspect"]:
        return false
    return bool(fx.call("trigger",supported,local_point,reduced_motion))

static func crossfade(sound: Node, map_id: String, indoor: bool) -> bool:
    if sound==null or not is_instance_valid(sound) or not sound.has_method("configure"):
        return false
    sound.call("configure",map_id,"interior" if indoor else "street",indoor,0.40)
    return true

static func contracts() -> Dictionary:
    return {"b_schedule":"res://scripts/world_npc_daily.gd",
        "c_npc":"res://scripts/world_npc_visual.gd",
        "c_fx":"res://scripts/c_interaction_fx.gd",
        "c_sound":"res://scripts/c_town_soundscape.gd"}
