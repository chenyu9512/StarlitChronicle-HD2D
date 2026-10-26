extends RefCounted
## Compact persistent fog of war: 72x48 = 432 bytes per visited map.
## Per-cell check runs only against cached bytes, never decodes a base64 string in _draw.
const W: int = 72
const H: int = 48
const LEN: int = 432
var state
var decoded: Dictionary = {}
var last_reveal: Dictionary = {}
var extents: Dictionary = {}

func configure(id: String, extent: Vector2i) -> void:
    if id.is_empty():
        return
    var next_extent: Vector2i = Vector2i(maxi(W,extent.x),maxi(H,extent.y))
    var old_extent: Vector2i = _extent(id)
    if decoded.has(id) and old_extent != next_extent:
        # The map view may read fog before the physical map dimensions arrive.
        # Remap existing explored cells to the new row stride, not only resize.
        var previous: PackedByteArray = decoded[id]
        var resized := PackedByteArray()
        resized.resize(int(ceil(float(next_extent.x*next_extent.y)/8.0)))
        resized.fill(0)
        for y in range(mini(old_extent.y,next_extent.y)):
            for x in range(mini(old_extent.x,next_extent.x)):
                var from_bit: int = y*old_extent.x+x
                var to_bit: int = y*next_extent.x+x
                var source_index: int = int(from_bit/8)
                if source_index < previous.size() and (int(previous[source_index]) & (1<<(from_bit%8))) != 0:
                    var dest_index: int = int(to_bit/8)
                    resized[dest_index] = int(resized[dest_index]) | (1<<(to_bit%8))
        decoded[id] = resized
        if state != null:
            var world: Dictionary = state.rpg.get("world",{})
            var layers: Dictionary = world.get("fog",{})
            layers[id] = Marshalls.raw_to_base64(resized)
            world["fog"] = layers
            state.rpg["world"] = world
    extents[id] = next_extent
    _bytes(id)

func _extent(id: String) -> Vector2i:
    return extents.get(id,Vector2i(W,H))

func bind(progress) -> void:
    state = progress
    decoded.clear()
    last_reveal.clear()
    extents.clear()
    if state == null:
        return
    if not state.rpg.get("world") is Dictionary:
        state.rpg["world"] = {}
    var world: Dictionary = state.rpg["world"]
    if not world.get("fog") is Dictionary:
        world["fog"] = {}

func _bytes(id: String) -> PackedByteArray:
    if decoded.has(id):
        var existing: PackedByteArray = decoded[id]
        var old_extent: Vector2i = _extent(id)
        var required: int = int(ceil(float(old_extent.x*old_extent.y)/8.0))
        if existing.size() == required:
            return existing
        # Repair stale/truncated cached arrays rather than indexing beyond end.
        decoded.erase(id)
    var values := PackedByteArray()
    if state != null:
        var layers: Dictionary = state.rpg.get("world",{}).get("fog",{})
        var stored: String = str(layers.get(id,""))
        if not stored.is_empty():
            values = Marshalls.base64_to_raw(stored)
    var extent: Vector2i = _extent(id)
    var needed: int = int(ceil(float(extent.x*extent.y)/8.0))
    if values.size()!=needed:
        var migrated := PackedByteArray()
        migrated.resize(needed)
        migrated.fill(0)
        if values.size()==LEN and needed!=LEN:
            # Convert previous 72-column maps without losing explored cells.
            for y in range(H):
                for x in range(W):
                    var old_bit: int = y*W+x
                    if (int(values[old_bit/8]) & (1<<(old_bit%8)))!=0:
                        var new_bit: int = y*extent.x+x
                        migrated[new_bit/8] = int(migrated[new_bit/8]) | (1<<(new_bit%8))
        values = migrated
        if state != null:
            state.rpg["world"]["fog"][id] = Marshalls.raw_to_base64(values)
    decoded[id] = values
    return values

func revealed(id: String, x: int, y: int) -> bool:
    var extent: Vector2i = _extent(id)
    if id.is_empty() or x < 0 or y < 0 or x >= extent.x or y >= extent.y:
        return false
    var values: PackedByteArray = _bytes(id)
    var position: int = y*extent.x+x
    var index: int = int(position/8)
    if index < 0 or index >= values.size():
        return false
    return (int(values[index]) & (1<<(position%8))) != 0

func reveal(id: String, center: Vector2i, radius: int = 4) -> bool:
    if state == null or id.is_empty():
        return false
    var previous: Vector2i = last_reveal.get(id,Vector2i(-100,-100))
    if previous == center:
        return false
    last_reveal[id] = center
    var extent: Vector2i = _extent(id)
    var bytes: PackedByteArray = _bytes(id)
    var dirty: bool = false
    for dy in range(-radius,radius+1):
        for dx in range(-radius,radius+1):
            if dx*dx+dy*dy > radius*radius:
                continue
            var x: int = center.x+dx
            var y: int = center.y+dy
            if x<0 or y<0 or x>=extent.x or y>=extent.y:
                continue
            var offset: int = y*extent.x+x
            var chunk: int = int(offset/8)
            if chunk < 0 or chunk >= bytes.size():
                continue
            var mask: int = 1<<(offset%8)
            if (int(bytes[chunk]) & mask)==0:
                bytes[chunk] = int(bytes[chunk]) | mask
                dirty = true
    if dirty:
        decoded[id] = bytes
        var world: Dictionary = state.rpg["world"]
        var layers: Dictionary = world["fog"]
        layers[id] = Marshalls.raw_to_base64(bytes)
    return dirty

func percent(id: String) -> int:
    if id.is_empty():
        return 0
    var bits: int = 0
    var values: PackedByteArray = _bytes(id)
    for byte_value in values:
        var item: int = int(byte_value)
        while item!=0:
            item &= item-1
            bits += 1
    var extent: Vector2i = _extent(id)
    return roundi(float(bits)*100.0/float(extent.x*extent.y))
