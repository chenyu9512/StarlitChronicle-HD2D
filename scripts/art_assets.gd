extends RefCounted
const CArtOverrides = preload("res://scripts/c_art_overrides.gd")
const CAct01GlobalArt = preload("res://scripts/c_act01_global_art_v14.gd")
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
    _load_registry()
    return str(bosses.get(boss_id, ""))

static func battle_image(enemy: Dictionary, is_boss: bool, chapter: int) -> String:
    _load_registry()
    if is_boss:
        var boss_id: String = str(enemy.get("boss_id", "boss.ch%03d" % chapter))
        var boss_path: String = str(bosses.get(boss_id, ""))
        if boss_path.is_empty():
            boss_path = str(bosses.get("boss.ch%03d" % chapter, ""))
        if not boss_path.is_empty():
            return boss_path
        # Static boss assets are curated candidates only. Keep identity-specific
        # B03/phase motion; do not replace it with an unrelated monster portrait.
    # Prefer a physically imported first-act monster portrait over the generic
    # placeholder. Existing coastal action sheets still own combat movement.
    if chapter >= 1 and chapter <= 6 and not is_boss:
        var imported: String = CAct01GlobalArt.battle_path(str(enemy.get("monster_id", "")))
        if not imported.is_empty():
            return imported
    var monster: String = str(enemy.get("art", ""))
    if not monster.is_empty():
        var path: String = "res://assets/art/monsters/coast/%s/battle.png" % monster
        if CArtOverrides.exists(path):
            return path
    return "res://assets/enemies/boss.png"
