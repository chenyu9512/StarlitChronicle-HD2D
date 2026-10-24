extends RefCounted
## 全游戏共用的装备、背包、职业、技能、任务、图鉴和商店引擎。
const CATEGORIES: Array[String] = ["characters","npcs","regions","maps","monsters","bosses","weapons","armor","items","skills","quests"]
const SLOTS: Array[String] = ["weapon","head","body","hand","legs","accessory"]
var state
var tables: Dictionary = {}
var indices: Dictionary = {}
var jobs: Dictionary = {}

func bind(progress) -> void:
    state = progress
    for category in CATEGORIES:
        var table: Dictionary = _read("res://data/content/%s.json" % category)
        tables[category] = table.get("entries", [])
        var index: Dictionary = {}
        for entry in tables[category]:
            if entry is Dictionary:
                index[str(entry.get("id",""))] = entry
        indices[category] = index
    var pack: Dictionary = _read("res://story/data/jobs.json")
    for job in pack.get("jobs", []):
        if job is Dictionary:
            jobs[str(job.get("id",""))] = job
    if not (state.rpg is Dictionary):
        state.rpg = {}
    for key in ["equipment","jobs","quests","regions","discovered","settings"]:
        if not (state.rpg.get(key) is Dictionary):
            state.rpg[key] = {}
    if not (state.rpg.get("party") is Array):
        state.rpg["party"] = []
    for actor in state.actors:
        register_actor(str(actor.get("id","")))
    state.rpg["regions"][location_name(state.chapter)] = true
    state.inventory["item_herb_01"] = maxi(state.potions, int(state.inventory.get("item_herb_01",0)))

func _read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

func records(category: String) -> Array:
    return tables.get(category, [])

func entry(category: String, key: String) -> Dictionary:
    return (indices.get(category,{}) as Dictionary).get(key,{})

func register_actor(id: String) -> void:
    if id.is_empty():
        return
    if not state.rpg["equipment"].has(id):
        state.rpg["equipment"][id] = {}
    if not state.rpg["jobs"].has(id):
        state.rpg["jobs"][id] = "healer" if id == "char_tidecaller" else ("ranger" if id == "char_seeker" else "swordsman")
    var party: Array = state.rpg["party"]
    if id not in party and party.size() < 4:
        party.append(id)

func actor_index(id: String) -> int:
    for i in range(state.actors.size()):
        if str(state.actors[i].get("id","")) == id:
            return i
    return -1

func display_name(id: String) -> String:
    for c in ["items","weapons","armor"]:
        var item: Dictionary = entry(c,id)
        if not item.is_empty():
            return str(item.get("name",id))
    return id

func count(id: String) -> int:
    return maxi(0,int(state.inventory.get(id,0)))

func add_item(id: String, amount: int) -> void:
    if amount < 1 or (entry("items",id).is_empty() and entry("weapons",id).is_empty() and entry("armor",id).is_empty()):
        return
    state.inventory[id] = count(id) + amount
    _herbs()

func take_item(id: String, amount: int) -> bool:
    if amount < 1 or count(id) < amount:
        return false
    state.inventory[id] = count(id) - amount
    if count(id) == 0:
        state.inventory.erase(id)
    _herbs()
    return true

func _herbs() -> void:
    state.potions = count("item_herb_01")

func gear_stats(id: String) -> Dictionary:
    var idx: int = actor_index(id)
    if idx < 0:
        return {}
    var actor: Dictionary = state.actors[idx]
    var result: Dictionary = {"attack":int(actor.get("attack",0)),"defense":int(actor.get("defense",0)),"magic":0,"speed":int(actor.get("speed",0)),"max_hp":int(actor.get("max_hp",0)),"max_mp":int(actor.get("max_mp",0))}
    var slots: Dictionary = state.rpg["equipment"].get(id,{})
    for slot in slots:
        var object: Dictionary = entry("weapons",str(slots[slot])) if str(slot) == "weapon" else entry("armor",str(slots[slot]))
        for stat in ["attack","defense","magic"]:
            result[stat] += int(object.get(stat,0))
        var bonus: Dictionary = object.get("bonus",{})
        var amount: int = int(bonus.get("power",0))
        match str(bonus.get("kind","")):
            "生命": result["max_hp"] += amount
            "魔力": result["max_mp"] += amount
            "攻击": result["attack"] += amount
            "防御": result["defense"] += amount
            "速度": result["speed"] += amount
    return result

func equip(id: String, slot: String, item_id: String) -> String:
    if actor_index(id) < 0 or slot not in SLOTS or count(item_id) < 1:
        return "目标或装备库存无效。"
    var info: Dictionary = entry("weapons",item_id) if slot == "weapon" else entry("armor",item_id)
    if info.is_empty():
        return "这件物品不属于该装备类型。"
    if slot != "weapon" and str(info.get("slot","")) != slot:
        return "不适合这个装备槽位。"
    if slot == "weapon":
        var tags: Array = info.get("job_tags",[])
        var job: String = str(state.rpg["jobs"].get(id,"swordsman"))
        if not tags.is_empty() and job not in tags and not (job == "swordsman" and "wayfarer" in tags):
            return "当前职业不能使用此武器。"
    var slots: Dictionary = state.rpg["equipment"].get(id,{})
    var old: String = str(slots.get(slot,""))
    if not take_item(item_id,1):
        return "库存不足。"
    if not old.is_empty():
        add_item(old,1)
    slots[slot] = item_id
    state.rpg["equipment"][id] = slots
    return "装备成功：" + display_name(item_id)

func unequip(id: String, slot: String) -> String:
    var slots: Dictionary = state.rpg["equipment"].get(id,{})
    if not slots.has(slot):
        return "这个位置没有装备。"
    var old: String = str(slots[slot])
    slots.erase(slot)
    state.rpg["equipment"][id] = slots
    add_item(old,1)
    return "装备已放回背包。"

func buy(id: String) -> String:
    var info: Dictionary = {}
    for cat in ["items","weapons","armor"]:
        info = entry(cat,id)
        if not info.is_empty():
            break
    var cost: int = int(info.get("buy_price",info.get("price",0)))
    if cost < 1 or state.gold < cost:
        return "金币不足或无法购买。"
    state.gold -= cost
    add_item(id,1)
    return "购买了 " + display_name(id)

func sell(id: String) -> String:
    if count(id) < 1:
        return "背包里没有此物品。"
    var info: Dictionary = {}
    for cat in ["items","weapons","armor"]:
        info = entry(cat,id)
        if not info.is_empty():
            break
    var cost: int = int(info.get("sell_price",int(info.get("buy_price",info.get("price",0))) / 2))
    if cost < 1:
        return "不可出售。"
    take_item(id,1)
    state.gold += cost
    return "出售获得 %dG。" % cost

func use_item(id: String, actor_id: String) -> String:
    var i: int = actor_index(actor_id)
    if i < 0 or count(id) < 1:
        return "目标或背包数量不足。"
    var record: Dictionary = entry("items",id)
    var effect: Dictionary = record.get("effect",{})
    var actor: Dictionary = state.actors[i]
    var field: String = ""
    match str(effect.get("kind","")):
        "heal_hp": field = "hp"
        "heal_mp": field = "mp"
        _: return "此物品没有可在菜单使用的效果。"
    var cap: String = "max_" + field
    if int(actor.get(field,0)) >= int(actor.get(cap,0)):
        return "状态已满，无须使用。"
    actor[field] = mini(int(actor[cap]),int(actor[field]) + int(effect.get("power",0)))
    state.actors[i] = actor
    take_item(id,1)
    return "使用了 " + display_name(id)

func change_job(id: String, job: String) -> String:
    if actor_index(id) < 0 or not jobs.has(job):
        return "职业不可用。"
    state.rpg["jobs"][id] = job
    return "已转职：" + str(jobs[job].get("name",job))

func job_name(id: String) -> String:
    return str((jobs.get(id,{}) as Dictionary).get("name",id))

func _skill_track(job: String) -> String:
    var tracks: Dictionary = {
        "swordsman":"wayfarer", "guardian":"vanguard", "monk":"vanguard",
        "ranger":"seeker", "healer":"tidecaller", "mage":"mirrorweaver",
        "engineer":"smith", "bard":"cantor", "star_knight":"wayfarer",
        "shadow_blade":"seeker", "high_priest":"tidecaller",
        "element_archmage":"mirrorweaver", "beast_keeper":"seeker",
        "arc_gunner":"navigator", "war_singer":"cantor",
        "star_smith":"smith", "oath_keeper":"vanguard",
        "time_scholar":"mirrorweaver", "celestial_sailor":"navigator",
        "allmaker":"alchemist"
    }
    return str(tracks.get(job,job))

func skills(id: String) -> Array:
    var result: Array = []
    var i: int = actor_index(id)
    if i < 0:
        return result
    var job: String = _skill_track(str(state.rpg["jobs"].get(id,"swordsman")))
    var level: int = int(state.actors[i].get("level",1))
    for skill in records("skills"):
        if str(skill.get("job_id","")) == job and level >= int(skill.get("unlock_level",999)):
            result.append(skill)
    return result

func toggle_party(id: String) -> String:
    if actor_index(id) < 0:
        return "此伙伴尚未加入。"
    var party: Array = state.rpg["party"]
    if id in party:
        if party.size() < 2:
            return "至少要有一人出战。"
        party.erase(id)
    else:
        if party.size() >= 4:
            return "最多四人出战。"
        party.append(id)
    return "阵容已经更新。"

func is_active(id: String) -> bool:
    return id in state.rpg["party"]

func forge(id: String) -> String:
    var current: Dictionary = entry("weapons",id)
    if current.is_empty() or count(id) < 2:
        return "需要两把同型号武器。"
    var next: Dictionary = {}
    for candidate in records("weapons"):
        if str(candidate.get("family","")) == str(current.get("family","")) and int(candidate.get("tier",0)) == int(current.get("tier",0)) + 1:
            next = candidate
            break
    if next.is_empty():
        return "没有下一阶可用配方。"
    var price: int = maxi(20,int(next.get("price",0)) / 3)
    if state.gold < price:
        return "锻造需要 %dG。" % price
    take_item(id,2)
    state.gold -= price
    add_item(str(next.get("id","")),1)
    return "锻造成品：" + str(next.get("name","武器"))

func register_chapter(chapter: int) -> void:
    state.rpg["regions"][location_name(chapter)] = true

func chapter_data(chapter: int) -> Dictionary:
    if chapter < 1 or chapter > 72:
        return {}
    var act: int = int((chapter - 1)/6) + 1
    for item in _read("res://story/campaign/act_%02d.json" % act).get("chapters",[]):
        if int(item.get("number",0)) == chapter:
            return item
    return {}

func chapter_name(chapter: int) -> String:
    if chapter == 0:
        return "童年序章"
    return str(chapter_data(chapter).get("title","第%d章" % chapter))

func location_name(chapter: int) -> String:
    if chapter == 0:
        return "晨露村·星灯祭"
    return str(chapter_data(chapter).get("location","远方"))

func record_quest(id: String) -> String:
    var q: Dictionary = entry("quests",id)
    if q.is_empty():
        return "没有对应任务。"
    if state.rpg["quests"].has(id):
        return "奖励已经领取。"
    state.rpg["quests"][id] = true
    var rewards: Dictionary = q.get("rewards",{})
    state.give_rewards(int(rewards.get("xp",0)),int(rewards.get("gold",0)))
    return "已记录任务完成：" + str(q.get("name",id))

func recruit_from_story(chapter: int) -> String:
    var story: Dictionary = _read("res://story/data/characters.json")
    for person in story.get("cast",[]):
        if str(person.get("join_chapter","")) != "ch%03d" % chapter:
            continue
        var n: String = str(person.get("name",""))
        var id: String = str(person.get("id",""))
        if n in ["主角","岚音","朔弦"]:
            continue
        var pid: String = "cast_" + id
        if actor_index(pid) >= 0:
            continue
        var level: int = maxi(1, chapter + 2)
        var actor: Dictionary = {"id":pid,"name":n,"level":level,"xp":0,"hp":110+level*11,"max_hp":110+level*11,"mp":42+level*5,"max_mp":42+level*5,"attack":14+level*4,"defense":7+level*2,"speed":12,"skill":"星辉击"}
        state.actors.append(actor)
        register_actor(pid)
        return n + "加入了队伍。"
    return ""
