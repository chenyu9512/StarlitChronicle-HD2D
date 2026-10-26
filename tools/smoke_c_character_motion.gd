extends SceneTree
## C-line isolated character visual contract; run during consolidated Godot QA.
const Motion = preload("res://scripts/c_character_motion.gd")
const Actor = preload("res://scripts/first_act_actor.gd")
const NPC = preload("res://scripts/world_npc_visual.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _run() -> void:
    var states := Motion.new()
    var directions: Array[Vector2] = [
        Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1),
        Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1)
    ]
    for idx in range(directions.size()):
        states.face_vector(directions[idx])
        expect(states.heading8 == idx, "Wrong 8-way heading: " + str(idx))
        expect(states.atlas_row() in [0, 1, 2, 3], "Old atlas row out of bounds")
    states.advance(0.1, Vector2.RIGHT)
    expect(states.state in ["start", "walk"], "Start state missing")
    states.advance(0.1, Vector2.ZERO)
    expect(states.state in ["stop", "turn", "idle"], "Stop state missing")
    states.start_talking(Vector2.UP)
    expect(states.state == "talk" and states.heading8 == 4, "Talk face missing")
    for character_id in ["leon", "lanyin", "shuoxian", "chengzhou"]:
        var source: String = "res://assets/art/characters/%s/walk_4dir_3frames.png" % character_id
        var sample := Actor.new()
        root.add_child(sample)
        sample.setup(source)
        expect(sample.sprite.texture != null, character_id + ": missing imported atlas")
        if sample.sprite.texture != null:
            expect(sample.sprite.texture.get_size() == Vector2(96, 192), character_id + ": wrong atlas dimensions")
            if str(sample.sprite.get_meta("c21_walk_source", "")) != "":
                var frame_image: Image = sample.sprite.texture.get_image()
                expect(frame_image != null, character_id + ": SVG image unreadable")
                if frame_image != null and frame_image.get_size() == Vector2i(96, 192):
                    var front: PackedByteArray = frame_image.get_region(Rect2i(32, 0, 32, 48)).get_data()
                    for direction in range(1, 4):
                        var facing_image: PackedByteArray = frame_image.get_region(Rect2i(32, direction * 48, 32, 48)).get_data()
                        expect(front != facing_image, character_id + ": identical directional art")
                    var step0: PackedByteArray = frame_image.get_region(Rect2i(0, 0, 32, 48)).get_data()
                    var step2: PackedByteArray = frame_image.get_region(Rect2i(64, 0, 32, 48)).get_data()
                    expect(step0 != step2, character_id + ": missing real walking frame change")
        sample.queue_free()
    var actor := Actor.new()
    root.add_child(actor)
    actor.setup("res://assets/art/characters/leon/walk_4dir_3frames.png")
    actor.set_motion(0.12, Vector2(1, -1))
    expect(actor.motion.heading8 == 5, "Actor diagonal heading missing")
    expect(actor.sprite.frame_coords.y in [0, 1, 2, 3], "Invalid 4-direction fallback")
    actor.begin_conversation(actor.global_position + Vector2.LEFT * 25.0)
    expect(actor.motion.heading8 == 2, "Actor conversation facing missing")
    var npc := NPC.new()
    root.add_child(npc)
    npc.setup({"id": "npc_coast_01", "role": "shop", "name": "Test villager"})
    npc.face_player(npc.global_position + Vector2.RIGHT * 18.0)
    expect(npc.talking and npc.motion.heading8 == 6, "NPC facing missing")
    npc.end_conversation()
    npc.perform_life_action("sort_goods")
    expect(npc.life_action == "sort_goods", "NPC shop activity missing")
    npc.set_reduced_motion(true)
    expect(npc.reduced_motion, "Low motion setting missing")
    actor.queue_free()
    npc.queue_free()
    if failures.is_empty():
        print("PASS C character: eight logical directions, 4x3 visual fallback, interactions, NPC life states")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)
