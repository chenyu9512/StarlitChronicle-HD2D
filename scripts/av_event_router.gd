extends Node
## Standalone audiovisual bridge for the A/B/C integration stage.
## Dispatch only. Never mutates combat, story progression, inventories or save states.
signal audio_requested(asset_id: String, context: Dictionary)
signal visual_requested(asset_id: String, context: Dictionary)
const Registry = preload("res://scripts/av_asset_registry.gd")
const DYNAMIC_FIELDS: Dictionary = {"id":"skill_id", "mood":"mood", "region":"region_id", "weather":"weather"}

func dispatch(event_id: String, context: Dictionary = {}) -> bool:
    var source: Dictionary = Registry._read().get("event_bridge", {})
    for item in source.get("mappings", []):
        if not item is Dictionary or str(item.get("event", "")) != event_id:
            continue
        var audio_id: String = _expand(str(item.get("audio_id", "")), context)
        var visual_id: String = _expand(str(item.get("visual_id", "")), context)
        if not audio_id.is_empty():
            audio_requested.emit(audio_id, context.duplicate(true))
        if not visual_id.is_empty():
            visual_requested.emit(visual_id, context.duplicate(true))
        return true
    return false

func _expand(value: String, context: Dictionary) -> String:
    if value.is_empty():
        return ""
    var marker: int = value.find(".by_")
    if marker < 0:
        return value
    var field: String = value.substr(marker + 4)
    var payload_key: String = str(DYNAMIC_FIELDS.get(field, field))
    # The legacy registry uses "bgm.region.by_id" but world events carry region_id,
    # not skill_id. Keep that canonical ID stable for A/B/D producers.
    if field == "id" and value.begins_with("bgm.region."):
        payload_key = "region_id"
    var suffix: String = str(context.get(payload_key, ""))
    if suffix.is_empty() or "/" in suffix or "\\" in suffix or ".." in suffix:
        return ""
    return value.substr(0, marker) + "." + suffix
