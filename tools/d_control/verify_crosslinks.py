#!/usr/bin/env python3
"""D-line strict cross-system static validator. No Godot/network and no file mutation."""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path


def verify(root: Path) -> dict:
    errors: list[str] = []
    warnings: list[str] = []
    def read(path: str):
        return json.loads((root / path).read_text(encoding='utf-8-sig'))
    try:
        chapters = [c for n in range(1, 13) for c in read(f'story/campaign/act_{n:02}.json')['chapters']]
        boss = read('story/data/bosses.json')['bosses']
        mech = read('data/gameplay/boss_mechanics.json')['entries']
        maps = read('data/levels/world_levels_v3.json')['levels']
        catalog_maps = read('data/content/maps.json')['entries']
        jobs = read('story/data/jobs.json')['jobs']
        profiles = read('data/gameplay/vocation_profiles.json')['jobs']
        families = [read(f'story/data/{name}.json')['quests'] for name in
                    ['side_quests', 'regional_quests_v2', 'companion_quests']]
        anchors = read('story/data/phase19_quest_world_anchors.json')['quests']
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return {'status': 'FAIL', 'errors': [f'Cannot load required content: {exc}'],
                'warnings': [], 'counts': {}, 'runtime_test': 'NOT_RUN'}
    quests = [q for family in families for q in family]
    counts = {'chapters': len(chapters), 'bosses': len(boss), 'mechanics': len(mech),
              'maps': len(maps), 'jobs': len(jobs), 'side_quests': len(quests),
              'quest_anchors': len(anchors)}
    for key, target in [('chapters',72),('bosses',66),('mechanics',66),('maps',40),
                        ('jobs',20),('side_quests',120),('quest_anchors',120)]:
        if counts[key] != target:
            errors.append(f'{key}: expected {target}, got {counts[key]}')
    def duplicates(label, ids):
        for key, n in Counter(ids).items():
            if not key or n != 1:
                errors.append(f'{label} empty/duplicate ID {key!r}: {n}')
    duplicates('chapter', [c['id'] for c in chapters])
    duplicates('boss', [b['id'] for b in boss])
    duplicates('mechanics', [m['boss_id'] for m in mech])
    duplicates('quest', [q['id'] for q in quests])
    duplicates('anchors', [a['quest_id'] for a in anchors])
    duplicates('jobs', [j['id'] for j in jobs])
    stage_ids = []
    for n, chapter in enumerate(chapters, 1):
        cid = f'ch{n:03}'
        if chapter['id'] != cid:
            errors.append(f'{cid}: wrong chapter order')
        preceding = 'story.prologue_done' if n == 1 else f'story.ch{n-1:03}.done'
        if preceding not in chapter.get('required_flags', []):
            errors.append(f'{cid}: missing mandatory previous chapter flag')
        if not chapter.get('scenes'):
            errors.append(f'{cid}: no authored scenes')
        stage_ids.extend(s.get('id') for s in chapter.get('scenes', []))
    duplicates('global scene', stage_ids)
    boss_ids = {b['id'] for b in boss}
    mechanized = {m['boss_id']: m for m in mech}
    if boss_ids != set(mechanized):
        errors.append('boss IDs mismatch between story and live mechanics')
    for b in boss:
        bm = mechanized.get(b['id'])
        if bm and int(bm.get('chapter', -1)) != int(b.get('chapter_id', 'ch000')[2:]):
            errors.append(f"{b['id']}: boss-mechanics chapter mismatch")
    if {j['id'] for j in jobs} != set(profiles):
        errors.append('20-job catalog and runtime profiles disagree')
    catalog_ids = {m['id'] for m in catalog_maps if m.get('status') != 'prototype'}
    if set(maps) != catalog_ids:
        errors.append('Active map IDs differ from active map catalog')
    anchor_index = {a['quest_id']: a for a in anchors}
    if set(anchor_index) != {q['id'] for q in quests}:
        errors.append('Canonical 120 quest IDs differ from 120 world anchor IDs')
    chapters_set = {c['id'] for c in chapters}
    for q in quests:
        qid = q['id']
        if not q.get('completion_flag'):
            errors.append(f'{qid}: no completion flag')
        if q.get('required_chapter') not in chapters_set:
            errors.append(f'{qid}: invalid required chapter')
        anchor = anchor_index.get(qid)
        if anchor:
            if q.get('required_chapter') != anchor.get('first_chapter'):
                errors.append(f'{qid}: inconsistent chapter unlock and map marker')
            if anchor.get('map_id') not in maps:
                errors.append(f'{qid}: world marker references absent active map')
        if len({s.get('id') for s in q.get('stages', [])}) != len(q.get('stages', [])):
            errors.append(f'{qid}: duplicate quest stage ID')
    warnings.append('Static links do not prove NPC interactions, quests or Boss battle settlement')
    return {'status': 'FAIL' if errors else 'STATIC_PASS_RUNTIME_UNVERIFIED',
            'errors': errors, 'warnings': warnings, 'counts': counts,
            'runtime_test': 'NOT_RUN'}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument('--json', action='store_true')
    a = p.parse_args()
    result = verify(a.root)
    print(json.dumps(result, ensure_ascii=False, indent=2) if a.json else
          f"{result['status']}: {result['counts']}; errors={result['errors']}")
    return int(result['status'] == 'FAIL')


if __name__ == '__main__':
    raise SystemExit(main())
