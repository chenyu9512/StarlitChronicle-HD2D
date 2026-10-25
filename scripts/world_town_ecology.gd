extends RefCounted
## Settlement-specific neighborhood activities. Existing NPCs, shops and original quests remain authoritative.
const SOURCE: String = "res://data/levels/v7/town_ecology.json"
const TOWNS: String = "res://data/levels/town_director_v4.json"
var towns: Dictionary = {}
var issues: Array[String] = []

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOWNS))
    if not parsed is Dictionary or str(parsed.get("schema",""))!="starlit.town_ecology.v7":
        issues.append("Invalid V7 settlement ecology")
        return
    if not original is Dictionary:
        issues.append("Cannot load original town designs")
        return
    towns = parsed.get("towns",{})
    var plans: Dictionary = original.get("towns",{})
    if towns.size()!=11 or plans.size()!=11:
        issues.append("Eleven settlement plans required")
    var themes: Dictionary = {}
    for key in towns.keys():
        var map_id: String = str(key)
        var record: Dictionary = towns[map_id]
        if not plans.has(map_id):
            issues.append("Activity without existing city layout: "+map_id)
            continue
        var title: String = str(record.get("activity",""))
        if themes.has(title):
            issues.append("Two towns share the same community activity "+title)
        themes[title]=true
        var districts: Dictionary = {}
        for district in (plans[map_id] as Dictionary).get("districts",[]):
            districts[str(district.get("name",""))]=true
        var ordered: Dictionary = {}
        var events: Array = record.get("events",[])
        if events.size()!=3:
            issues.append("Each town needs three different neighborhood activities: "+map_id)
        for event in events:
            if not event is Dictionary:
                issues.append("Invalid community event "+map_id)
                continue
            var event_id: String = str(event.get("id",""))
            var requirement: String = str(event.get("need",""))
            var cell: Array = event.get("cell",[])
            if ordered.has(event_id) or (not requirement.is_empty() and not ordered.has(requirement)):
                issues.append("Duplicate or unordered neighborhood activity "+map_id+":"+event_id)
            ordered[event_id]=true
            if not districts.has(str(event.get("district",""))):
                issues.append("Community event does not belong to a named district "+map_id+":"+event_id)
            if cell.size()!=2 or str(event.get("text","")).length()<12:
                issues.append("Invalid authored location or dialogue "+map_id+":"+event_id)
            if int(event.get("open",-1))<0 or int(event.get("close",25))>24:
                issues.append("Invalid time schedule "+map_id+":"+event_id)

func config(map_id: String) -> Dictionary:
    return towns.get(map_id,{})

func entries(map_id: String) -> Array:
    return (config(map_id) as Dictionary).get("events",[])

func entry(map_id: String,event_id: String) -> Dictionary:
    for record in entries(map_id):
        if str(record.get("id",""))==event_id:
            return record
    return {}

static func is_open(event: Dictionary,hour: int) -> bool:
    var start: int = int(event.get("open",0))
    var close: int = int(event.get("close",24))
    var clock_hour: int = posmod(hour,24)
    if start==close:
        return true
    if start<close:
        return clock_hour>=start and clock_hour<close
    return clock_hour>=start or clock_hour<close

static func _state(state,map_id: String) -> Dictionary:
    var history: Dictionary = state.rpg.get("town_ecology_v7",{})
    return (history.get(map_id,{}) as Dictionary).duplicate(true)

static func progress(state,map_id: String) -> Dictionary:
    return _state(state,map_id)

static func _commit(state,map_id: String,status: Dictionary) -> void:
    var history: Dictionary = state.rpg.get("town_ecology_v7",{})
    history[map_id]=status.duplicate(true)
    state.rpg["town_ecology_v7"]=history

func interact(map_id: String,event_id: String,state,hour: int) -> Dictionary:
    var activity: Dictionary = config(map_id)
    var record: Dictionary = entry(map_id,event_id)
    if activity.is_empty() or record.is_empty() or state==null:
        return {"changed":false,"message":"这里没有开放的社区活动。"}
    var result: Dictionary = _state(state,map_id)
    var event_title: String = str(record.get("title","街区活动"))
    if bool(result.get(event_id,false)):
        return {"changed":false,"message":"【%s】这项街区工作已记录在居民档案中。" % event_title}
    if not is_open(record,hour):
        return {"changed":false,"message":"【%s】活动时间为 %02d:00—%02d:00，当前无法办理。" % [event_title,int(record.get("open",0)),int(record.get("close",24))]}
    var required: String = str(record.get("need",""))
    if not required.is_empty() and not bool(result.get(required,false)):
        return {"changed":false,"message":"【%s】先完成前一处街区协作，再回来确认。" % event_title}
    result[event_id]=true
    _commit(state,map_id,result)
    var message: String = "【%s】\n%s" % [event_title,str(record.get("text",""))]
    var reward: Dictionary = record.get("reward",{}) if record.get("reward",{}) is Dictionary else {}
    if not reward.is_empty():
        message+="\n社区感谢你协助完成整日的工作。"
    return {"changed":true,"message":message,"reward":reward,"complete":not reward.is_empty()}

func completion_count(state,map_id: String) -> int:
    var status: Dictionary = _state(state,map_id)
    var count: int = 0
    for record in entries(map_id):
        if bool(status.get(str(record.get("id","")),false)):
            count+=1
    return count
