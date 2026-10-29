extends Node
## Converts authored ch021 direction into an unskippable presentation cue.
## The gameplay caller owns V3 checkpointing and the later choice UI.
const CUE_ID: String = "direction.ch021.crisis"
const PRESENT_ERA: String = "present_campfire"

func build_cue(scene: Dictionary) -> Dictionary:
    if str(scene.get("id", "")) != "ch021.crisis":
        return {}
    var choice: Dictionary = scene.get("choice", {})
    var direction: Dictionary = scene.get("direction", {})
    if str(choice.get("id", "")) != "ch021.choice":
        return {}
    if str(direction.get("phase11_player_time_transition", "")).is_empty():
        return {}
    var evidence: String = str(direction.get("shot", ""))
    if evidence.is_empty():
        return {}
    # Each beat needs player confirmation. No choice is contained in this cue.
    # The last beat is explicitly on the present-day side of the time cut.
    return {
        "title":"药房门前 · 时间切换",
        "sub":"第21章 · 十年前的回忆结束",
        "location":"十年后 · 现世营火旁",
        "tone":"grief",
        "can_skip":false,
        "lines":[
            {"speaker":"环境音","text":"药房门外的风声先于解释响起。"},
            {"speaker":"实物证据","text":evidence},
            {"speaker":"留白","text":"……"},
            {"speaker":"现世","text":"回忆停在药房门前。十年后，营火仍在燃烧；现在由成年的同伴回应彼此。"}
        ]
    }

func choice_is_unlocked(progress: Object) -> bool:
    if progress == null:
        return false
    return int(progress.get("chapter")) == 21 and int(progress.get("scene_index")) == 2 \
        and bool(progress.flags.get("ch021.campfire_returned", false)) \
        and str(progress.rpg.get("direction_ch021_era", "")) == PRESENT_ERA
