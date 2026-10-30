extends SceneTree
## First-act sailor recruitment: normal party, overlevelled party, V3 back-compat.
const State = preload("res://scripts/first_act_state.gd")

var failures: Array[String] = []

func check(valid: bool, description: String) -> void:
    if not valid:
        failures.append(description)

func member_by_id(state, identity: String) -> Dictionary:
    for record in state.actors:
        if str(record.get("id","")) == identity:
            return record
    return {}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for pair in [[5,5],[5,7],[18,19],[1,1]]:
        var state = State.new()
        state.chapter = 4
        state.actors[0]["level"] = pair[0]
        state.actors[1]["level"] = pair[1]
        var expected: int = clampi(roundi(float(pair[0]+pair[1])/2.0),1,state.level_cap)
        state.recruit_sailor()
        var seeker: Dictionary = member_by_id(state,"char_seeker")
        var offset: int = expected - 5
        check(state.actors.size()==3,"Recruitment did not create exactly one sailor for "+str(pair))
        check(int(seeker.get("level",0))==expected,"Level mismatch for "+str(pair))
        check(int(seeker.get("max_hp",0))==maxi(1,136+15*offset) and
            int(seeker.get("max_mp",0))==maxi(1,35+6*offset) and
            int(seeker.get("attack",0))==maxi(1,30+4*offset) and
            int(seeker.get("defense",-1))==maxi(0,15+2*offset),
            "Sailor attributes do not scale consistently for "+str(pair))
        check(int(seeker.get("hp",0))==int(seeker.get("max_hp",0)) and
            int(seeker.get("mp",0))==int(seeker.get("max_mp",0)),
            "New recruit does not arrive ready to fight for "+str(pair))
        # A second registration must NEVER heal or reset an already
        # injured/levelled companion, even with a changed party roster.
        var seeker_index: int = state.actors.size()-1
        state.actors[seeker_index]["hp"] = 1
        state.actors[seeker_index]["xp"] = 17
        state.actors[0]["level"] = 30
        state.recruit_sailor()
        check(state.actors.size()==3 and
            int(state.actors[seeker_index]["hp"])==1 and
            int(state.actors[seeker_index]["xp"])==17 and
            int(state.actors[seeker_index]["level"])==expected,
            "Duplicate recruitment mutated an existing party member for "+str(pair))
        var loaded = State.new()
        check(loaded.restore_snapshot(state._pack()),"V3 snapshot failed to restore for "+str(pair))
        loaded.recruit_sailor()
        var loaded_sailor: Dictionary = member_by_id(loaded,"char_seeker")
        check(loaded.actors.size()==3 and
            int(loaded_sailor.get("level",0))==expected and
            int(loaded_sailor.get("hp",0))==1 and
            int(loaded_sailor.get("xp",0))==17,
            "V3 load or replayed recruitment overwrote the sailor for "+str(pair))
    # A shipped legacy V3 save already stores Lv.8, so it must stay Lv.8.
    var legacy = State.new()
    legacy.actors.append({"id":"char_seeker","name":"朔弦","level":8,"xp":27,
        "hp":60,"max_hp":136,"mp":15,"max_mp":35,"attack":30,
        "defense":15,"speed":16,"skill":"破雾击"})
    var resumed = State.new()
    check(resumed.restore_snapshot(legacy._pack()),"Old V3 party payload could not be restored")
    resumed.recruit_sailor()
    var old: Dictionary = member_by_id(resumed,"char_seeker")
    check(resumed.actors.size()==3 and int(old.get("level",0))==8 and
        int(old.get("hp",0))==60 and int(old.get("xp",0))==27,
        "Old V3 party was wrongly re-levelled or healed")
    if failures.is_empty():
        print("PASS Act-I recruitment: 5/5, mixed, overlevelled and level-one parties; single join, scaled attributes, V3 legacy-safe")
        quit(0)
    else:
        for problem in failures:
            push_error(problem)
        quit(1)
