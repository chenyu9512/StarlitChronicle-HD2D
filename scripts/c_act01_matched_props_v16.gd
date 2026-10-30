extends RefCounted
## The old manually uploaded V16 rowboat was purged. Use only the current
## canonical exact-role generated dock boat; never substitute wooden bridge.
## Placement, collision, quests, and V3 save data remain unchanged.
const Art = preload("res://scripts/c_art_overrides.gd")
const RuntimeArt = preload("res://scripts/c_art_runtime.gd")
const DOCK_SLOT: String = "prop.harbor.dock_boat"

static func texture_for_prop(kind: String) -> Texture2D:
    if kind != "dock_boat":
        return null
    var source: String = RuntimeArt.slot_source(DOCK_SLOT)
    if source != "res://assets/art/runtime/generated_gaps_v10/prop__harbor__dock_boat.png":
        return null
    return Art.texture(source)
