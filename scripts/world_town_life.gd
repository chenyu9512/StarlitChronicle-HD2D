extends RefCounted
## Regional residents, shop inventories and daily guild requests.
## All interactions are offline and stored in the existing game state; no API calls.
const NPCS_PATH: String = "res://data/content/npcs.json"
const REGIONS: Array[String] = [
    "region_coast","region_oaths","region_forge","region_isles",
    "region_mirror","region_oldland","region_sanctum","region_city"
]
const CITIZEN_DAY: Array[Vector2i] = [
    Vector2i(49,36),Vector2i(58,24),Vector2i(12,38),
    Vector2i(51,7),Vector2i(61,37)
]
const CITIZEN_NIGHT: Array[Vector2i] = [
    Vector2i(49,29),Vector2i(58,35),Vector2i(12,35),
    Vector2i(51,13),Vector2i(61,30)
]
const DIALOGUE: Dictionary = {
    "region_coast":["涨潮前，别往海洞深处走。","晨露村的老井，记得上一代守灯人的故事。","港口的旧航图记录着安全浅滩。"],
    "region_oaths":["三誓门的钟声代表新的巡逻换班。","山径上的银鹫哨塔会回应灯光。","守卫和旅人都须遵守城门宵禁。"],
    "region_forge":["炉区夜班的工人需要清泉叶。","灰烬轨道还留有旧矿主的标记。","锻造炉火越旺，越应注意风道。"],
    "region_isles":["这片群岛的航道会随着潮汐改变。","夜里可以凭岸上的灯火判断方向。","各岛的珊瑚颜色提醒我们水温变化。"],
    "region_mirror":["镜湖上的倒影不总能说明真相。","夜色中的森林路标容易看错。","银玻璃塔的镜子反射星辰。"],
    "region_oldland":["遗迹的碑文记载了旧洲的迁徙。","大峡谷的风声像失去的时钟。","测绘员的工作不能靠猜测完成。"],
    "region_sanctum":["天轨会记录每一次诚实的抉择。","光芒明亮之处也有阴影。","祭坛守望者只会指引，不代替选择。"],
    "region_city":["新城市的每盏灯都要有人维护。","居民街欢迎来自世界各地的人。","自由议事厅里人人都有发表意见的权利。"]
}
var citizens: Dictionary = {}

func _init() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPCS_PATH))
    if raw is Dictionary:
        for record in raw.get("entries",[]):
            if record is Dictionary:
                var region: String = str(record.get("region_id",""))
                if not citizens.has(region):
                    citizens[region] = []
                (citizens[region] as Array).append(record)

func residents(region_id: String) -> Array:
    return citizens.get(region_id,[]).duplicate()

func position_for(index: int, hour: int) -> Vector2i:
    var candidates: Array[Vector2i] = CITIZEN_NIGHT if hour < 6 or hour >= 20 else CITIZEN_DAY
    return candidates[index % candidates.size()]

func talk(npc_id: String, region_id: String, clock: Dictionary, state) -> Dictionary:
    var citizen: Dictionary = {}
    for entry in residents(region_id):
        if str(entry.get("id","")) == npc_id:
            citizen = entry
            break
    if citizen.is_empty():
        return {"text":"这里没有人回应。","first":false}
    if not state.rpg.get("talked_to") is Dictionary:
        state.rpg["talked_to"] = {}
    var talked: Dictionary = state.rpg["talked_to"]
    var first: bool = not talked.has(npc_id)
    talked[npc_id] = true
    var day: int = int(clock.get("day",1))
    var rotation: int = abs(npc_id.hash()+day) % 3
    var lines: Array = DIALOGUE.get(region_id,["旅行时注意安全。"])
    var quote: String = str(lines[rotation % lines.size()])
    var occupation: String = str(citizen.get("role","lore"))
    var suffix: String = ""
    match occupation:
        "shop": suffix = "若需要补给，可以去商店。"
        "craft": suffix = "工房里也许有你需要的技艺。"
        "quest": suffix = "冒险者公会会记录这片地区的委托。"
        "rumor": suffix = "这片地方每天都有新的消息。"
        _: suffix = "旅途上的故事值得被记住。"
    return {
        "name":str(citizen.get("name",npc_id)),
        "text":"%s\n%s" % [quote,suffix],
        "first":first
    }

func town_shop_ids(region_id: String,core) -> Array[String]:
    var tier: int = maxi(0,REGIONS.find(region_id))
    var stock: Array[String] = [
        "item_herb_%02d" % clampi(tier+1,1,10),
        "item_ether_%02d" % clampi(tier+1,1,10)
    ]
    var weapon_id: String = "wpn_sword_%02d" % clampi(tier+1,1,7)
    if not core.entry("weapons",weapon_id).is_empty():
        stock.append(weapon_id)
    return stock

func guild_progress(region_id: String,state) -> Dictionary:
    if not state.rpg.get("guild_contracts") is Dictionary:
        state.rpg["guild_contracts"] = {}
    var contracts: Dictionary = state.rpg["guild_contracts"]
    var record: Dictionary = contracts.get(region_id,{})
    if record.is_empty():
        return {"state":"available","needed":3,"progress":0}
    var battles: int = int(state.rpg.get("event_counters",{}).get("battle_victory",0))
    var progress: int = maxi(0,battles-int(record.get("battle_at",0)))
    if bool(record.get("claimed",false)):
        return {"state":"claimed","progress":progress,"needed":3}
    return {"state":"ready" if progress>=3 else "active","progress":progress,"needed":3}

func guild_action(region_id: String,state) -> String:
    var records: Dictionary = state.rpg.get("guild_contracts",{})
    var current: Dictionary = guild_progress(region_id,state)
    match str(current.get("state","")):
        "available":
            records[region_id] = {
                "battle_at":int(state.rpg.get("event_counters",{}).get("battle_victory",0)),
                "claimed":false
            }
            state.rpg["guild_contracts"] = records
            return "已接取地区讨伐委托：累计战胜3场战斗后回来领取报酬。"
        "active":
            return "正在执行：%d / 3 场胜利。冒险者安全第一。" % int(current.get("progress",0))
        "ready":
            var reward: int = 80+20*maxi(0,REGIONS.find(region_id))
            state.gold += reward
            var log: Dictionary = records[region_id]
            log["claimed"] = true
            records[region_id] = log
            state.rpg["guild_contracts"] = records
            return "地区讨伐完成！获得 %d G，已记入公会档案。" % reward
        _:
            return "本地区讨伐已完成。欢迎探索下一地区。"
