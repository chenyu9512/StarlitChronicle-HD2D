extends "res://scripts/systems/ChapterMechanicsSequence.gd"
## Player-facing adapter for authored X-XII story decisions.
## The separate Act10To12EndgameMechanics records POST-commit state only.
## These actions never manufacture actual chapter/boss/ending receipts.
const CHAPTERS: Array[String] = [
    "ch058","ch059","ch060","ch064","ch066","ch071","ch072"
]

func configure(id: String) -> bool:
    if id not in CHAPTERS or not super.configure(id):
        return false
    var known: Dictionary = {}
    for row in stages:
        if not (row is Dictionary):
            return false
        var phase: Dictionary = row
        var key: String = str(phase.get("correct",""))
        var choices: Array = phase.get("options",[])
        if key.is_empty() or known.has(key) or choices.size() < 2:
            return false
        known[key] = true
        var matches: int = 0
        var choice_ids: Dictionary = {}
        for choice in choices:
            if not (choice is Dictionary):
                return false
            var cid: String = str(choice.get("id",""))
            if cid.is_empty() or choice_ids.has(cid):
                return false
            choice_ids[cid] = true
            if cid == key:
                matches += 1
        if matches != 1:
            return false
    return true

func get_prompt(state: Dictionary) -> Dictionary:
    var view: Dictionary = super.get_prompt(state)
    if not view.is_empty() and not bool(view.get("done",false)):
        view["prompt"] = str(view.get("prompt","")).replace("机关调查","关键行动")
    return view
