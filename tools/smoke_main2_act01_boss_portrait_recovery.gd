extends SceneTree
## Main2 runtime fallback: authentic per-chapter imported candidate art,
## never an unrelated third-party tile or missing legacy B03. This does not
## assert commercial illustration/animation acceptance.
const Art = preload("res://scripts/art_assets.gd")
const Av = preload("res://scripts/av_asset_registry.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var seen: Dictionary = {}
    for chapter in range(2,7):
        var boss_id: String = "boss.ch%03d" % chapter
        var file: String = Art.boss_image(boss_id)
        if file.is_empty() or not ResourceLoader.exists(file):
            failures.append(boss_id+" missing imported boss texture")
            continue
        if seen.has(file):
            failures.append(boss_id+" duplicates another boss art source")
        seen[file] = true
        var texture: Texture2D = load(file) as Texture2D
        if texture == null or texture.get_width()<=0 or texture.get_height()<=0:
            failures.append(boss_id+" image cannot be rendered")
        if Art.battle_image({"boss_id":boss_id},true,chapter) != file:
            failures.append(boss_id+" main battle uses a different fallback")
        if Av.boss_static_art(boss_id).is_empty():
            failures.append(boss_id+" AV system cannot resolve the portrait")
    if failures.is_empty():
        print("PASS Main2: five distinct loaded first-act boss portraits in Battle and AV (visual QA pending)")
        quit(0)
        return
    for err in failures:
        push_error(err)
    quit(1)
