extends RefCounted
## Atomic V3 persistence for the Phase19 evidence gallery, deductions and
## quest tracking. Mutate only inside the existing D-line transaction boundary.
## No UI side effects, no rewards, and no changes to the save-file schema.
const Settlement = preload("res://scripts/d_world_interaction/world_object_settlement.gd")

static func observe(progress: Object, quest_id: String, step: int) -> Dictionary:
    if progress == null or quest_id.is_empty() or step < 0 or step > 2:
        return {"ok":false,"reason":"invalid_evidence"}
    return Settlement.transact(progress,func() -> Dictionary:
        var raw_gallery: Variant=progress.rpg.get("quest_gallery",{})
        var gallery: Dictionary=raw_gallery if raw_gallery is Dictionary else {}
        var raw_record: Variant=gallery.get(quest_id,{})
        var record: Dictionary=raw_record if raw_record is Dictionary else {}
        var key: String=str(step)
        if bool(record.get(key,false)):
            return {"ok":true,"changed":false,"result":{"seen":true}}
        record[key]=true
        gallery[quest_id]=record
        progress.rpg["quest_gallery"]=gallery
        return {"ok":true,"changed":true,"result":{"seen":true}}
    )

static func answer(progress: Object, puzzle_runtime: Object,
        quest_id: String, option_id: String, chapter: int) -> Dictionary:
    if progress == null or puzzle_runtime == null or quest_id.is_empty():
        return {"ok":false,"reason":"invalid_evidence"}
    if not puzzle_runtime.has_method("result"):
        return {"ok":false,"reason":"missing_evidence_runtime"}
    return Settlement.transact(progress,func() -> Dictionary:
        var value: Variant=puzzle_runtime.call("result",progress.rpg,quest_id,option_id,chapter)
        if not (value is Dictionary):
            return {"ok":false,"reason":"invalid_evidence_result"}
        var result: Dictionary=value
        return {"ok":true,"changed":bool(result.get("accepted",false)),"result":result}
    )

static func track(progress: Object, event_id: String) -> Dictionary:
    if progress == null or event_id.is_empty():
        return {"ok":false,"reason":"invalid_story_event"}
    return Settlement.transact(progress,func() -> Dictionary:
        if str(progress.rpg.get("tracked_branch_event",""))==event_id:
            return {"ok":true,"changed":false}
        progress.rpg["tracked_branch_event"]=event_id
        return {"ok":true,"changed":true}
    )
