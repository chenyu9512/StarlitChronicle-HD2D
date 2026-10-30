extends RefCounted
## Chapter-47 rescue encounters select ONLY the canonically eligible fighting
## members of each squad. The protected child Noe is field support in the
## SOUTH lane and is never enrolled in combat before chapter 49.
## No mutation of rpg.party, actor recruitment, experience or save flags here.
const PartyCanonGuard = preload("res://scripts/systems/PartyCanonGuard.gd")
const FIGHTERS: Dictionary = {
    "EAST_GATE_LEISO": ["cast_lei_suo", "char_tidecaller"],
    "SOUTH_GATE_SHUOXIAN": ["char_seeker"],
    "WEST_GATE_TIFA": ["cast_ti_fa"]
}
const ENCOUNTER_LABELS: Dictionary = {
    "EAST_GATE_LEISO": "东门 · 拦路突击队",
    "SOUTH_GATE_SHUOXIAN": "南门 · 追击游骑",
    "WEST_GATE_TIFA": "西门 · 破城机兵"
}

static func resolve(squad_id: String, chapter: int,
        actors: Array, flags: Dictionary) -> Dictionary:
    if chapter != 47 or not FIGHTERS.has(squad_id):
        return {"ok":false, "reason":"invalid_rescue_context"}
    var combat_ids: Array[String] = []
    for required_id in FIGHTERS[squad_id]:
        var matching_id: String = ""
        var active_hp: int = 0
        for actor_value in actors:
            if not (actor_value is Dictionary):
                continue
            var actor: Dictionary = actor_value
            var actual: String = str(actor.get("id",""))
            if PartyCanonGuard.canonical_id(actual) == str(required_id):
                matching_id = actual
                active_hp = int(actor.get("hp",0))
                break
        if matching_id.is_empty():
            return {"ok":false,"reason":"required_character_not_recruited:"+str(required_id)}
        if not PartyCanonGuard.can_fight(matching_id,chapter,flags):
            return {"ok":false,"reason":"character_not_canonically_playable:"+matching_id}
        combat_ids.append(matching_id)
    var conscious: bool = false
    for member in actors:
        if member is Dictionary and str(member.get("id","")) in combat_ids and int(member.get("hp",0)) > 0:
            conscious = true
    if not conscious:
        return {"ok":false,"reason":"rescue_squad_all_incapacitated"}
    return {"ok":true,"ids":combat_ids, "encounter_title":str(ENCOUNTER_LABELS[squad_id]),
        "protected_noncombat_support":["cast_nuo_yi"] if squad_id == "SOUTH_GATE_SHUOXIAN" else []}
