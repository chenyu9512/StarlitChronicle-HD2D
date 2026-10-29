extends RefCounted
## Precisely matched third-party coastal scenery promoted from source_packs.
## Each path is a physically imported runtime image, not a .gdignore original.
## No gameplay collision, map coordinate, save flag or quest data is changed.
const Art = preload("res://scripts/c_art_overrides.gd")
const DOCK_BOAT: String = "res://assets/art/runtime/act01_matched_v16/dock_boat.png"

static func texture_for_prop(kind: String) -> Texture2D:
    # A real Golden Horizon rowboat, replacing the old false wooden-bridge art.
    # Do not substitute this for world bridges, cave props or indoor furniture.
    if kind != "dock_boat":
        return null
    return Art.texture(DOCK_BOAT)
