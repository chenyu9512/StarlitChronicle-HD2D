extends SceneTree
## Engine-side proof that the B02/B03 runtime resources resolve without replacing animation sheets.
const ArtAssets = preload("res://scripts/art_assets.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func expect(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)

func _run() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/b02/MANIFEST.json"))
    expect(raw is Dictionary, "B02 manifest must parse")
    var count_main: int = 0
    var count_npc: int = 0
    if raw is Dictionary:
        for record in raw.get("records", []):
            if not record is Dictionary:
                continue
            var character_id: String = str(record.get("id", ""))
            var person_name: String = str(record.get("name", ""))
            var group: String = "main" if str(record.get("group", "")) == "main" else "npc"
            var root_path: String = "res://assets/art/b02/characters/%s/%s/" % [group,character_id]
            for filename in ["fullbody_rgba.png","portrait_320x400.png","dialogue_192x240.png","head_160x160.png"]:
                expect(ResourceLoader.exists(root_path+filename), "Missing B02 asset: "+root_path+filename)
            expect(ArtAssets.dialogue_portrait(person_name)==root_path+"dialogue_192x240.png","Dialogue must use B02 portrait: "+character_id)
            expect(ArtAssets.party_head(character_id)==root_path+"head_160x160.png","Missing B02 headshot: "+character_id)
            if group == "main":
                count_main += 1
            else:
                count_npc += 1
                expect(ArtAssets.npc_fullbody(character_id)==root_path+"fullbody_rgba.png","Missing NPC still art: "+character_id)
                expect(ArtAssets.npc_dialogue(character_id)==root_path+"dialogue_192x240.png","Missing NPC dialogue art: "+character_id)
    expect(count_main==12 and count_npc==35,"Expected 12 leads and 35 NPC art sets")
    expect(ArtAssets.dialogue_portrait("旁白").is_empty(),"Narrator must not impersonate a character")
    expect(ArtAssets.npc_fullbody("npc_coast_01").is_empty(),"Unfinished coast art must use fallback")
    var b03: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/b03/boss_final_render/manifest.json"))
    expect(b03 is Dictionary,"B03 manifest must parse")
    var boss_count: int = 0
    if b03 is Dictionary:
        for boss in b03.get("assets", []):
            if not boss is Dictionary:
                continue
            var boss_id: String = str(boss.get("boss_id", ""))
            var chapter: int = int(str(boss.get("chapter", "ch000")).trim_prefix("ch"))
            var image_path: String = ArtAssets.boss_image(boss_id)
            expect(ResourceLoader.exists(image_path),"Missing B03 boss: "+boss_id)
            expect(ArtAssets.battle_image({"boss_id":boss_id,"art":"tide_guardian"},true,chapter)==image_path,"Boss illustration not bound: "+boss_id)
            var image: Texture2D = load(image_path)
            expect(image != null and image.get_size()==Vector2(768,768),"Boss render must be 768×768: "+boss_id)
            boss_count += 1
    expect(boss_count==5,"B03 must contain five authored static boss portraits")
    expect(ArtAssets.battle_image({"art":"salt_slime"},false,3).ends_with("salt_slime/battle.png"),"Regular monster must retain runtime art")
    expect(ArtAssets.battle_image({},false,10)=="res://assets/enemies/boss.png","Missing monsters need a safe fallback")
    if failures.is_empty():
        print("PASS: 12 main characters, 35 NPC illustrations, 5 B03 bosses and all fallback paths")
        quit(0)
    else:
        for reason in failures:
            push_error(reason)
        quit(1)
