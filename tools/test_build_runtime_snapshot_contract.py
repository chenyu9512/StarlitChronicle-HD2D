#!/usr/bin/env python3
"""Focused regression coverage for the first-act Runtime snapshot builder."""
import ast
import inspect
import textwrap
import unittest

from build_runtime_snapshot import create_snapshot, is_game_file


class RuntimeSnapshotContractTests(unittest.TestCase):
    def test_chinese_font_resource_and_future_font_files_are_shipped(self):
        self.assertTrue(is_game_file("assets/fonts/chinese_system_font.tres"))
        self.assertTrue(is_game_file("assets/fonts/NotoSansSC-Regular.ttf"))
        self.assertTrue(is_game_file("assets/fonts/fallback.otf"))
        self.assertFalse(is_game_file("assets/fonts/notes.txt"))

    def test_gameplay_script_and_scene_are_shipped(self):
        self.assertTrue(is_game_file("scripts/font_setup.gd"))
        self.assertTrue(is_game_file("scenes/first_act.tscn"))
        self.assertFalse(is_game_file("assets/art/source_packs/unapproved.png"))

    def test_manifest_image_loop_does_not_shadow_source_directory(self):
        # The regression changed source: Path to source: str while iterating
        # the supplemental manifest. AST detects accidental future rebinding.
        parsed = ast.parse(textwrap.dedent(inspect.getsource(create_snapshot)))
        function = parsed.body[0]
        assignments = []
        for statement in ast.walk(function):
            if isinstance(statement, (ast.Assign, ast.AnnAssign, ast.NamedExpr)):
                targets = (statement.targets if isinstance(statement, ast.Assign)
                           else [statement.target])
                for target in targets:
                    names = [node.id for node in ast.walk(target)
                             if isinstance(node, ast.Name)]
                    if "source" in names:
                        assignments.append(statement.lineno)
        # Initial source/output Path normalisation is the only allowed binding.
        self.assertEqual(len(assignments), 1, assignments)


if __name__ == "__main__":
    unittest.main()
