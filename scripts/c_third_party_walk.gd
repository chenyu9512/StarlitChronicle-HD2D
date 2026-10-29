extends RefCounted
## Runtime-only adaptation of the third-party Foozle 48px directional strips.
## No claim that these stock character identities are final story portraits.
const Art = preload("res://scripts/c_art_overrides.gd")
const PREFIX: String = "res://assets/art/external/cc0_named_v1/characters/"
const DIRECTIONS: Array[String] = ["down", "left", "up", "right"]
const FAMILIES: Array[String] = ["foozle_warrior", "foozle_sorceress", "foozle_necromancer"]
const FRAME: int = 48

static func _strip(family: String, direction: String, action: String) -> Texture2D:
    var short_name: String = family.trim_prefix("foozle_")
    var filename: String = "char_%s_%s_%s_%s.png" % [family, short_name, direction, action]
    var path: String = PREFIX + family + "/" + direction + "/" + filename
    var texture: Texture2D = Art.texture(path)
    if texture == null or texture.get_height() != FRAME or texture.get_width() < FRAME:
        return null
    if texture.get_width() % FRAME != 0 or texture.get_width() / FRAME > 32:
        return null
    return texture

## Every direction must have a real movement strip. Do not substitute combat
## attack files, stretch a one-frame pose or synthesize fake directional frames.
static func resolve(legacy_walk_slot: String) -> Dictionary:
    if not legacy_walk_slot.ends_with("/walk_4dir_3frames.png"):
        return {}
    if Art.has_override(legacy_walk_slot):
        return {}
    # An explicit user-selected DLC pack owns the visual choice.
    if Art.active_pack() not in ["original", "uploaded_later_v1"]:
        return {}
    var source: String = Art.third_party_source(legacy_walk_slot)
    if not source.begins_with(PREFIX):
        return {}
    var family: String = source.trim_prefix(PREFIX).get_slice("/", 0)
    if family not in FAMILIES:
        return {}
    var strips: Dictionary = {}
    for direction in DIRECTIONS:
        var walking: Texture2D = _strip(family, direction, "walk")
        if walking == null:
            walking = _strip(family, direction, "run")
        if walking == null:
            return {}
        var standing: Texture2D = _strip(family, direction, "idle")
        if standing == null:
            # The upstream necromancer left idle file is named leftt_idle.
            standing = _strip(family, direction, "leftt_idle") if direction == "left" else null
        if standing == null:
            standing = walking
        strips[direction] = {"walk": walking, "idle": standing}
    return strips
