extends RefCounted
## 多敌人遭遇编队；只负责敌方队列、目标与奖励，不修改玩家或剧情状态。
var units: Array[Dictionary] = []

func start(encounter, chapter: int, boss: bool, primary: Dictionary) -> void:
    units.clear()
    units.append(primary.duplicate(true))
    if boss:
        return
    var number: int = 1 + int(chapter >= 4) + int(chapter >= 19)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    number = rng.randi_range(1, mini(3,number))
    for i in range(1,number):
        var monster: Dictionary = encounter.roll_monster(chapter)
        if not monster.is_empty():
            units.append(monster)

func alive_indices() -> Array[int]:
    var alive: Array[int] = []
    for i in range(units.size()):
        if int(units[i].get("hp",0)) > 0:
            alive.append(i)
    return alive

func valid_target(index: int) -> bool:
    return index >= 0 and index < units.size() and int(units[index].get("hp",0)) > 0

func target(index: int) -> Dictionary:
    return units[index] if valid_target(index) else {}

func apply_damage(index: int, value: int) -> int:
    if not valid_target(index):
        return 0
    var enemy: Dictionary = units[index]
    var dealt: int = mini(int(enemy.get("hp",0)),maxi(0,value))
    enemy["hp"] = maxi(0,int(enemy["hp"])-dealt)
    units[index] = enemy
    return dealt

func complete() -> bool:
    return alive_indices().is_empty()

func rewards() -> Dictionary:
    var xp: int = 0
    var gold: int = 0
    for unit in units:
        xp += maxi(0,int(unit.get("xp",0)))
        gold += maxi(0,int(unit.get("gold",0)))
    return {"xp":xp,"gold":gold}

func names() -> String:
    var result: Array[String] = []
    for unit in units:
        if int(unit.get("hp",0)) > 0:
            result.append(str(unit.get("name","")))
    return "、".join(result)
