extends SceneTree
## B-only 11-town/33-stage social activity transaction intent contract.
## The pure preview must never alter V3 state or pay out rewards. D later
## settles approved intents under its one authoritative save/receipt.
const Ecology = preload("res://scripts/world_town_ecology.gd")
const State = preload("res://scripts/first_act_state.gd")
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool, explanation: String) -> void:
    if not ok:
        failures.append(explanation)


func _run() -> void:
    var ecology=Ecology.new()
    check(ecology.issues.is_empty(),"Broken town/source definitions: "+str(ecology.issues))
    var total: int=0
    var seen_events: Dictionary={}
    for map_value in ecology.towns.keys():
        var map_id: String=str(map_value)
        var player=State.new()
        player.new_game()
        var events: Array=ecology.entries(map_id)
        check(events.size()==3,map_id+": wrong number of real town stages")
        if events.size()!=3:
            continue
        # No shortcuts: the third stage is not available until the first
        # two stages have been performed by a real local action.
        var last: Dictionary=events[2]
        var blocked: Dictionary=ecology.preview_interact(
            map_id,str(last.get("id","")),player,int(last.get("open",20)))
        check(not bool(blocked.get("allowed",true)),map_id+": skipped required activities")
        for record in events:
            var id: String=str(record.get("id",""))
            var hour: int=int(record.get("open",8))
            var before: Dictionary=player._pack().duplicate(true)
            var preview: Dictionary=ecology.preview_interact(map_id,id,player,hour)
            var again: Dictionary=ecology.preview_interact(map_id,id,player,hour)
            check(bool(preview.get("allowed",false)),map_id+"/"+id+": activity not available at scheduled start")
            check(preview==again,map_id+"/"+id+": preview not deterministic")
            check(player._pack()==before,map_id+"/"+id+": preview altered player save data")
            check(bool(preview.get("requires_save",false)),map_id+"/"+id+": no V3 save intent")
            var expected: String="b.town."+map_id+"."+id
            check(str(preview.get("event_id",""))==expected,map_id+"/"+id+": unstable receipt ID")
            check(not seen_events.has(expected),"Two town actions share receipt ID: "+expected)
            seen_events[expected]=true
            if int(record.get("open",0))!=int(record.get("close",24)):
                var closing: int=int(record.get("close",24))%24
                var unavailable: Dictionary=ecology.preview_interact(map_id,id,player,closing)
                check(not bool(unavailable.get("allowed",true)),
                    map_id+"/"+id+": outside-hours preview bypassed")
                check(player._pack()==before,map_id+"/"+id+": closing-time preview wrote state")
            var performed: Dictionary=ecology.interact(map_id,id,player,hour)
            check(bool(performed.get("changed",false)),map_id+"/"+id+": existing player action broken")
            check(str(performed.get("event_id",""))==expected,map_id+"/"+id+": commit mismatch")
            check((performed.get("reward",{}) as Dictionary)==(preview.get("reward",{}) as Dictionary),
                map_id+"/"+id+": preview and actual reward differ")
            var duplicate: Dictionary=ecology.preview_interact(map_id,id,player,hour)
            check(not bool(duplicate.get("allowed",true)),map_id+"/"+id+": duplicate stage preview")
            check(not duplicate.has("reward"),map_id+"/"+id+": repeated step exposes reward")
            total+=1
        check(ecology.completion_count(player,map_id)==3,map_id+": missing a town stage")
        var recovered=State.new()
        check(recovered.restore_snapshot(player._pack()),map_id+": town progress cannot restore")
        check(ecology.completion_count(recovered,map_id)==3,map_id+": restored town activities differ")
    check(total==33,"Expected exactly 33 local neighborhood activities, got "+str(total))
    check(seen_events.size()==33,"Not all 33 V3 receipt identities are unique")
    var invalid=State.new()
    var before_invalid: Dictionary=invalid._pack().duplicate(true)
    check(not bool(ecology.preview_interact("map_invalid","handoff",invalid,20).get("allowed",true)),
        "Unknown town offered an activity")
    check(invalid._pack()==before_invalid,"Unknown town preview changed V3 save")
    if failures.is_empty():
        print("PASS B: 11 settlements, 33 preview receipts, no rewards or save writes, stage/time gates")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
