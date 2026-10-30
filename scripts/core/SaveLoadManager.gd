class_name SaveLoadManager
extends RefCounted
## V3 compatibility adapter for the supplied SaveLoadManager concept.
## No SHA-256/HMAC, no hardcoded secret, no anti-cheat, no silent canonical
## flag repairs. The authoritative SaveSlots and FirstActState keep temporary
## file -> backup -> atomic rename and payload structure validation.
## Cheat modifications remain ordinary user-owned V3 progress data.
signal game_saved(slot_id: int, file_path: String)
signal game_loaded(slot_id: int)
signal save_error(slot_id: int, reason: String)

func save_to_slot(slot_id: int, progress: Object, slots: Object) -> Dictionary:
    if progress == null or slots == null:
        return {"ok":false,"reason":"service_unavailable"}
    if not progress._valid_payload(progress._pack()):
        save_error.emit(slot_id,"invalid_v3_structure")
        return {"ok":false,"reason":"invalid_v3_structure"}
    var ok: bool = slots.save_slot(progress,slot_id)
    if not ok:
        save_error.emit(slot_id,"v3_slot_write_failed")
        return {"ok":false,"reason":"v3_slot_write_failed"}
    var location: String = "%s/slot_%02d.json" % [slots.folder,slot_id]
    game_saved.emit(slot_id,location)
    return {"ok":true,"path":location,"version":3,"checksum_required":false}

func load_from_slot(slot_id: int, progress: Object, slots: Object) -> Dictionary:
    if progress == null or slots == null:
        return {"ok":false,"reason":"service_unavailable"}
    # Load_slot checks both the slot and its last valid backup. The caller
    # continues to perform world/party rebinding and autosave rollback.
    var ok: bool = slots.load_slot(progress,slot_id)
    if not ok:
        save_error.emit(slot_id,"v3_slot_or_backup_unreadable")
        return {"ok":false,"reason":"v3_slot_or_backup_unreadable"}
    game_loaded.emit(slot_id)
    return {"ok":true,"version":3,"checksum_required":false}

func save_autosave(progress: Object) -> Dictionary:
    if progress == null:
        return {"ok":false,"reason":"no_progress"}
    return {"ok":bool(progress.save()),"version":3,"checksum_required":false}

func load_autosave(progress: Object) -> Dictionary:
    if progress == null:
        return {"ok":false,"reason":"no_progress"}
    return {"ok":bool(progress.load_saved()),"version":3,"checksum_required":false}
