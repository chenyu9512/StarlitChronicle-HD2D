extends RefCounted
## Chapter 47 authored non-Boss combat profiles. Existing monster identities,
## reward sources and HD2D art remain from EncounterRegistry. Never award
## rewards, alter quest flags, or pretend a specialized guard sprite exists.
const PROFILE_PATH: String = "res://story/runtime/act08_encounter_profiles.json"

static func _entry(squad_id: String) -> Dictionary:
    if squad_id.is_empty() or not FileAccess.file_exists(PROFILE_PATH):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    if not (parsed is Dictionary) or str(parsed.get("chapter_id","")) != "ch047":
        return {}
    var entries: Variant = parsed.get("squads",{})
    if not (entries is Dictionary):
        return {}
    var profile: Variant = entries.get(squad_id,{})
    if not (profile is Dictionary):
        return {}
    if str(profile.get("display_name","")).is_empty():
        return {}
    var count: int = int(profile.get("max_enemies",0))
    if count < 1 or count > 3:
        return {}
    for key in ["hp_ratio","atk_ratio","speed_ratio"]:
        var ratio: float = float(profile.get(key,0.0))
        if ratio < 0.5 or ratio > 1.5:
            return {}
    var defense_offset: int = int(profile.get("def_delta",-99))
    if defense_offset < -5 or defense_offset > 10:
        return {}
    return (profile as Dictionary).duplicate(true)

static func configured(squad_id: String) -> bool:
    return not _entry(squad_id).is_empty()

static func apply(formation, squad_id: String) -> Dictionary:
    var profile: Dictionary = _entry(squad_id)
    if profile.is_empty() or formation == null or formation.units.is_empty():
        return {"ok":false,"reason":"missing_rescue_combat_profile"}
    var adapted: Array[Dictionary] = []
    var limit: int = mini(int(profile.get("max_enemies",1)),formation.units.size())
    for i in range(limit):
        var original: Dictionary = formation.units[i]
        var enemy: Dictionary = original.duplicate(true)
        var hp: int = maxi(1,roundi(float(enemy.get("max_hp",1))*float(profile["hp_ratio"])))
        enemy["max_hp"] = hp
        enemy["hp"] = hp
        enemy["atk"] = maxi(1,roundi(float(enemy.get("atk",1))*float(profile["atk_ratio"])))
        enemy["def"] = maxi(0,int(enemy.get("def",0))+int(profile["def_delta"]))
        enemy["speed"] = maxi(1,roundi(float(enemy.get("speed",8))*float(profile["speed_ratio"])))
        enemy["name"] = str(profile["display_name"]) + (" · %d" % (i+1) if limit > 1 else "")
        # Preserve enemy.monster_id, region_id, xp, gold and art as provided
        # by EncounterRegistry. No forged bespoke enemy ID or boss flag.
        adapted.append(enemy)
    formation.units = adapted
    return {"ok":true,"name":str(profile["display_name"]),
        "hint":str(profile.get("tactical_hint","")),"count":adapted.size()}
