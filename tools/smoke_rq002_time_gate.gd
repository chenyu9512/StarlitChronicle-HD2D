extends SceneTree
## Regression for rq_002: no flag or A/B save state may bypass chapter locks.
const State = preload("res://scripts/first_act_state.gd")
const Branch = preload("res://scripts/story_branch_runtime.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var branch = Branch.new()
    assert(branch.load_all())
    for approach in ["a","b"]:
        var state = State.new()
        state.new_game()
        branch.bind(state)
        var chosen: String = "rq_002.p17.%s" % approach
        var other: String = "rq_002.p17.%s" % ("b" if approach=="a" else "a")
        state.chapter = 5
        assert(not branch.eligible(chosen+".followup")) # no original completion
        state.flags["side.rq_002.done"] = true
        state.flags["side.rq_002.approach"] = approach
        state.chapter = 4
        assert(not branch.eligible(chosen+".followup")) # flags cannot skip chapter 5
        state.chapter = 5
        assert(branch.eligible(chosen+".followup"))
        assert(not branch.eligible(other+".followup")) # exclusive A/B route
        state.rpg["branch_story"]["seen"][chosen+".followup"] = true
        assert(not branch.eligible(chosen+".followup")) # no duplicate reward path
        state.rpg["branch_story"]["seen"][chosen+".community"] = true
        state.chapter = 19
        assert(not branch.eligible(chosen+".revisit")) # chapter 18 completion required
        state.flags["story.ch018.done"] = true
        state.chapter = 17
        assert(not branch.eligible(chosen+".revisit"))
        state.chapter = 18
        assert(not branch.eligible(chosen+".revisit")) # only AFTER chapter 18
        state.chapter = 19
        assert(branch.eligible(chosen+".revisit"))
        assert(not branch.eligible(other+".revisit"))
        print("PASS: rq_002 %s chapter-5 followup, exclusive choice and post-18 revisit" % approach)
    quit(0)
