extends SceneTree
## B-only NPC conversation regression: pure preview, stable receipts, no effects.
const State = preload("res://scripts/first_act_state.gd")
const TownLife = preload("res://scripts/world_town_life.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, reason: String) -> void:
    if not value:
        errors.append(reason)

func _run() -> void:
    var life = TownLife.new()
    var progress = State.new()
    progress.new_game()
    progress.chapter = 2
    var npc_count: int = 0
    for npc_id in life.by_id.keys():
        var citizen: Dictionary=life.citizen(str(npc_id))
        var region: String=str(citizen.get("region_id",""))
        var clock: Dictionary={"day":1,"minutes":480}
        var before: Dictionary=progress._pack().duplicate(true)
        var preview: Dictionary=life.preview_talk(str(npc_id),region,clock,progress)
        var repeat_preview: Dictionary=life.preview_talk(str(npc_id),region,clock,progress)
        _check(progress._pack()==before,"Preview changed saved state: "+str(npc_id))
        _check(bool(preview.get("first",false)),"First preview lost: "+str(npc_id))
        _check(preview==repeat_preview,"Repeated preview changed event ID/text: "+str(npc_id))
        _check(str(preview.get("event_id",""))=="b.npc.first."+str(npc_id),
            "Unstable NPC contact event receipt: "+str(npc_id))
        _check(not str(preview.get("text","")).is_empty(),"Dialogue missing: "+str(npc_id))
        var invalid: Dictionary=life.preview_talk(str(npc_id),"region_invalid",clock,progress)
        _check(not bool(invalid.get("first",true)),"Wrong region could claim NPC: "+str(npc_id))
        var live: Dictionary=life.talk(str(npc_id),region,clock,progress)
        _check(bool(live.get("first",false)),"Existing main-game NPC talk no longer records first visit")
        var after: Dictionary=life.preview_talk(str(npc_id),region,clock,progress)
        _check(not bool(after.get("first",true)),"First contact not committed: "+str(npc_id))
        _check(str(after.get("dialogue_phase",""))=="repeat",
            "Repeat NPC dialogue not selected: "+str(npc_id))
        _check(not bool(after.get("requires_save",true)) and str(after.get("event_id","")).is_empty(),
            "Repeat NPC contact creates duplicate transaction: "+str(npc_id))
        npc_count += 1
    _check(npc_count==40,"Must cover all 40 canonical NPC identities")
    if errors.is_empty():
        print("PASS B NPC: 40 non-mutating dialogue previews, stable first-contact receipts, repeat and wrong-region guard")
        quit(0)
    else:
        for message in errors:
            push_error(message)
        quit(1)
