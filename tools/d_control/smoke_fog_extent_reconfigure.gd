extends SceneTree
## D-line regression: small/default fog prepared by menu before a 40-map world
## announces its actual size. Must not cause PackedByteArray out-of-range.
const Fog = preload("res://scripts/world_fog_v3.gd")
const State = preload("res://scripts/first_act_state.gd")

var errors: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")

func assert_true(value: bool, label: String) -> void:
    if not value:
        errors.append(label)

func _run() -> void:
    var state = State.new()
    var fog = Fog.new()
    fog.bind(state)
    var id: String = "d.test.fog.extent"
    # Some UI paths consult fog before World.build announces live dimensions.
    assert_true(not fog.revealed(id,0,0), "Default fog must begin hidden")
    assert_true(fog.reveal(id,Vector2i(35,20),2), "Default cells were not revealed")
    assert_true(fog.revealed(id,35,20), "Default reveal did not persist")
    fog.configure(id,Vector2i(100,64))
    assert_true(fog.revealed(id,35,20), "Resizing lost existing known cell")
    assert_true(not fog.revealed(id,99,63), "Expanded fog should stay concealed")
    assert_true(fog.reveal(id,Vector2i(99,63),1), "Expanded edge could not be revealed")
    assert_true(fog.revealed(id,99,63), "Expanded map edge did not stay visible")
    assert_true(not fog.revealed(id,100,63) and not fog.revealed(id,99,64),
        "Out-of-range map coordinates returned visible")
    assert_true(not fog.revealed(id,-1,0), "Negative coordinate accepted")
    var persisted: String = str(state.rpg.get("world",{}).get("fog",{}).get(id,""))
    assert_true(not persisted.is_empty(), "Resized fog not serialized")
    var restored = Fog.new()
    restored.bind(state)
    restored.configure(id,Vector2i(100,64))
    assert_true(restored.revealed(id,35,20) and restored.revealed(id,99,63),
        "Expanded fog lost bit positions after save roundtrip")
    # Changing stride again must not mistake byte offsets for tile indices.
    restored.configure(id,Vector2i(112,64))
    assert_true(restored.revealed(id,99,63), "Second dimension change lost edge")
    assert_true(not restored.revealed(id,111,63), "Fresh second expansion revealed cells")
    # Corrupt legacy payload length must fail closed rather than read outside.
    var bad: PackedByteArray = PackedByteArray([1,2,3])
    restored.decoded[id] = bad
    assert_true(not restored.revealed(id,111,63), "Damaged fog read outside stored bits")
    if errors.is_empty():
        print("PASS: fog default-to-live extent migration, save/reload, edge reveal, damaged cache")
        quit(0)
        return
    for reason in errors:
        push_error(reason)
    quit(1)
