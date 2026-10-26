extends RefCounted
## Read-only bridge to B-owned furniture data. State mutations belong to D executor.
const Home = preload("res://scripts/world_home_interactions.gd")
const SAVE_BUCKET: String = "home_investigations_v1"
var source = Home.new()

func inspect(context: Dictionary, building_id: String, object_id: String,
        progress, owner_present: bool = false) -> Dictionary:
    var map_id: String=str(context.get("map_id",""))
    var output: Dictionary={"handled":false,"dialogue":[],"message":"",
        "effects":[],"animation":"","transition":{}}
    if map_id.is_empty() or building_id.is_empty() or object_id.is_empty() or progress==null:
        return output
    var item: Dictionary={}
    for obj in source.objects(map_id,building_id):
        if str(obj.get("id",""))==object_id:
            item=obj
            break
    if item.is_empty():
        output["message"]="这里没有开放的调查目标。"
        return output
    var phase: String="after" if bool(progress.flags.get(str(item.get("after_flag","")),false)) else "before"
    var key: String=map_id+"#"+building_id+"#"+object_id
    var snapshots: Dictionary=progress.rpg.get(SAVE_BUCKET,{})
    var record: Dictionary=snapshots.get(key,{})
    var seen: bool=bool(record.get("seen_"+phase,false))
    var text_value: String=str(item.get("repeat_text","它仍放在原来的位置。")) if seen else str(
        item.get("after_text",item.get("first_text","")) if phase=="after" else item.get("first_text",""))
    if owner_present and not str(item.get("owner_present_text","")).is_empty():
        text_value+="\n"+str(item["owner_present_text"])
    elif not owner_present and not str(item.get("owner_absent_text","")).is_empty():
        text_value+="\n"+str(item["owner_absent_text"])
    output["handled"]=true
    output["message"]="【"+str(item.get("name","室内物件"))+"】"+text_value
    output["animation"]="inspect"
    if not seen:
        output["effects"]=[{"type":"home_seen","key":key,"phase":phase}]
        output["event_id"]="d.home."+map_id+"."+building_id+"."+object_id+"."+phase
    return output

func entry(context: Dictionary, building: Dictionary) -> Dictionary:
    var response: Dictionary={"handled":false,"dialogue":[],"message":"",
        "effects":[],"animation":"","transition":{}}
    var room_id: String=str(building.get("id",""))
    var map_id: String=str(context.get("map_id",""))
    if map_id.is_empty() or room_id.is_empty() or not str(context.get("indoor_id","")).is_empty():
        return response
    var required: String=str(building.get("required_flag",""))
    var flags: Dictionary=context.get("story_flags",{})
    if not required.is_empty() and not bool(flags.get(required,false)):
        response["handled"]=true
        response["message"]="门还锁着。"
        return response
    var minutes: int=posmod(int(context.get("minutes",480)),1440)
    var hours: Array=building.get("open_hours",[])
    if hours.size()==2 and (minutes < int(hours[0])*60 or minutes >= int(hours[1])*60):
        response["handled"]=true
        response["message"]="这里尚未营业。"
        return response
    response["handled"]=true
    response["animation"]="open"
    response["transition"]={"mode":"enter","id":"door:"+map_id+":"+room_id,
        "from_map":map_id,"to_map":map_id,"building_id":room_id,
        "indoor_id":str(context.get("indoor_id",""))}
    return response
