extends SceneTree
## 21 wilderness maps × 4 real sites: previews must be pure, deterministic,
## weather-aware and compatible with existing B progression/save fields.
## D still owns the authoritative transaction and gold/item payouts.
const Field = preload("res://scripts/world_field_ecology.gd")
const State = preload("res://scripts/first_act_state.gd")
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)


func _preview_pure(field, map_id: String, action: String, state,
        weather: String, minute: int, day: int) -> Dictionary:
    var before: Dictionary=state._pack().duplicate(true)
    var first: Dictionary=field.preview_interact(map_id,action,state,weather,minute,day)
    var repeat: Dictionary=field.preview_interact(map_id,action,state,weather,minute,day)
    check(first==repeat,map_id+"/"+action+": preview changed between identical reads")
    check(state._pack()==before,map_id+"/"+action+": preview changed V3 state, party or items")
    return first


func _run() -> void:
    var field=Field.new()
    check(field.issues.is_empty(),"21-area authoring invalid: "+str(field.issues))
    check(field.maps.size()==21,"Wilderness area count differs from canonical 21")
    var event_ids: Dictionary={}
    var checked: int=0
    for map_value in field.maps.keys():
        var map_id: String=str(map_value)
        var info: Dictionary=field.config(map_id)
        var challenge: Dictionary=info.get("challenge",{})
        var gathering: Dictionary=info.get("gather",{})
        var player=State.new()
        player.new_game()
        var before: Dictionary=player._pack().duplicate(true)
        var denied: Dictionary=_preview_pure(field,map_id,"cache",player,"clear",480,1)
        check(not bool(denied.get("allowed",true)),map_id+": premature cache unlock")
        denied=_preview_pure(field,map_id,"gather",player,"clear",480,1)
        check(not bool(denied.get("allowed",true)),map_id+": premature harvest")
        check(player._pack()==before,map_id+": rejected activity changed state")

        var danger: String=str(challenge.get("danger_weather","rain"))
        var trial: Dictionary=_preview_pure(field,map_id,"trial",player,danger,480,1)
        check(bool(trial.get("allowed",false)) and bool(trial.get("requires_save",false)),
            map_id+": challenge preview missing")
        check(int(trial.get("hazard",0))==int(challenge.get("hp_cost",0)),
            map_id+": challenge HP preview does not match authored danger")
        var trial_applied: Dictionary=field.interact(map_id,"trial",player,danger,480,1)
        check(bool(trial_applied.get("changed",false)) and
            int(trial_applied.get("hazard",0))==int(trial.get("hazard",0)),
            map_id+": trial preview disagrees with existing game interaction")
        for hero in player.actors:
            check(int(hero.get("hp",1))>=1,map_id+": ground hazard was lethal")
        check(not bool(_preview_pure(field,map_id,"trial",player,danger,480,1).get("allowed",true)),
            map_id+": already-scouted terrain offered second HP cost")

        var bonus: String=str(gathering.get("bonus_weather","clear"))
        var gather: Dictionary=_preview_pure(field,map_id,"gather",player,bonus,480,1)
        check(bool(gather.get("allowed",false)),map_id+": collection not allowed after scouting")
        check(int((gather.get("reward",{}) as Dictionary).get("amount",0))==2,
            map_id+": bonus weather did not apply")
        check(str(gather.get("event_id",""))=="b.field."+map_id+".gather.day.1",
            map_id+": repeatable harvest has no calendar-scoped receipt")
        var harvested: Dictionary=field.interact(map_id,"gather",player,bonus,480,1)
        check(bool(harvested.get("changed",false)) and
            (harvested.get("reward",{}) as Dictionary)==(gather.get("reward",{}) as Dictionary),
            map_id+": first harvest disagrees with preview")
        check(not bool(_preview_pure(field,map_id,"gather",player,bonus,600,1).get("allowed",true)),
            map_id+": multiple harvests possible in one day")
        var day_two: Dictionary=_preview_pure(field,map_id,"gather",player,"clear",480,2)
        check(bool(day_two.get("allowed",false)) and
            str(day_two.get("event_id",""))=="b.field."+map_id+".gather.day.2",
            map_id+": next-day gathering not distinguished from first day")
        check(bool(field.interact(map_id,"gather",player,"clear",480,2).get("changed",false)),
            map_id+": second calendar day gathering failed")

        # Two samples permit the passage even in poor weather/time, while
        # its first opening and later reuse must have distinct save semantics.
        var passage: Dictionary=_preview_pure(field,map_id,"passage",player,"rain",12*60,2)
        check(bool(passage.get("allowed",false)) and bool(passage.get("teleport",false)),
            map_id+": fully investigated passage inaccessible")
        var opened: Dictionary=field.interact(map_id,"passage",player,"rain",12*60,2)
        check(bool(opened.get("changed",false)) and bool(opened.get("teleport",false)),
            map_id+": first passage does not open")
        var revisit: Dictionary=_preview_pure(field,map_id,"passage",player,"rain",12*60,3)
        check(bool(revisit.get("allowed",false)) and not bool(revisit.get("changed",true))
            and bool(revisit.get("teleport",false))
            and not bool(revisit.get("requires_save",true)),
            map_id+": shortcut reuse attempts a second permanent event")

        var treasure: Dictionary=_preview_pure(field,map_id,"cache",player,"clear",480,2)
        check(bool(treasure.get("allowed",false)) and not (treasure.get("reward",{}) as Dictionary).is_empty(),
            map_id+": cache preview has no legitimate one-time reward")
        var got: Dictionary=field.interact(map_id,"cache",player,"clear",480,2)
        check(bool(got.get("claimed",false)) and
            (got.get("reward",{}) as Dictionary)==(treasure.get("reward",{}) as Dictionary),
            map_id+": cache loot does not match its preview")
        check(not bool(_preview_pure(field,map_id,"cache",player,"clear",480,2).get("allowed",true)),
            map_id+": duplicate cache reward exposed")
        check(field.completed(player,map_id)==4,map_id+": one-time progress incomplete")

        for record in [trial,gather,passage,treasure]:
            var event_id: String=str(record.get("event_id",""))
            check(not event_id.is_empty() and not event_ids.has(event_id),
                map_id+": empty/duplicate stable event ID "+event_id)
            event_ids[event_id]=true
            checked+=1
        var restored=State.new()
        check(restored.restore_snapshot(player._pack()),map_id+": V3 snapshot restore failed")
        check(field.snapshot(player,map_id)==field.snapshot(restored,map_id),
            map_id+": restored field progress differs from original")
    var unknown=State.new()
    unknown.new_game()
    check(not bool(_preview_pure(field,"invalid","cache",unknown,"clear",480,1).get("allowed",true)),
        "Unknown map allowed a reward")
    check(not bool(_preview_pure(field,"map_coast_02","cache",unknown,"clear",480,0).get("allowed",true)),
        "Day zero could create an invalid receipt")
    check(checked==84 and event_ids.size()==84,
        "Not exactly 84 unique first-pass wilderness interaction receipts")
    if failures.is_empty():
        print("PASS B field: 21 maps, 84 immutable previews, daily receipts, weather/HP, shortcut and one-time treasure")
        quit(0)
        return
    for issue in failures:
        push_error(issue)
    quit(1)
