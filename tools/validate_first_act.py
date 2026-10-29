#!/usr/bin/env python3
"""Validate first-act assets and semantic integration, beyond bare JSON syntax."""
import json
from pathlib import Path
from art_source_contract import resolve
root = Path(__file__).resolve().parents[1]
scene = root/'scenes'/'first_act.tscn'
assert scene.exists(), 'missing first act scene'
project = (root/'project.godot').read_text(encoding='utf-8')
assert 'res://scenes/first_act.tscn' in project, 'main scene must be first act'
for f in ['first_act.gd','first_act_state.gd','first_act_actor.gd','first_act_world.gd','first_act_ui.gd','first_act_battle.gd']:
    assert (root/'scripts'/f).exists(), f
art = json.loads((root/'assets'/'art'/'art_manifest.json').read_text(encoding='utf-8'))
assert len(art['assets']) >= 89, 'first act needs original assets'
for entry in art['assets']:
    svg = root/entry['path']
    png = svg.with_suffix('.png')
    assert resolve(entry['path']).is_file(), svg
    assert resolve(str(png.relative_to(root))).is_file(), png
for path in ['assets/art/characters/leon/walk_4dir_3frames.png',
             'assets/art/characters/lanyin/walk_4dir_3frames.png',
             'assets/art/characters/shuoxian/walk_4dir_3frames.png',
             'assets/art/tilesets/coast_ground.png',
             'assets/art/tilesets/coast_water.png',
             'assets/art/backdrops/coast/tide_lighthouse.png']:
    assert resolve(path).is_file(), path
chapter_file = json.loads((root/'story'/'campaign'/'act_01.json').read_text(encoding='utf-8'))
assert len(chapter_file['chapters']) == 6
expected = [f'ch{x:03d}' for x in range(1,7)]
assert [x['id'] for x in chapter_file['chapters']] == expected
for i,chapter in enumerate(chapter_file['chapters'], start=1):
    assert len(chapter['scenes']) == 4, chapter['id']
    scenes = chapter['scenes']
    assert len(scenes[0].get('dialogue', [])) >= 5
    assert len(scenes[2].get('choice', {}).get('options', [])) == 2
    assert scenes[0]['objectives'][1]['target'] == f'ch{i:03d}.key_npc'
    assert scenes[1]['objectives'][0]['target'] == f'ch{i:03d}.clue'
    assert scenes[1]['objectives'][1]['target'] == f'ch{i:03d}.witness'
    assert scenes[2]['objectives'][0]['target'] == f'ch{i:03d}.choice'
    if i >= 2:
        assert scenes[2]['encounter']['enemy_id'] == f'boss.ch{i:03d}'
        assert scenes[3]['trigger']['requires_flags'] == [f'ch{i:03d}.battle_won']
    else:
        assert scenes[2]['encounter'] is None
    assert scenes[3]['objectives'][0]['target'] == chapter['id']
pro = json.loads((root/'story'/'campaign'/'prologue.json').read_text(encoding='utf-8'))
assert len(pro['scenes']) == 9
bosses = json.loads((root/'story'/'data'/'bosses.json').read_text(encoding='utf-8'))
by_id = {e['id'] for e in bosses['bosses']}
assert all(f'boss.ch{i:03d}' in by_id for i in range(2, 7))
side = json.loads((root/'data'/'first_act_side_quests.json').read_text(encoding='utf-8'))
assert len(side['quests']) == 6
assert [q['chapter'] for q in side['quests']] == list(range(1,7))
for quest in side['quests']:
    assert all(quest[k] for k in ('id','name','start','find','finish'))
assert '9169' in (root/'scripts'/'cheat_panel.gd').read_text(encoding='utf-8')
print('PASS: First Act nine prologue scenes, six playable chapters, 5 boss links, objective IDs, third-party physical art mappings')
