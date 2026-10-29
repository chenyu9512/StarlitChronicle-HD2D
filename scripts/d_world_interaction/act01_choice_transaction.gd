extends RefCounted
## Persist the canonical A/B story choice together with its optional follow-up
## receipt. A failed V3 save must not keep choice flags or consume a dialogue.
const Transition = preload("res://scripts/d_world_interaction/v3_progress_transition.gd")

static func commit(progress: Object, director: Object, item: Dictionary,
        choice_id: String) -> Dictionary:
    if progress == null or director == null or choice_id.is_empty():
        return {"ok":false,"reason":"invalid_choice"}
    if not director.has_method("reaction") or not director.has_method("mark_seen"):
        return {"ok":false,"reason":"invalid_optional_director"}
    if not (item.get("sets",{}) is Dictionary):
        return {"ok":false,"reason":"invalid_choice_flags"}
    return Transition.commit(progress,func() -> Dictionary:
        var changes: Dictionary=item.get("sets",{})
        for raw_key in changes.keys():
            progress.flags[str(raw_key)]=changes[raw_key]
        progress.flags[choice_id+".chosen"]=true
        var additional: Array=[]
        var followup: Dictionary=director.call("reaction",progress.chapter,item,progress.flags)
        if not followup.is_empty() and bool(director.call("mark_seen",followup)):
            additional=(followup.get("dialogue",[]) as Array).duplicate(true)
        return {"ok":true,"response_dialogue":additional}
    )
