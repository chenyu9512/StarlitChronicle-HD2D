extends RefCounted
## 单机住宅。地契、家具库存、放置格、仓库均永久保存于State.rpg["housing"]。
const WIDTH: int = 10
const HEIGHT: int = 7
const LAND_PRICE: int = 160
var catalog: Dictionary = {}
var goods: Dictionary = {}
var recipes: Array = []
var progress

func _init() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/content/housing.json"))
    catalog = parsed if parsed is Dictionary else {}
    var cooking: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/content/housing_recipes.json"))
    if cooking is Dictionary:
        recipes = cooking.get("recipes",[])
    for item in catalog.get("furniture",[]):
        if item is Dictionary:
            goods[str(item.get("id",""))] = item

func bind(save_state) -> void:
    progress = save_state
    if not progress.rpg.get("housing") is Dictionary:
        progress.rpg["housing"] = {}
    var h: Dictionary = progress.rpg["housing"]
    if not h.get("stock") is Dictionary:
        h["stock"] = {}
    if not h.get("warehouse") is Dictionary:
        h["warehouse"] = {}
    if not h.get("placed") is Array:
        h["placed"] = []
    if not h.has("owned"):
        h["owned"] = false
    if not h.has("tier"):
        h["tier"] = 0
    if not h.has("wall"):
        h["wall"] = "海砂白"
    if not h.has("floor"):
        h["floor"] = "橡木棕"
    if not h.has("region_id"):
        h["region_id"] = "region_coast"

func data() -> Dictionary:
    return progress.rpg["housing"]

func owned() -> bool:
    return bool(data().get("owned",false))

func can_access(map_info: Dictionary) -> bool:
    return str(map_info.get("kind","")) == "town" or str(map_info.get("kind","")) == "residential"

func purchase(map_info: Dictionary) -> String:
    if owned():
        return "已经拥有一间冒险者之家。"
    if progress.chapter < 1 or not can_access(map_info):
        return "只能在开放的城镇住宅区购买地契。"
    if progress.gold < LAND_PRICE:
        return "购买地契需要 %dG。" % LAND_PRICE
    progress.gold -= LAND_PRICE
    var h: Dictionary = data()
    h["owned"] = true
    h["region_id"] = str(map_info.get("region_id","region_coast"))
    h["stock"] = {"bed_oak":1,"chest_oak":1}
    h["placed"] = []
    place("bed_oak",2,1)
    place("chest_oak",7,1)
    return "成功购得冒险者之家！附赠床与旅行木箱。"

func item(id: String) -> Dictionary:
    return goods.get(id,{})

func buy_furniture(id: String) -> String:
    if not owned() or not goods.has(id):
        return "请先购置住宅。"
    var entry: Dictionary = goods[id]
    if int(entry.get("tier",0)) > int(data().get("tier",0)):
        return "房屋等级不足，需要升级。"
    var price: int = int(entry.get("price",0))
    if price < 1 or progress.gold < price:
        return "金币不足。"
    progress.gold -= price
    var stock: Dictionary = data()["stock"]
    stock[id] = int(stock.get(id,0)) + 1
    return "购入家具：" + str(entry.get("name",""))

func stock(id: String) -> int:
    return maxi(0,int(data()["stock"].get(id,0)))

func at(x: int, y: int) -> Dictionary:
    for placed in data()["placed"]:
        if int(placed.get("x",-1)) == x and int(placed.get("y",-1)) == y:
            return placed
    return {}

func place(id: String, x: int, y: int) -> String:
    if not owned() or not goods.has(id):
        return "家具无法使用。"
    if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
        return "超出房间边界。"
    if (x == 4 or x == 5) and y == HEIGHT - 1:
        return "请保持大门通道畅通。"
    if not at(x,y).is_empty():
        return "这里已有家具，请先收起。"
    if stock(id) < 1:
        return "家具库存不足。"
    if (data()["placed"] as Array).size() >= capacity():
        return "房屋家具数量已达上限，请升级。"
    data()["stock"][id] = stock(id) - 1
    (data()["placed"] as Array).append({"id":id,"x":x,"y":y})
    return "已布置：" + str(goods[id].get("name",""))

func remove_at(x: int, y: int) -> String:
    var h: Dictionary = data()
    var placed: Array = h["placed"]
    for i in range(placed.size()):
        var record: Dictionary = placed[i]
        if int(record.get("x",-1)) == x and int(record.get("y",-1)) == y:
            var id: String = str(record.get("id",""))
            placed.remove_at(i)
            h["stock"][id] = stock(id) + 1
            return "已收回：" + str(goods.get(id,{}).get("name",id))
    return "这里没有家具。"

func capacity() -> int:
    return 12 + int(data().get("tier",0)) * 6

func warehouse_capacity() -> int:
    var chests: int = 0
    for record in data()["placed"]:
        if str(goods.get(str(record.get("id","")),{}).get("effect","")) == "storage":
            chests += 1
    if chests == 0:
        return 0
    return chests * 20 + int(data().get("tier",0)) * 20

func warehouse_total() -> int:
    var sum: int = 0
    for id in data()["warehouse"]:
        sum += maxi(0,int(data()["warehouse"][id]))
    return sum

func deposit(id: String, quantity: int = 1) -> String:
    if not owned() or not has_effect("storage"):
        return "需要先摆放储物柜才能使用仓库。"
    if quantity < 1 or not progress.inventory.has(id):
        return "背包没有这件物品。"
    if int(progress.inventory[id]) < quantity:
        return "背包物品数量不足。"
    if warehouse_total()+quantity > warehouse_capacity():
        return "住宅仓库已经存满。"
    progress.inventory[id] = int(progress.inventory[id]) - quantity
    if int(progress.inventory[id]) == 0:
        progress.inventory.erase(id)
    var store: Dictionary = data()["warehouse"]
    store[id] = int(store.get(id,0)) + quantity
    _sync_herbs()
    return "已经存入：" + id

func withdraw(id: String, quantity: int = 1) -> String:
    if not owned() or not has_effect("storage"):
        return "需要先摆放储物柜才能取出物品。"
    var store: Dictionary = data()["warehouse"]
    if not owned() or quantity < 1 or int(store.get(id,0)) < quantity:
        return "住宅仓库库存不足。"
    store[id] = int(store[id]) - quantity
    if int(store[id]) == 0:
        store.erase(id)
    progress.inventory[id] = int(progress.inventory.get(id,0)) + quantity
    _sync_herbs()
    return "已经取出：" + id

func _sync_herbs() -> void:
    progress.potions = int(progress.inventory.get("item_herb_01",0))

func upgrade() -> String:
    if not owned():
        return "尚未拥有住宅。"
    var tier: int = int(data().get("tier",0))
    var cost: Array = catalog.get("upgrade_prices",[300,700,1300])
    if tier >= cost.size():
        return "房屋已经升级到最高等级。"
    if progress.gold < int(cost[tier]):
        return "升级需要 %dG。" % int(cost[tier])
    progress.gold -= int(cost[tier])
    data()["tier"] = tier + 1
    return "升级成功：住宅等级 %d。" % (tier+2)

func recolor(part: String, palette: String) -> String:
    var choices: Dictionary = {"wall":["海砂白","星夜蓝","银镜灰","森林青"],"floor":["橡木棕","海盐灰","赤炉红","天轨紫"]}
    if not owned() or not choices.has(part) or palette not in choices[part]:
        return "无法使用这个装修颜色。"
    data()[part] = palette
    return "已更换室内装修。"

func has_effect(effect: String) -> bool:
    for placed in data()["placed"]:
        if str(goods.get(str(placed.get("id","")),{}).get("effect","")) == effect:
            return true
    return false

func rest() -> String:
    if not owned() or not has_effect("rest"):
        return "请先在房屋中摆放一张床。"
    progress.heal_all()
    return "全队在家中休息，HP与MP完全恢复。"

func valid_layout() -> bool:
    var seen: Dictionary = {}
    if (data()["placed"] as Array).size() > capacity():
        return false
    for p in data()["placed"]:
        var x: int = int(p.get("x",-1))
        var y: int = int(p.get("y",-1))
        var key: String = "%d:%d" % [x,y]
        if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT or seen.has(key):
            return false
        seen[key] = true
    return true

func cook(recipe_id: String) -> String:
    if not owned() or not has_effect("cook"):
        return "请先在房间布置灶台。"
    for formula in recipes:
        if str(formula.get("id","")) != recipe_id:
            continue
        var ingredients: Dictionary = formula.get("ingredients",{})
        for ingredient in ingredients:
            if int(progress.inventory.get(ingredient,0)) < int(ingredients[ingredient]):
                return "食材不足：" + str(ingredient)
        var cost: int = int(formula.get("gold",0))
        if progress.gold < cost:
            return "烹饪金币不足。"
        var food: String = str(formula.get("output",""))
        if food.is_empty():
            return "烹饪配方无效。"
        for ingredient in ingredients:
            progress.inventory[ingredient] = int(progress.inventory.get(ingredient,0)) - int(ingredients[ingredient])
            if int(progress.inventory[ingredient]) <= 0:
                progress.inventory.erase(ingredient)
        progress.gold -= cost
        progress.inventory[food] = int(progress.inventory.get(food,0)) + 1
        _sync_herbs()
        return "制作成功：" + str(formula.get("name",food))
    return "未找到这份食谱。"
