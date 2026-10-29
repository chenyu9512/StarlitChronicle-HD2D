"""Deterministic cross-system fixture tests; no game state changes or bypasses."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from test_audit import make_fixture
from verify_crosslinks import verify


class CrossLinkTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write = make_fixture(self.root)
        path = 'data/gameplay/boss_mechanics.json'
        data = json.loads((self.root / path).read_text())
        for entry in data['entries']:
            entry['chapter'] = int(entry['boss_id'][-3:])
        self.write(path, data)
        self.write('story/data/phase19_quest_world_anchors.json', {'quests': [
            {'quest_id': f'{prefix}_{i:03}', 'first_chapter': 'ch001', 'map_id': 'map_00'}
            for prefix, count in [('sq', 36), ('rq', 36), ('cq', 48)]
            for i in range(count)]})

    def test_good_links_are_not_runtime_acceptance(self):
        report = verify(self.root)
        self.assertEqual(report['status'], 'STATIC_PASS_RUNTIME_UNVERIFIED', report['errors'])
        self.assertEqual(report['counts']['side_quests'], 120)

    def test_bad_quest_map(self):
        file = 'story/data/phase19_quest_world_anchors.json'
        j = json.loads((self.root / file).read_text())
        j['quests'][0]['map_id'] = 'orphan_map'
        self.write(file, j)
        self.assertIn('absent active map', ' '.join(verify(self.root)['errors']))

    def test_duplicate_boss(self):
        file = 'story/data/bosses.json'
        j = json.loads((self.root / file).read_text())
        j['bosses'][1]['id'] = j['bosses'][0]['id']
        self.write(file, j)
        self.assertIn('duplicate ID', ' '.join(verify(self.root)['errors']))

    def test_missing_chapter_gate(self):
        file = 'story/campaign/act_02.json'
        j = json.loads((self.root / file).read_text())
        j['chapters'][0]['required_flags'] = []
        self.write(file, j)
        self.assertIn('missing mandatory previous', ' '.join(verify(self.root)['errors']))


if __name__ == '__main__':
    unittest.main()
