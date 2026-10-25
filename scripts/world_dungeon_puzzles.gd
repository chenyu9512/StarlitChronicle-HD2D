extends RefCounted
## Eight independently authored dungeon mechanisms. Stored inside existing save.rpg.
const SOURCE: String = "res://data/levels/v7/dungeon_puzzles.json"
const MODES: Array[String] = ["sequence","balance","circuit","water_level","mirror","time_phase","rhythm","dial"]
var maps: Dictionary = {}
var issues: Array[String] = []

func _init() -> void:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not data is Dictionary or str(data.get("schema",""))!="starlit.dungeon_puzzles.v7":
        issues.append("Invalid V7 dungeon puzzle registry")
        return
    maps = data.get("maps",{})
    if maps.size()!=8:
        issues.append("Expected eight original dungeon puzzles")
    var modes: Dictionary = {}
    for map_id in maps.keys():
        var info: Dictionary = maps[map_id]
        var mode: String = str(info.get("mode",""))
        if mode not in MODES or modes.has(mode):
            issues.append("Duplicate or unknown puzzle mode "+str(map_id))
        modes[mode]=true
        var components: Array = info.get("controls",[])
        var ids: Dictionary = {}
        for device in components:
            if not device is Dictionary:
                issues.append("Invalid puzzle device "+str(map_id))
                continue
            var id: String = str(device.get("id",""))
            var cell: Array = device.get("cell",[])
            if id not in ["a","b","c"] or ids.has(id) or cell.size()!=2:
                issues.append("Invalid puzzle device identity/position "+str(map_id))
            ids[id]=true
        if ids.size()!=3 or (info.get("seal",{}) as Dictionary).get("cell",[]).size()!=2:
            issues.append("Puzzle missing a device or its physical seal "+str(map_id))

func config(map_id: String) -> Dictionary:
    return maps.get(map_id,{})

func devices(map_id: String) -> Array:
    var info: Dictionary = config(map_id)
    if info.is_empty():
        return []
    var records: Array = info.get("controls",[]).duplicate(true)
    records.append((info.get("seal",{}) as Dictionary).duplicate(true))
    return records

static func _saved(state, map_id: String) -> Dictionary:
    var storage: Dictionary = state.rpg.get("dungeon_puzzles_v7",{})
    return (storage.get(map_id,{}) as Dictionary).duplicate(true)

static func snapshot(state, map_id: String) -> Dictionary:
    return _saved(state,map_id)

static func _write(state, map_id: String, status: Dictionary) -> void:
    var storage: Dictionary = state.rpg.get("dungeon_puzzles_v7",{})
    storage[map_id] = status.duplicate(true)
    state.rpg["dungeon_puzzles_v7"] = storage

static func _matches(left: Array, right: Array) -> bool:
    return left.size()==right.size() and left==right

func _ready_to_open(record: Dictionary, values: Dictionary) -> bool:
    var mode: String = str(record.get("mode",""))
    match mode:
        "sequence","rhythm":
            return int(values.get("index",0)) == (record.get("pattern",[]) as Array).size()
        "balance":
            return int(values.get("level",0))==int(record.get("target",3)) and bool(values.get("locked",false))
        "circuit":
            return _matches(values.get("lamps",[0,0,0]),record.get("target",[]))
        "water_level":
            return int(values.get("level",1))==int(record.get("target",2)) and bool(values.get("observed",false)) and int(values.get("raised",0))>0 and int(values.get("drained",0))>0
        "mirror":
            return _matches(values.get("angles",[0,0]),record.get("target",[])) and bool(values.get("flipped",false))
        "time_phase":
            return int(values.get("phase",0))==int(record.get("target",3)) and (values.get("touched",[]) as Array).size()==3
        "dial":
            return _matches(values.get("dials",[0,0,0]),record.get("target",[]))
    return false

func interact(map_id: String, button: String, state) -> Dictionary:
    var info: Dictionary = config(map_id)
    if info.is_empty() or button not in ["a","b","c","seal"] or state==null:
        return {"message":"这里没有可以操作的古代装置。","changed":false}
    var status: Dictionary = _saved(state,map_id)
    if bool(status.get("claimed",false)):
        return {"message":"【%s】机关已解开，典藏宝物也已领取。" % info.get("title","古机关"),"changed":false}
    if button=="seal":
        if not _ready_to_open(info,status):
            return {"message":"【%s】封印尚未解除。\n%s" % [info.get("title","古机关"),info.get("hint","")],"changed":false}
        status["claimed"]=true
        _write(state,map_id,status)
        return {"message":"【%s】古代装置的光纹依次亮起，封印的秘藏终于打开！" % info.get("title","古机关"),"changed":true,"reward":info.get("reward",{}),"completed":true}
    var mode: String = str(info.get("mode",""))
    var action_text: String = ""
    match mode:
        "sequence","rhythm":
            var order: Array = info.get("pattern",[])
            var index: int = int(status.get("index",0))
            if index>=order.size():
                action_text="全部音纹已经对齐，前往宝柜确认。"
            elif str(order[index])==button:
                index+=1
                status["index"]=index
                action_text="%s %d / %d 道纹路已响应。" % ["潮门" if mode=="sequence" else "星钟",index,order.size()]
            else:
                status["index"]=0
                action_text="节序不符，光纹熄灭；需要重新检查地面的符号。"
        "balance":
            var level: int = int(status.get("level",0))
            if button=="a":
                status["level"]=clampi(level+2,-4,6)
            elif button=="b":
                status["level"]=clampi(level-1,-4,6)
            else:
                status["locked"]=true
            action_text="守誓天平的刻度：%d；%s。" % [int(status.get("level",0)),"指针已固定" if bool(status.get("locked",false)) else "仍未固定"]
        "circuit":
            var lamps: Array = status.get("lamps",[0,0,0]).duplicate()
            var turns: Array = {"a":[0,1],"b":[1,2],"c":[0,1,2]}[button]
            for cell in turns:
                lamps[int(cell)]=1-int(lamps[int(cell)])
            status["lamps"]=lamps
            var lit_labels: PackedStringArray = PackedStringArray()
            for value in lamps:
                lit_labels.append("亮" if int(value)==1 else "暗")
            action_text="导电线依次显示：%s。" % " · ".join(lit_labels)
        "water_level":
            var wave: int = int(status.get("level",1))
            if button=="a":
                status["level"]=mini(3,wave+1)
                status["raised"]=int(status.get("raised",0))+1
            elif button=="b":
                status["level"]=maxi(0,wave-1)
                status["drained"]=int(status.get("drained",0))+1
            else:
                status["observed"]=true
            action_text="目前蓄水线为第 %d 格；%s。" % [int(status.get("level",1)),"水位已记录" if bool(status.get("observed",false)) else "还需读取观测灯"]
        "mirror":
            var angles: Array = status.get("angles",[0,0]).duplicate()
            if button=="a":
                angles[0]=(int(angles[0])+1)%4
            elif button=="b":
                angles[1]=(int(angles[1])+1)%4
            else:
                status["flipped"]=not bool(status.get("flipped",false))
            status["angles"]=angles
            action_text="左右折光方位为 %d / %d；镜像%s。" % [int(angles[0]),int(angles[1]),"反转" if bool(status.get("flipped",false)) else "正常"]
        "time_phase":
            var phase: int = int(status.get("phase",0))
            status["phase"]=(phase+({"a":1,"b":-1,"c":2}[button])+4)%4
            var touched: Array = status.get("touched",[]).duplicate()
            if button not in touched:
                touched.append(button)
            status["touched"]=touched
            action_text="时钟相位来到第 %d 刻；已检查 %d / 3 座转轮。" % [int(status["phase"]),touched.size()]
        "dial":
            var dials: Array = status.get("dials",[0,0,0]).duplicate()
            var slot: int = ["a","b","c"].find(button)
            dials[slot]=(int(dials[slot])+1)%3
            status["dials"]=dials
            action_text="灯网三盘当前停在 %d / %d / %d 档。" % [int(dials[0]),int(dials[1]),int(dials[2])]
    _write(state,map_id,status)
    if _ready_to_open(info,status):
        action_text+="\n所有校准已符合记录，可前往典藏宝柜。"
    return {"message":"【%s】%s" % [info.get("title","古机关"),action_text],"changed":true,"completed":false}
