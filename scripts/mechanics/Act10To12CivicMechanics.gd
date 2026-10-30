extends "res://scripts/systems/ChapterMechanicsSequence.gd"
## Acts X-XII: player-operated civic/archival pre-crisis sequences.
## The shared V3 transaction saves each action separately. A completed
## sequence authorizes only the existing crisis choice; it never settles a boss,
## fabricates civic completion, alters endings or grants experience.
const SUPPORTED: Array[String] = [
    "ch055","ch056","ch057","ch060",
    "ch061","ch062","ch065","ch070"
]

func configure(id: String) -> bool:
    if id not in SUPPORTED:
        return false
    if not super.configure(id):
        return false
    for step in stages:
        if not (step is Dictionary):
            return false
        var record: Dictionary = step
        var correct: String = str(record.get("correct",""))
        var options: Array = record.get("options",[])
        if correct.is_empty() or options.size() < 2:
            return false
        var found: bool = false
        for option in options:
            if option is Dictionary and str(option.get("id","")) == correct:
                found = true
        if not found:
            return false
    return true
