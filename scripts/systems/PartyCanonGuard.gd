extends RefCounted
## V2.1 canon roster gate. Pure decisions: callers own V3 save transactions.
const LOCKED: String = "LOCKED"
const ACQUAINTED: String = "ACQUAINTED"
const GUEST_SUPPORT: String = "GUEST_SUPPORT"
const ACTIVE_PARTY: String = "ACTIVE_PARTY"
const PROTECTED_CHILD: String = "PROTECTED_CHILD"

static func canonical_id(id: String) -> String:
    var aliases: Dictionary = {
        "char_vanguard":"cast_lei_suo", "char_seeker":"char_seeker",
        "cast_shuo_xian":"char_seeker", "char_smith":"cast_ti_fa",
        "char_navigator":"cast_yi_ze", "char_mirrorweaver":"cast_xuan_li",
        "char_alchemist":"cast_nuo_yi", "char_cantor":"cast_wei_sha"
    }
    return str(aliases.get(id, id))

static func roster_state(id: String, chapter: int, flags: Dictionary) -> String:
    var actor: String = canonical_id(id)
    match actor:
        "char_wayfarer", "char_tidecaller", "cast_player", "cast_lan_yin":
            return ACTIVE_PARTY
        "char_seeker":
            return ACTIVE_PARTY if chapter >= 4 and bool(flags.get("story.ch004.done",false)) else LOCKED
        "cast_lei_suo":
            if chapter < 7:
                return LOCKED
            if chapter == 7:
                return ACQUAINTED
            if chapter == 8:
                return GUEST_SUPPORT
            return ACTIVE_PARTY if bool(flags.get("story.ch009.done",false)) else GUEST_SUPPORT
        "cast_ti_fa":
            return ACTIVE_PARTY if chapter >= 14 else LOCKED
        "cast_yi_ze":
            if chapter < 27:
                return LOCKED # ch022 anonymous musician has an independent NPC identity
            if chapter == 27:
                return GUEST_SUPPORT
            return ACTIVE_PARTY if bool(flags.get("story.ch028.done",false)) else GUEST_SUPPORT
        "cast_xuan_li":
            if chapter < 32:
                return LOCKED
            return ACTIVE_PARTY if bool(flags.get("story.ch034.done",false)) else ACQUAINTED
        "cast_nuo_yi":
            if chapter < 39:
                return LOCKED
            if chapter < 49:
                return PROTECTED_CHILD
            return ACTIVE_PARTY if bool(flags.get("story.ch048.done",false)) else LOCKED
        "cast_wei_sha":
            if chapter < 58:
                return LOCKED # ch023/024 records and ch043 message are never actors
            return ACTIVE_PARTY if bool(flags.get("story.ch058.done",false)) else ACQUAINTED
    # Unknown/cameo NPCs never become combat members through old save injection.
    return LOCKED

static func can_join(id: String, chapter: int, flags: Dictionary) -> bool:
    return roster_state(id,chapter,flags) == ACTIVE_PARTY

static func historical_actor(chapter: int, flags: Dictionary = {}) -> String:
    if chapter == 21 and bool(flags.get("ch021.campfire_returned",false)):
        return "" # Present-day choice must not retain the ten-year-ago sandbox.
    match chapter:
        19: return "cast_lei_suo"
        20: return "char_seeker"
        21: return "char_tidecaller"
    return ""

static func can_fight(id: String, chapter: int, flags: Dictionary) -> bool:
    if not can_join(id,chapter,flags):
        return false
    var historical: String = historical_actor(chapter,flags)
    return historical.is_empty() or canonical_id(id) == historical

static func can_lead(id: String, chapter: int, flags: Dictionary) -> bool:
    var actor: String = canonical_id(id)
    if actor != "cast_nuo_yi":
        return can_join(id,chapter,flags)
    # Chapter 49 is the actual adulthood/POV handover; chapter 54 closes
    # leadership cooperation, not the first moment Noe can control the party.
    # Require BOTH the completed twelve-year transition and a real ch049
    # opening flag. Chapter-47 child Noe remains permanently non-combat.
    return chapter >= 49 and bool(flags.get("story.ch048.done",false))         and bool(flags.get("ch049.started",false)) and can_join(id,chapter,flags)
