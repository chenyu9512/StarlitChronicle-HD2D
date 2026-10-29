extends RefCounted
## Canonical 288 content-ID art routing. Legacy v6 allocation is historical.
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")

static func icon_path(content_id: String) -> String:
    return RuntimeArt.content_icon_source(content_id)

static func texture_for(content_id: String) -> Texture2D:
    return RuntimeArt.content_icon_texture(content_id)

static func allocated_count() -> int:
    return RuntimeArt.content_icon_count()
