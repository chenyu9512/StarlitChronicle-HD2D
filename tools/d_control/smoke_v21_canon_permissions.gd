extends SceneTree
## Headless canon check, not a player-path claim.
const Guard = preload("res://scripts/systems/PartyCanonGuard.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func expect(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)

func _run() -> void:
    var flags: Dictionary = {}
    expect(Guard.roster_state("cast_lei_suo",8,flags) == Guard.GUEST_SUPPORT,"ch008 guest")
    expect(not Guard.can_join("cast_lei_suo",9,flags),"ch009 premature")
    flags["story.ch009.done"] = true
    expect(Guard.can_join("cast_lei_suo",9,flags),"ch009 resolve")
    expect(not Guard.can_join("cast_yi_ze",27,flags),"ch027 guide")
    flags["story.ch028.done"] = true
    expect(Guard.can_join("cast_yi_ze",28,flags),"ch028 resolve")
    expect(not Guard.can_join("cast_xuan_li",32,flags),"ch032 acquaintance")
    flags["story.ch034.done"] = true
    expect(Guard.can_join("cast_xuan_li",34,flags),"ch034 resolve")
    expect(not Guard.can_join("cast_nuo_yi",39,flags),"ch039 minor")
    flags["story.ch048.done"] = true
    expect(Guard.can_join("cast_nuo_yi",49,flags),"ch049 adult")
    expect(not Guard.can_lead("cast_nuo_yi",51,flags),"ch051 leadership")
    flags["story.ch054.done"] = true
    expect(Guard.can_lead("cast_nuo_yi",54,flags),"ch054 leadership")
    expect(not Guard.can_join("cast_wei_sha",43,flags),"ch043 cameo")
    flags["story.ch058.done"] = true
    expect(Guard.can_join("cast_wei_sha",58,flags),"ch058 resolve")
    expect(Guard.historical_actor(21) == "char_tidecaller","ch021 sandbox")
    expect(not Guard.can_fight("char_wayfarer",21,flags),"adult cannot enter ch021")
    flags["ch021.campfire_returned"] = true
    expect(Guard.historical_actor(21,flags).is_empty(),"ch021 must restore present at campfire")
    expect(Guard.can_fight("char_wayfarer",21,flags),"adult party did not restore after campfire")
    if failures.is_empty():
        print("PASS: V2.1 chapter permissions (headless)")
        quit(0)
    for issue in failures:
        push_error(issue)
    quit(1)
