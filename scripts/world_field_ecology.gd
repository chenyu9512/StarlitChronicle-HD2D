extends RefCounted
## V7 field ecology: 21 authored outdoor sectors; all persistence lives in the existing rpg dictionary.
const SOURCE: String = "res://data/levels/v7/field_ecology.json"
const LEVELS: String = "res://data/levels/world_levels_v3.json"
const ATLAS: String = "res://data/levels/world_atlas_v2.json"
const SITE_IDS: Array[String] = ["trial","gather","passage","cache"]
var maps: Dictionary = {}
var issues: Array[String] = []

func _init() -> void:
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS))
    var atlas: Variant = JSON.parse_string(FileAccess.get_file_as_string(ATLAS))
    if not source is Dictionary or str(source.get("schema",""))!="starlit.field_ecology.v7":
        issues.append("Missing V7 field ecology registry")
        return
    if not original is Dictionary or not atlas is Dictionary:
        issues.append("Cannot cross-check authored field ecology with existing geography")
        return
    maps = source.get("maps",{})
    var levels: Dictionary = original.get("levels",{})
    var allowed: Dictionary = {}
    for zone in atlas.get("zones",[]):
        if not zone is Dictionary:
            continue
        if str(zone.get("archetype","")) in ["field","route","landmark"] and not str(zone.get("id","")).begins_with("map_city_"):
            allowed[str(zone.get("id",""))]=str(zone.get("biome",""))
    if maps.size()!=21 or allowed.size()!=21:
        issues.append("Expected precisely 21 independently authored wilderness maps")
    var challenge_titles: Dictionary = {}
    var passage_titles: Dictionary = {}
    for map_id in maps.keys():
        var id: String = str(map_id)
        var spec: Dictionary = maps[id]
        if not allowed.has(id) or not levels.has(id) or str(spec.get("biome",""))!=str(allowed.get(id,"")):
            issues.append("Field ecology is not mapped to a valid wilderness sector: "+id)
            continue
        var dims: Array = (levels[id] as Dictionary).get("size",[])
        var seen: Dictionary = {}
        var occupied: Dictionary = {}
        var sites: Array = spec.get("sites",[])
        if sites.size()!=4 or dims.size()!=2:
            issues.append("Field ecology requires four sites inside the independent layout: "+id)
            continue
        for site in sites:
            if not site is Dictionary:
                issues.append("Invalid field site: "+id)
                continue
            var site_id: String = str(site.get("id",""))
            var cell: Array = site.get("cell",[])
            if site_id not in SITE_IDS or seen.has(site_id) or cell.size()!=2:
                issues.append("Duplicate/missing field interaction: "+id+"/"+site_id)
                continue
            seen[site_id]=true
            var key: String = str(cell)
            if occupied.has(key) or int(cell[0])<4 or int(cell[1])<4 or int(cell[0])>=int(dims[0])-4 or int(cell[1])>=int(dims[1])-4:
                issues.append("Field site outside playable bounds / overlaps: "+id+"/"+site_id)
            occupied[key]=true
        if seen.size()!=4:
            issues.append("Missing authored field ecology sites: "+id)
        var challenge: Dictionary = spec.get("challenge",{})
        var gather: Dictionary = spec.get("gather",{})
        var secret: Dictionary = spec.get("secret",{})
        var reward: Dictionary = spec.get("reward",{})
        var title: String = str(challenge.get("title",""))
        var opening: String = str(secret.get("title",""))
        if challenge_titles.has(title) or passage_titles.has(opening) or title.is_empty() or opening.is_empty():
            issues.append("Field-specific trial/secret names are not independent: "+id)
        challenge_titles[title]=true
        passage_titles[opening]=true
        if str(challenge.get("danger_weather","")) not in ["rain","mist","ash"] or str(secret.get("opening_weather","")) not in ["clear","rain","mist","ash"]:
            issues.append("Invalid weather interaction: "+id)
        if str(secret.get("opening_time","")) not in ["dawn","day","dusk","night"]:
            issues.append("Invalid local discovery time: "+id)
        if not str(gather.get("item_id","")).begins_with("item_") or not str(reward.get("item_id","")).begins_with("item_"):
            issues.append("Field uses non-catalog reward identifier: "+id)
        if int(challenge.get("hp_cost",0))<=0 or int(challenge.get("speed_pct",0))<50 or int(challenge.get("speed_pct",100))>100:
            issues.append("Field exploration hazard is invalid: "+id)

func config(map_id: String) -> Dictionary:
    return maps.get(map_id,{})

func sites(map_id: String) -> Array:
    return (config(map_id) as Dictionary).get("sites",[])

static func _saved(state,map_id: String) -> Dictionary:
    return (state.rpg.get("field_ecology_v7",{}) as Dictionary).get(map_id,{}).duplicate(true)

static func snapshot(state,map_id: String) -> Dictionary:
    return _saved(state,map_id)

static func _write(state,map_id: String,status: Dictionary) -> void:
    var history: Dictionary = state.rpg.get("field_ecology_v7",{})
    history[map_id]=status.duplicate(true)
    state.rpg["field_ecology_v7"]=history

func completed(state,map_id: String) -> int:
    var status: Dictionary = _saved(state,map_id)
    var count: int = 0
    for key in ["trial","harvested","passage","claimed"]:
        if bool(status.get(key,false)):
            count+=1
    return count

func movement_multiplier(map_id: String,weather: String) -> float:
    var challenge: Dictionary = (config(map_id) as Dictionary).get("challenge",{})
    if challenge.is_empty() or str(challenge.get("danger_weather",""))!=weather:
        return 1.0
    return clampf(float(challenge.get("speed_pct",100))/100.0,0.5,1.0)

func encounter_multiplier(map_id: String,weather: String) -> float:
    return 1.20 if movement_multiplier(map_id,weather)<1.0 else 1.0

static func _time_window(window: String,minutes: int) -> bool:
    var hour: int = floori(float(posmod(minutes,1440))/60.0)
    match window:
        "dawn": return hour>=5 and hour<9
        "day": return hour>=9 and hour<17
        "dusk": return hour>=17 and hour<20
        "night": return hour>=20 or hour<5
    return false

func interact(map_id: String,action: String,state,weather: String,minutes: int,day: int) -> Dictionary:
    var info: Dictionary = config(map_id)
    if info.is_empty() or action not in SITE_IDS or state==null:
        return {"changed":false,"message":"这里没有对应的野外探索记录。"}
    var current: Dictionary = _saved(state,map_id)
    var challenge: Dictionary = info.get("challenge",{})
    var gathering: Dictionary = info.get("gather",{})
    var secret: Dictionary = info.get("secret",{})
    var reward: Dictionary = info.get("reward",{})
    match action:
        "trial":
            if bool(current.get("trial",false)):
                return {"changed":false,"message":"地形路线已勘定，队伍记住了安全落脚点。"}
            var hazardous: bool = weather==str(challenge.get("danger_weather",""))
            var cost: int = int(challenge.get("hp_cost",10)) if hazardous else maxi(1,floori(float(challenge.get("hp_cost",10))*0.5))
            for index in range(state.actors.size()):
                var member: Dictionary = state.actors[index]
                var hp: int = int(member.get("hp",1))
                if hp>0:
                    member["hp"]=maxi(1,hp-cost)
                    state.actors[index]=member
            current["trial"]=true
            _write(state,map_id,current)
            var warning: String = "（%s天气，存活队员损失至多 %d HP；不会致命）" % [weather,cost]
            return {"changed":true,"message":"【%s】%s\n%s" % [challenge.get("title","地貌挑战"),challenge.get("text",""),warning],"hazard":cost}
        "gather":
            if not bool(current.get("trial",false)):
                return {"changed":false,"message":"必须先勘察地貌与安全路线，才能接近采集点。"}
            if int(current.get("gather_day",-1))==day:
                return {"changed":false,"message":"今日这处采集点已采完。翌日会自然恢复，不能反复刷取。"}
            var bonus: int = 1 if weather==str(gathering.get("bonus_weather","")) else 0
            var qty: int = 1+bonus
            current["gather_day"]=day
            current["gather_total"]=int(current.get("gather_total",0))+1
            current["harvested"]=true
            _write(state,map_id,current)
            return {"changed":true,"message":"【%s】%s\n采得 %d 份地区素材。" % [gathering.get("title","野外采集"),gathering.get("text",""),qty],"reward":{"item_id":str(gathering.get("item_id","")),"amount":qty},"gather":true}
        "passage":
            if not bool(current.get("trial",false)) or not bool(current.get("harvested",false)):
                return {"changed":false,"message":"隐藏通道尚未定位：需要先完成地貌勘察，并取得当地采样。"}
            var active: bool = weather==str(secret.get("opening_weather","")) or _time_window(str(secret.get("opening_time","")),minutes)
            if not bool(current.get("passage",false)) and not active and int(current.get("gather_total",0))<2:
                return {"changed":false,"message":"【%s】此刻风向/光照无法辨认入口。可等候合适的时刻或天气，或在不同日期取得第二次采样来复原路线。" % secret.get("title","秘密通道")}
            var was_open: bool = bool(current.get("passage",false))
            current["passage"]=true
            _write(state,map_id,current)
            return {"changed":not was_open,"teleport":true,"message":"【%s】%s\n沿地图中真实的捷径前往暗藏宝匣。" % [secret.get("title","隐藏通道"),secret.get("text","")]}
        "cache":
            if not bool(current.get("passage",false)):
                return {"changed":false,"message":"秘藏仍在岩壁另一侧，必须先找到正确的隐藏入口。"}
            if bool(current.get("claimed",false)):
                return {"changed":false,"message":"这处隐藏秘藏已领取，不能反复获取。"}
            current["claimed"]=true
            _write(state,map_id,current)
            return {"changed":true,"message":"【%s】%s" % [reward.get("title","秘藏"),reward.get("text","")],"reward":{"gold":int(reward.get("gold",0)),"item_id":str(reward.get("item_id","")),"amount":int(reward.get("amount",1))},"claimed":true}
    return {"changed":false,"message":"未能识别野外探索动作。"}
