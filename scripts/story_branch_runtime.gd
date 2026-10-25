extends RefCounted
## Phase 19-1: authored branch event state machine, save-compatible with first_act_v3.
## Does not grant quest rewards, fabricate missing A/B, or install map markers.
const ROOT: String = "res://story/"
const MANIFESTS: Array[String] = [
    "data/phase17_lost_pages_manifest.json",
    "data/phase17_life_manifest.json",
    "data/phase17_regional_manifest.json",
    "data/phase18_companion_manifest.json"
]
const CODAS: String = "data/phase18_companion_ending_codas.json"
const KINDS: Array[String] = ["followup", "community", "revisit"]
const LEAD_ACTOR: Dictionary = {
    "lanyin":"char_tidecaller", "shouxian":"char_seeker"
}
var events: Dictionary = {}
var quest_events: Dictionary = {}
var errors: Array[String] = []
var state

func _read(rel_path: String) -> Dictionary:
    var file_path: String = ROOT + rel_path
    if not FileAccess.file_exists(file_path):
        errors.append("missing " + file_path)
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
    if not (parsed is Dictionary):
        errors.append("invalid JSON " + file_path)
        return {}
    return parsed

func load_all() -> bool:
    events.clear()
    quest_events.clear()
    errors.clear()
    for manifest_name in MANIFESTS:
        var manifest: Dictionary = _read(manifest_name)
        var files: Array = manifest.get("source_files", manifest.get("branch_files", []))
        var authored: Dictionary = {}
        for file_name in files:
            var relative: String = str(file_name).trim_prefix("story/")
            for raw in _read(relative).get("quests", []):
                if raw is Dictionary:
                    authored[str(raw.get("id",""))] = raw
        for raw_entry in manifest.get("entries", []):
            if not (raw_entry is Dictionary):
                continue
            var entry: Dictionary = raw_entry
            var quest_id: String = str(entry.get("id", ""))
            var arc: Dictionary = authored.get(quest_id, {})
            if arc.is_empty():
                errors.append("no authored script: " + quest_id)
                continue
            var group: Array = []
            for branch in ["a", "b"]:
                var choice: Dictionary = entry.get("branches", {}).get(branch, {})
                var scripts: Array = arc.get("arms", {}).get(branch, [])
                var contracts: Array = choice.get("stages", [])
                if contracts.size() != 3 or scripts.size() != 3:
                    errors.append("missing scenes: " + quest_id + branch)
                    continue
                for index in range(3):
                    var contract: Dictionary = contracts[index]
                    var scene: Dictionary = scripts[index]
                    var event_id: String = str(contract.get("id", ""))
                    if event_id.is_empty() or events.has(event_id):
                        errors.append("duplicate branch event " + event_id)
                        continue
                    var expected: Array = contract.get("source_dialogue_ids",
                        contract.get("existing_dialogue_ids", []))
                    var lines: Array = scene.get("dialogue", [])
                    if lines.size() != 3:
                        errors.append("wrong line count " + event_id)
                        continue
                    var matches: bool = true
                    for line_index in range(3):
                        if str(lines[line_index].get("id","")) != str(expected[line_index]):
                            matches = false
                    if not matches:
                        errors.append("dialogue drift " + event_id)
                        continue
                    var flags: Dictionary = contract.get("required_flags",
                        contract.get("required_runtime_flags", {}))
                    var previous_value: Variant = contract.get("previous_optional_stage",
                        contract.get("must_follow", null))
                    var previous: String = "" if previous_value == null else str(previous_value)
                    var seen_key: String = str(contract.get("proposed_seen_flag",
                        contract.get("completion_marker_proposed", "")))
                    if not (flags is Dictionary) or seen_key.is_empty():
                        errors.append("invalid gate " + event_id)
                        continue
                    var record: Dictionary = {
                        "id":event_id, "quest_id":quest_id, "branch":branch,
                        "kind":str(contract.get("kind","")),
                        "title":str(scene.get("title","")),
                        "region":str(entry.get("region","")),
                        "lead_id":str(entry.get("lead_id","")),
                        "required_flags":flags,
                        "required_present_flags":contract.get("required_present_flags", []),
                        "companion_presence_required":bool(contract.get("companion_presence_required",false)),
                        "previous_id":previous,
                        "seen_flag":seen_key, "dialogue":lines,
                        "player_action":str(contract.get("player_action",
                            "、".join(contract.get("player_actions",[])))),
                        "is_coda":false
                    }
                    events[event_id] = record
                    group.append(event_id)
            quest_events[quest_id] = group
    var ending_file: Dictionary = _read(CODAS)
    for raw in ending_file.get("codas", []):
        if not (raw is Dictionary):
            continue
        var record: Dictionary = raw
        var event_id: String = str(record.get("id",""))
        if event_id.is_empty() or events.has(event_id):
            errors.append("duplicate coda " + event_id)
            continue
        if (record.get("dialogue", []) as Array).size() != 3:
            errors.append("bad coda dialogue " + event_id)
            continue
        events[event_id] = {
            "id":event_id, "quest_id":str(record.get("source_quest","")),
            "branch":str(record.get("branch","")),
            "kind":"ending_coda", "title":str(record.get("title","")),
            "region":"", "lead_id":str(record.get("lead_id","")),
            "required_flags":record.get("requires_flags",{}),
            "required_present_flags":[], "companion_presence_required":false,
            "previous_id":"", "seen_flag":str(record.get("proposed_seen_flag","")),
            "dialogue":record.get("dialogue",[]), "player_action":"",
            "is_coda":true
        }
    if events.size() != 768:
        errors.append("expected 768 branch/coda events, got %d" % events.size())
    return errors.is_empty()

func bind(progress) -> void:
    state = progress
    if not (state.rpg.get("branch_story") is Dictionary):
        state.rpg["branch_story"] = {}
    var storage: Dictionary = state.rpg["branch_story"]
    if not (storage.get("seen") is Dictionary):
        storage["seen"] = {}
    if not (storage.get("active") is Dictionary):
        storage["active"] = {}

func get_event(event_id: String) -> Dictionary:
    return events.get(event_id, {})

func _storage() -> Dictionary:
    return state.rpg.get("branch_story", {}) if state != null else {}

func is_seen(event_id: String) -> bool:
    if state == null or not events.has(event_id):
        return false
    var event: Dictionary = events[event_id]
    var done: Dictionary = _storage().get("seen", {})
    return bool(done.get(event_id,false)) or bool(state.flags.get(str(event["seen_flag"]),false))

func _party_has(lead_id: String) -> bool:
    if lead_id.is_empty():
        return true
    var overrides: Dictionary = state.rpg.get("story_companions_present",{})
    if bool(overrides.get(lead_id,false)):
        return true
    var party: Array = state.rpg.get("party",[])
    if lead_id in party or str(LEAD_ACTOR.get(lead_id,"")) in party:
        return true
    return false

func eligible(event_id: String) -> bool:
    if state == null or not events.has(event_id) or is_seen(event_id):
        return false
    var event: Dictionary = events[event_id]
    for key in (event.get("required_flags",{}) as Dictionary):
        if state.flags.get(str(key)) != event["required_flags"][key]:
            return false
    for key in event.get("required_present_flags",[]):
        if str(state.flags.get(str(key),"")).is_empty():
            return false
    var previous: String = str(event.get("previous_id",""))
    if not previous.is_empty() and not is_seen(previous):
        return false
    if bool(event.get("companion_presence_required",false)):
        if not _party_has(str(event.get("lead_id",""))):
            return false
    if bool(event.get("is_coda",false)) and not bool(state.rpg.get("ending_complete",false)):
        return false
    return true

func next_for_quest(quest_id: String) -> Dictionary:
    for event_id in quest_events.get(quest_id,[]):
        if eligible(str(event_id)):
            return events[event_id]
    return {}

func offered_count() -> int:
    var amount: int = 0
    for id in events:
        if eligible(str(id)):
            amount += 1
    return amount

func begin(event_id: String) -> bool:
    if state == null or not eligible(event_id):
        return false
    var storage: Dictionary = _storage()
    if not (storage.get("active",{}) as Dictionary).is_empty():
        return false
    storage["active"] = {"id":event_id,"line":0}
    if not state.save():
        storage["active"] = {}
        return false
    return true

func resume() -> Dictionary:
    if state == null:
        return {}
    var active: Dictionary = _storage().get("active",{})
    var id: String = str(active.get("id",""))
    if id.is_empty() or not events.has(id) or is_seen(id):
        _storage()["active"] = {}
        return {}
    # Never resume a scene that no longer satisfies A/B, chapter or party gates.
    if not eligible(id):
        _storage()["active"] = {}
        return {}
    return events[id]

func current_line() -> Dictionary:
    var event: Dictionary = resume()
    if event.is_empty():
        return {}
    var index: int = int(_storage().get("active",{}).get("line",0))
    var lines: Array = event.get("dialogue",[])
    return lines[index] if index >= 0 and index < lines.size() else {}

func advance() -> bool:
    var event: Dictionary = resume()
    if event.is_empty():
        return false
    var storage: Dictionary = _storage()
    var active: Dictionary = storage.get("active",{})
    var next_index: int = int(active.get("line",0)) + 1
    if next_index < (event.get("dialogue",[]) as Array).size():
        active["line"] = next_index
        return state.save()
    var id: String = str(event["id"])
    (storage["seen"] as Dictionary)[id] = true
    # Dedicated seen key keeps the branch contract interoperable with flag consumers.
    state.flags[str(event["seen_flag"])] = true
    storage["active"] = {}
    if not state.save():
        (storage["seen"] as Dictionary).erase(id)
        state.flags.erase(str(event["seen_flag"]))
        storage["active"] = active
        return false
    return true

func cancel() -> bool:
    if state == null:
        return false
    var active: Dictionary = _storage().get("active",{})
    if active.is_empty():
        return false
    # A cancelled optional dialogue can be reopened from its first line.
    _storage()["active"] = {}
    return state.save()

func counts() -> Dictionary:
    return {"quests":quest_events.size(), "optional_events":events.size()-48,
        "ending_codas":48, "loaded":errors.is_empty()}

func eligible_events(limit: int = 12) -> Array:
    var result: Array = []
    for id in events:
        if eligible(str(id)):
            result.append(events[id])
            if result.size() >= limit:
                break
    return result
