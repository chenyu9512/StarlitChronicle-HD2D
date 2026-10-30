extends RefCounted
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
const Generated = preload("res://scripts/global_generated_art_v3.gd")
const CAct01GlobalArt = preload("res://scripts/c_act01_global_art_v14.gd")
const CRegionalMonsters = preload("res://scripts/c_art_regional_monsters_v15.gd")
## B02 static illustrations / B03 static boss art. Never treat portraits as animation sheets.
const B02: String = "res://assets/art/b02/MANIFEST.json"
const B03: String = "res://assets/art/b03/boss_final_render/manifest.json"
const B03_DIR: String = "res://assets/art/b03/boss_final_render/"
static var loaded: bool = false
static var dialogues: Dictionary = {}
static var npc_bodies: Dictionary = {}
static var npc_portraits: Dictionary = {}
static var heads: Dictionary = {}
static var bosses: Dictionary = {}

static func _load_registry() -> void:
    if loaded:
        return
    loaded = true
    if FileAccess.file_exists(B02):
        var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(B02))
        if doc is Dictionary:
            for record in doc.get("records", []):
                if not record is Dictionary:
                    continue
                var id: String = str(record.get("id", ""))
                var group: String = "main" if str(record.get("group", "")) == "main" else "npc"
                var base: String = "res://assets/art/b02/characters/%s/%s/" % [group, id]
                var dialogue: String = base + "dialogue_192x240.png"
                var head: String = base + "head_160x160.png"
                var body: String = base + "fullbody_rgba.png"
                if CArtOverrides.exists(dialogue):
                    dialogues[str(record.get("name", ""))] = dialogue
                    if group == "npc":
                        npc_portraits[id] = dialogue
                if CArtOverrides.exists(head):
                    heads[id] = head
                if group == "npc" and CArtOverrides.exists(body):
                    npc_bodies[id] = body
    if FileAccess.file_exists(B03):
        var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(B03))
        if doc is Dictionary:
            for item in doc.get("assets", []):
                if not item is Dictionary:
                    continue
                var file_names: Dictionary = item.get("files", {})
                var path: String = B03_DIR + str(file_names.get("battle", ""))
                if CArtOverrides.exists(path):
                    bosses[str(item.get("boss_id", ""))] = path

static func dialogue_portrait(speaker: String) -> String:
    _load_registry()
    if dialogues.has(speaker):
        return str(dialogues[speaker])
    for name in dialogues.keys():
        if not str(name).is_empty() and speaker.contains(str(name)):
            return str(dialogues[name])
    if speaker.contains("主角"):
        return str(dialogues.get("黎昂", ""))
    return ""

static func npc_dialogue(npc_id: String) -> String:
    _load_registry()
    return str(npc_portraits.get(npc_id, ""))

static func npc_fullbody(npc_id: String) -> String:
    _load_registry()
    return str(npc_bodies.get(npc_id, ""))

static func party_head(character_id: String) -> String:
    _load_registry()
    return str(heads.get(character_id, ""))

static func boss_image(boss_id: String) -> String:
    var generated: String = Generated.boss_path(boss_id)
    if not generated.is_empty():
        return generated
    _load_registry()
    var legacy: String = str(bosses.get(boss_id, ""))
    # Preserve an original B03 portrait if its real authored image still
    # exists, but do not mistake a migrated wall tile for that portrait.
    if not legacy.is_empty() and ResourceLoader.exists(legacy):
        return legacy
    # Main2 removed the B03 images. V14 provides five separately bound
    # chapter candidates; never collapse them to the same unrelated tile.
    var current: String = CAct01GlobalArt.boss_candidate(boss_id)
    if not current.is_empty() and CArtOverrides.exists(current):
        return current
    return ""

static func battle_image(enemy: Dictionary, is_boss: bool, chapter: int) -> String:
    _load_registry()
    if is_boss:
        var boss_id: String = str(enemy.get("boss_id", "boss.ch%03d" % chapter))
        var boss_path: String = boss_image(boss_id)
        if boss_path.is_empty():
            boss_path = boss_image("boss.ch%03d" % chapter)
        if not boss_path.is_empty():
            return boss_path
        # Static boss assets are curated candidates only. Keep identity-specific
        # B03/phase motion; do not replace it with an unrelated monster portrait.
    # Prefer a physically imported First Act monster portrait. Normal
    # encounters carry canonical monster_id. Party previews, multi-foe tests
    # and spawned encounters may carry only the legacy species "art" field:
    # both must resolve to exactly the same reviewed imported species.
    # Keep this order equal to EncounterRegistry.COAST_ART, not the old
    # MONSTER_ART battle-placement array (which has a different ordering).
    if not is_boss and not str(enemy.get("monster_id","")).is_empty():
        var generated_enemy: String = Generated.path("monsters", str(enemy.get("monster_id","")))
        if not generated_enemy.is_empty():
            return generated_enemy
    if chapter >= 1 and chapter <= 6 and not is_boss:
        var canonical_id: String = str(enemy.get("monster_id", ""))
        if canonical_id.is_empty():
            const COAST_SPECIES: Array[String] = [
                "salt_slime", "fog_crab", "sand_lizard", "tide_ghost",
                "white_seabird", "shell_hermit", "salt_wolf", "star_ray",
                "tide_guardian"
            ]
            var species: String = str(enemy.get("art", ""))
            var index: int = COAST_SPECIES.find(species)
            if index >= 0:
                canonical_id = "mon_coast_%02d" % (index + 1)
        var generated_coast: String = Generated.path("monsters", canonical_id)
        if not generated_coast.is_empty():
            return generated_coast
        var imported: String = CAct01GlobalArt.battle_path(canonical_id)
        if not imported.is_empty():
            return imported
    # Extra species-matched frontview art for the rest of the world (V15).
    # Only normal monsters; never overwrite story-boss identity/motion.
    if not is_boss:
        var regional: String = CRegionalMonsters.battle_path(str(enemy.get("monster_id", "")))
        if not regional.is_empty():
            return regional
    var monster: String = str(enemy.get("art", ""))
    if not monster.is_empty():
        var path: String = "res://assets/art/monsters/coast/%s/battle.png" % monster
        if CArtOverrides.exists(path):
            return path
    return "res://assets/enemies/boss.png"
