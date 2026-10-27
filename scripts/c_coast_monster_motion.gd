extends RefCounted
## Visual-only action sheets. All-or-nothing fallback avoids identity popping.
const ArtOverrides = preload("res://scripts/c_art_overrides.gd")
const FRAME_SIZE: int = 128
const CONFIG: Dictionary = {
    "salt_slime": {
        "idle": ["res://assets/art/monsters/coast/salt_slime/c21_idle_4f.svg", 4],
        "attack": ["res://assets/art/monsters/coast/salt_slime/c21_attack_6f.svg", 6],
        "hit": ["res://assets/art/monsters/coast/salt_slime/c21_hit_4f.svg", 4],
        "defeat": ["res://assets/art/monsters/coast/salt_slime/c21_defeat_6f.svg", 6]
    }
}
static func sheets(art_id: String) -> Dictionary:
    if not CONFIG.has(art_id):
        return {}
    var result: Dictionary = {}
    var item: Dictionary = CONFIG[art_id]
    for state in ["idle", "attack", "hit", "defeat"]:
        var spec: Array = item[state]
        var path: String = str(spec[0])
        if not ResourceLoader.exists(path):
            return {}
        var texture: Texture2D = ArtOverrides.texture(path)
        if texture == null or texture.get_size() != Vector2(FRAME_SIZE * int(spec[1]), FRAME_SIZE):
            return {}
        result[state] = texture
    return result
static func frame_count(state: String) -> int:
    match state:
        "attack", "defeat": return 6
        "idle", "hit": return 4
        _: return 0
