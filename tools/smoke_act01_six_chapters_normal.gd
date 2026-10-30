extends SceneTree
## Prologue and all six chapters on normal stats, real player commands and durable rewards.\n## No invincibility, boosted stats, cheat completion or forged battle callbacks.
## Marker positioning bypasses walking; this is NOT human navigation/visual acceptance.
const Game = preload("res://scripts/first_act.gd")
const State = preload("res://scripts/first_act_state.gd")
const Settlement = preload("res://scripts/d_world_interaction/battle_v3_settlement.gd")
const Registry = preload("res://scripts/encounter_registry.gd")
var game
var failures: Array[String] = []
var boss_pacing: Array[Dictionary] = []
const MAX_BOSS_ROUNDS: int = 24
const MAX_BOSS_COMMANDS: int = 64

func _initialize() -> void:
    call_deferred("_run")

func _touch(target: String) -> void:
    if not game.world.nodes.has(target):
        failures.append("Missing map target: " + target)
        return
    game.world.hero.position = game.world.nodes[target].position + Vector2(0, 18)
    game.world.interact()

func _enter_canonical_chapter(chapter: int) -> void:
    if chapter>6 or chapter<1:
        return
    var required: String=game.world_router.act01_target_map(chapter)
    for hop in range(5):
        if game.world_router.current_map()==required:
            return
        var route: Array[String]=game.world_router.route_towards(required)
        if route.size()<2:
            failures.append("Chapter %d has no unlocked, physically adjacent route to %s" % [chapter,required])
            return
        var exit_node: String="exit:"+route[1]
        if not game.world.nodes.has(exit_node):
            failures.append("Missing physical border gate "+exit_node)
            return
        var previous: String=game.world_router.current_map()
        _touch(exit_node)
        if game.world_router.current_map()==previous:
            failures.append("Physical gate did not advance from "+previous+" to "+route[1])
            return
    failures.append("Chapter route exceeded five physical exits")

# Exercise the real evidence hotspot UI, not a forged evidence flag.
# Chapter 1 and Chapter 3 require player-selected physical observations
# before their clue dialogue is allowed to progress.
func _inspect_canon_evidence() -> void:
    var attempts: int = 0
    while game.pending == "canon_evidence" and attempts < 24:
        var options: Array[Node] = game.ui.choice_area.get_children()
        if options.is_empty() or not (options[0] is Button):
            failures.append("Evidence close-up has no selectable hotspot")
            return
        (options[0] as Button).pressed.emit()
        attempts += 1
    if game.pending == "canon_evidence":
        failures.append("Physical evidence investigation did not finish within 24 choices")

func _dialog() -> void:
    for i in range(30):
        if not game.ui.dialog_layer.visible or game.ui.choosing:
            break
        game.ui._next()
    if game.ui.dialog_layer.visible and not game.ui.choosing:
        failures.append("Dialogue did not finish in 30 steps")

# Guard the public V3 settlement endpoint separately from the controller.
# A normal six-chapter playthrough below still proves valid rescues work.
func _reject_invalid_story_outcomes() -> void:
    for chapter_no in [5,6]:
        var probe = State.new()
        probe.chapter = chapter_no
        var before: Dictionary = probe._pack().duplicate(true)
        var expected: String = "invalid_beast_resolution" if chapter_no == 5 else "invalid_lighthouse_resolution"
        var invalid: Array[String] = ["", "defeated", "testimony" if chapter_no == 5 else "nonlethal"]
        for outcome in invalid:
            var result: Dictionary = Settlement.settle_victory(
                probe,RefCounted.new(),"boss:boss.ch%03d/crisis" % chapter_no,
                chapter_no,true,[],"",60,50,1,outcome)
            if bool(result.get("ok",false)) or str(result.get("reason","")) != expected:
                failures.append("Chapter %d accepted invalid story outcome: '%s'" % [chapter_no,outcome])
            if probe._pack() != before:
                failures.append("Chapter %d invalid boss receipt mutated V3 progress" % chapter_no)

func _run() -> void:
    _reject_invalid_story_outcomes()
    var boss_registry = Registry.new()
    game = Game.new()
    root.add_child(game)
    var folder: String = "user://act01_six_normal_%d" % OS.get_process_id()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    game.progress.save_path = folder + "/save.json"
    game.progress.backup_path = folder + "/backup.json"
    game.ui.title_overlay.hide()
    game._start(false)
    if game.invincible or game.five_xp or game.no_encounters:
        failures.append("New game enabled cheats or disabled random encounters")
    var initial_stats: Array[Dictionary]=game.progress.actors.duplicate(true)
    if int(initial_stats[0].get("level",0))!=1 or int(initial_stats[1].get("level",0))!=1:
        failures.append("Normal run did not start at canonical level-one stats")
    for idx in range(9):
        if game.progress.chapter != 0 or game.progress.scene_index != idx:
            failures.append("Prologue sequence interrupted at %d" % idx)
            break
        _touch("prologue_%d" % idx)
        _dialog()
    if game.progress.chapter != 1:
        failures.append("Prologue did not unlock chapter one")
    for chapter in range(1, 7):
        if game.progress.chapter != chapter:
            failures.append("Chapter progression stopped before %d" % chapter)
            break
        _enter_canonical_chapter(chapter)
        # Three distinct side-quest objects must actually be visited.
        _touch("side_start")
        _dialog()
        _touch("side_item")
        _dialog()
        _touch("side_return")
        _dialog()
        if game._side_step() != -1:
            failures.append("Chapter %d side quest did not complete" % chapter)
        # Chapter 2's real clinic opening happens outside, but all later
        # evidence, choices and battle require entering its authored V4 room.
        # Chapter 4 starts inside the real Black Sail tavern.
        if chapter == 4:
            _touch("building:tavern")
            if game.world.interior_building != "tavern":
                failures.append("Chapter 4 could not physically enter the tavern")
        _touch("key_npc")
        _dialog()
        if chapter == 2:
            _touch("building:shelter")
            if game.world.interior_building != "shelter":
                failures.append("Chapter 2 could not physically enter the clinic")
        if chapter in [2,4]:
            var required_room: String = "shelter" if chapter == 2 else "tavern"
            var observed: Array = game.world.terrain_layout.get("act01_main_story_evidence", [])
            if observed.size() != 2:
                failures.append("Chapter %d has no two physical V4 investigation records" % chapter)
            else:
                for evidence_id in observed:
                    # Invokes the actual proximity-gated HomeInteractions
                    # transaction; no fabricated V3 evidence flags.
                    _touch("homeinspect:" + str(evidence_id))
                    var record: Dictionary = game.room_investigations.snapshot(
                        game.progress,game.world_router.current_map(),required_room,str(evidence_id))
                    if not bool(record.get("seen_before", false)):
                        failures.append("Chapter %d physical evidence was not saved: %s" % [chapter,str(evidence_id)])
        # Chapters 5 and 6 have genuine world-site investigations.
        # Visit each actual on-map marker in the prescribed order; the
        # controller owns the V3 transaction and enforces proximity/order.
        # Never set flags, RPG receipts or battle-win fields in this test.
        if chapter == 5:
            var shoal_observations: Array[String] = ["red_flag","star_chain","retreat_line"]
            for observation in shoal_observations:
                _touch("shoal:" + observation)
                var persisted: Dictionary = game.world.shoal_plan.snapshot(game.progress)
                if not bool(persisted.get(observation,false)):
                    failures.append("Chapter 5 physical shoal evidence not saved: " + observation)
            if not game.world.shoal_plan.fully_observed(game.progress):
                failures.append("Chapter 5 rescue prerequisites not satisfied")
        if chapter == 6:
            var lamp_fragments: Array[String] = ["breakwater_wick","keeper_wick","summit_wick"]
            for fragment in lamp_fragments:
                _touch("wick:" + fragment)
                var persisted: Dictionary = game.world.lighthouse_plan.snapshot(game.progress)
                if not bool(persisted.get(fragment,false)):
                    failures.append("Chapter 6 physical lamp fragment not saved: " + fragment)
            if not game.world.lighthouse_plan.all_fragments_found(game.progress):
                failures.append("Chapter 6 lantern prerequisites not satisfied")
        _touch("clue")
        _inspect_canon_evidence()
        _dialog()
        _touch("witness")
        _touch("crisis")
        _dialog()
        if not game.ui.choosing:
            failures.append("Chapter %d failed to display actual branching choice" % chapter)
        else:
            var buttons: Array[Node] = game.ui.choice_area.get_children()
            if buttons.is_empty():
                failures.append("No choice available at %d" % chapter)
            else:
                var button: Button = buttons[0] as Button
                button.pressed.emit()
                if game.pending == "choice_reaction":
                    _dialog()
        if chapter >= 5:
            var sailor_level: int = -1
            var starter_levels: Array[int] = []
            for ally in game.progress.actors:
                if str(ally.get("id","")) == "char_seeker":
                    sailor_level = int(ally.get("level",0))
                elif str(ally.get("id","")) in ["char_wayfarer","char_tidecaller"]:
                    starter_levels.append(int(ally.get("level",0)))
            if sailor_level < 1 or starter_levels.size()!=2 or absi(sailor_level-starter_levels[0]) > 2 or absi(sailor_level-starter_levels[1]) > 2:
                failures.append("Chapter %d sailor level %d is unbalanced against the starting party: %s" % [chapter,sailor_level,str(starter_levels)])
        if chapter > 1:
            if chapter in [2,3] and game.battle == null and game.progress.task_index == 1:
                if not game._save_progress() or not game.progress.load_saved():
                    failures.append("Pre-boss save/load failed")
                game._enter_location()
                _touch("crisis")
                if game.battle != null:
                    game.battle.dice.seed = 731 + chapter
            # Exercise actual scene commands with normal, unboosted party state.
            # Record objective evidence and combat pacing before the Battle node
            # can be freed by the authoritative settlement callback.
            var actual_battle_id: String = str(game.battle.reward_transaction_id) if game.battle != null else ""
            var opening_levels: Array[int] = []
            for actor in game.progress.actors:
                opening_levels.append(int(actor.get("level",0)))
            var opening_herbs: int = int(game.progress.inventory.get("item_herb_01",0))
            var count: int = 0
            var last_round: int = 0
            var guards: int = 0
            var herbs: int = 0
            var specials: int = 0
            var strikes: int = 0
            var damage_taken: int = 0
            var guarded_strikes: int = 0
            var hp_before: int = 0
            for actor in game.progress.actors:
                hp_before += int(actor.get("hp",0))
            if game.battle != null and not game.battle.foe_info.text.contains("第1回合"):
                failures.append("Chapter %d Boss HUD has no opening round counter" % chapter)
            while game.battle != null and count < 100:
                var b = game.battle
                last_round = maxi(last_round,b.current_round)
                if b.hero_turn < 0 or b.hero_turn >= game.progress.actors.size():
                    failures.append("Chapter %d invalid actor turn index" % chapter)
                    break
                var member: Dictionary = game.progress.actors[b.hero_turn]
                if int(member["hp"]) < int(member["max_hp"]) / 2 and game.progress.potions > 0:
                    herbs += 1
                    b._act("potion")
                elif float(b.round_boss_intent.get("multiplier",1.0)) > 1.5:
                    guards += 1
                    b._act("guard")
                else:
                    specials += 1
                    b._act("special")
                count += 1
                # The authoritative callback may detach the Battle immediately
                # upon victory, but the local node remains valid until freed.
                if is_instance_valid(b):
                    strikes = b.enemy_strike_count
                    damage_taken = b.enemy_damage_dealt
                    guarded_strikes = b.enemy_guarded_strikes
            if game.battle != null:
                failures.append("Boss fight in chapter %d cannot finish" % chapter)
            # An envelope rather than an arbitrary HP nerf: preserve authored
            # mechanics while rejecting softlocks and excessively long fights.
            if last_round > MAX_BOSS_ROUNDS or count > MAX_BOSS_COMMANDS:
                failures.append("Chapter %d Boss exceeded normal pacing envelope (%d rounds, %d commands)" % [chapter,last_round,count])
            if count == 0 or specials == 0:
                failures.append("Chapter %d Boss ended without an earned player special action" % chapter)
            if int(game.progress.inventory.get("item_herb_01",0)) > opening_herbs:
                failures.append("Chapter %d Boss unexpectedly created healing herbs" % chapter)
            var hp_after: int = 0
            for actor in game.progress.actors:
                hp_after += int(actor.get("hp",0))
            var recommended_level: int = int(boss_registry.progression(chapter).get("recommended_level",chapter))
            var peak_level: int = 0
            for level in opening_levels:
                peak_level = maxi(peak_level,level)
            # The starting heroes should remain close to the recommended
            # chapter level; the authored sailor is recruited pre-levelled.
            for party_index in range(mini(2,opening_levels.size())):
                if absi(opening_levels[party_index]-recommended_level) > 2:
                    failures.append("Chapter %d original hero level %d deviates from recommended %d" % [chapter,opening_levels[party_index],recommended_level])
            var metric: Dictionary = {"chapter":chapter,"levels":opening_levels,
                "recommended_level":recommended_level,"max_level_gap":peak_level-recommended_level,
                "enemy_strikes":strikes,"enemy_damage":damage_taken,
                "guarded_enemy_strikes":guarded_strikes,
                "rounds":last_round,"commands":count,"guard_commands":guards,
                "herb_commands":herbs,"special_commands":specials,
                "herbs_before":opening_herbs,
                "herbs_after":int(game.progress.inventory.get("item_herb_01",0)),
                "party_hp_before":hp_before,"party_hp_after":hp_after,
                "battle_won":bool(game.progress.flags.get("ch%03d.battle_won" % chapter,false))}
            boss_pacing.append(metric)
            print("ACT01_BOSS_PACING " + JSON.stringify(metric))
            if not bool(game.progress.flags.get("ch%03d.battle_won" % chapter, false)):
                failures.append("Chapter %d victory flag missing" % chapter)
            if actual_battle_id.is_empty():
                failures.append("Chapter %d had no A-line battle nonce" % chapter)
            else:
                var a_receipts: Dictionary = game.progress.rpg.get("battle_reward_transactions",{})
                var d_journal: Dictionary = game.progress.rpg.get("d_reward_receipts_v1",{})
                var d_receipts: Dictionary = d_journal.get("consumed",{})
                if not a_receipts.has(actual_battle_id) or not d_receipts.has(actual_battle_id):
                    failures.append("Chapter %d real-command victory did not persist both receipts" % chapter)
                if chapter in [5,6]:
                    var expected_outcome: String = "nonlethal" if chapter == 5 else "testimony"
                    var receipt: Dictionary = d_receipts.get(actual_battle_id,{})
                    var intent: Dictionary = receipt.get("intent",{})
                    if str(intent.get("story_resolution","")) != expected_outcome:
                        failures.append("Chapter %d boss receipt lost canonical story outcome" % chapter)
            if chapter == 5 and not bool(game.progress.flags.get("ch005.beast_released",false)):
                failures.append("Fifth-chapter rescue was not durably recorded")
            if chapter == 6 and not bool(game.progress.flags.get("ch006.lighthouse_testimony",false)):
                failures.append("Sixth-chapter testimony was not durably recorded")
        _touch("resolve")
        _dialog()
        if not bool(game.progress.flags.get("story.ch%03d.done" % chapter, false)):
            failures.append("Chapter %d completion flag missing" % chapter)
    if boss_pacing.size() != 5:
        failures.append("First-act pacing report did not record all five real Boss battles")
    if game.progress.chapter != 7 or not bool(game.progress.flags.get("story.ch006.done",false)):
        failures.append("Six-chapter normal run did not unlock chapter seven")
    if game.progress.actors.size()!=3:
        failures.append("Chapter-4 sailor recruit did not persist into chapter seven")
    for boss_chapter in range(2,7):
        if not bool(game.progress.flags.get("ch%03d.battle_won" % boss_chapter,false)):
            failures.append("Normal run did not retain boss victory %d" % boss_chapter)
    if game.invincible or game.five_xp or game.no_encounters:
        failures.append("Controller enabled a cheat during six-chapter progression")
    var disk=State.new()
    disk.save_path=game.progress.save_path
    disk.backup_path=game.progress.backup_path
    if not disk.load_saved():
        failures.append("Final six-chapter V3 checkpoint cannot reload")
    elif disk.chapter!=7 or not bool(disk.flags.get("story.ch006.done",false)):
        failures.append("Reloaded V3 save lost sixth-chapter completion")
    elif not bool(disk.flags.get("ch005.beast_released",false)) or not bool(disk.flags.get("ch006.lighthouse_testimony",false)):
        failures.append("Reloaded V3 save lost the humane rescue or shared testimony")
    # Tests are not allowed to create or overwrite the player's default save.
    for path in [game.progress.save_path,game.progress.backup_path,
        game.progress.save_path+".tmp",game.progress.backup_path+".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
    if failures.is_empty():
        print("PASS Act I: all six chapters, ordinary stats, real commands, side quests, boss receipts and reload; walking/visual QA remains separate")
        quit(0)
    else:
        for error in failures:
            push_error(error)
        quit(1)
