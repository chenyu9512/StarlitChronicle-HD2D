extends SceneTree
## M0.1 anti-regression: concurrent art/route changes must not silently
## resurrect mutating B handlers followed by ignored _save_progress().
## This is an explicit source-wiring gate, not a substitute for live tests.
const MAIN_PATH: String = "res://scripts/first_act.gd"
const TX_PATH: String = "res://scripts/d_world_interaction/world_object_settlement.gd"
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool,label: String) -> void:
    if not ok:
        errors.append(label)

func _between(source: String,first: String,last: String) -> String:
    var start: int = source.find(first)
    if start < 0:
        return ""
    var end: int = source.find(last,start+first.length())
    if end < 0 or end<=start:
        return ""
    return source.substr(start,end-start)

func _run() -> void:
    var main: String = FileAccess.get_file_as_string(MAIN_PATH)
    var settlement: String = FileAccess.get_file_as_string(TX_PATH)
    var field_part: String = _between(main,
        'if target.begins_with("field:"):',
        'if target.begins_with("townlife:"):')
    var town_part: String = _between(main,
        'if target.begins_with("townlife:"):',
        'if target.begins_with("discovery:"):')
    var camp_part: String = _between(main,
        'if target == "wild_camp":',
        'if target.begins_with("exit:"):')
    check(not field_part.is_empty() and not town_part.is_empty() and not camp_part.is_empty(),
        "Official game lost a map/town/camp interaction branch")
    check(field_part.contains("WorldObjectSettlement.interact(progress,game_core,field_handler)"),
        "Official field harvest is no longer an atomic V3 transaction")
    check(town_part.contains("WorldObjectSettlement.interact(progress,game_core,town_handler)"),
        "Official town reward is no longer an atomic V3 transaction")
    check(camp_part.contains("WorldObjectSettlement.transact(progress,rest_handler)"),
        "Official camp HP/time/day must commit atomically")
    for branch in [field_part,town_part,camp_part]:
        check(not branch.contains("_save_progress()"),
            "Legacy unchecked save restored inside authoritative settlement branch")
    check(field_part.contains("if not bool(field_tx.get("),
        "Field does not abort after save failure")
    check(town_part.contains("if not bool(town_tx.get("),
        "Town does not abort after save failure")
    check(camp_part.contains("if not bool(camp_tx.get("),
        "Camp does not abort after save failure")
    check(settlement.contains("static func interact(progress: Object"),
        "World-object V3 interaction settlement module missing")
    check(settlement.contains('progress.call("restore_snapshot",before)'),
        "World-object settlement lost failure rollback")
    if errors.is_empty():
        print("PASS: M0.1 live field/town/camp paths use V3 atomic settlement and fail closed")
        quit(0)
        return
    for failure in errors:
        push_error(failure)
    quit(1)
