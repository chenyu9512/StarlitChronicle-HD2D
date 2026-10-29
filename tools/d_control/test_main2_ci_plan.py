#!/usr/bin/env python3
"""Regression: removing a game file must trigger QA and a release comparison."""
from __future__ import annotations

from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
import unittest

import run_main2_ci as ci


class Main2DeletionPlanningTests(unittest.TestCase):
    def test_real_git_deletion_is_in_change_list(self) -> None:
        with TemporaryDirectory() as temp:
            root = Path(temp)
            asset = root / "assets/art/runtime/global_factory_v3/props/example.png"
            asset.parent.mkdir(parents=True)
            asset.write_bytes(b"test-image-placeholder")

            def git(*args: str) -> str:
                result = subprocess.run(
                    ["git", *args], cwd=root, check=True, capture_output=True, text=True
                )
                return result.stdout.strip()

            git("init", "--quiet")
            git("config", "user.email", "ci@invalid.example")
            git("config", "user.name", "Main2 Plan Regression")
            git("add", "-A")
            git("commit", "--quiet", "-m", "baseline")
            before = git("rev-parse", "HEAD")
            asset.unlink()
            git("add", "-A")
            git("commit", "--quiet", "-m", "delete art")
            after = git("rev-parse", "HEAD")

            previous_root = ci.ROOT
            try:
                ci.ROOT = root
                self.assertEqual(
                    ci.diff(before, after),
                    ["assets/art/runtime/global_factory_v3/props/example.png"],
                )
            finally:
                ci.ROOT = previous_root

    def test_deleted_asset_requires_art_checks_and_release(self) -> None:
        previous_diff = ci.diff
        previous_published = ci.last_published_runtime_source
        changed = ["assets/art/runtime/global_factory_v3/props/deleted.png"]
        try:
            ci.diff = lambda before, head: changed
            ci.last_published_runtime_source = lambda: "last-published"
            result = ci.make_plan("previous", "current")
            self.assertIn("art", result["groups"])
            self.assertTrue(result["release_needed"])
            self.assertEqual(result["unpublished_game_files"], changed)
        finally:
            ci.diff = previous_diff
            ci.last_published_runtime_source = previous_published

    def test_deleted_script_and_map_trigger_all_related_checks(self) -> None:
        previous_diff = ci.diff
        previous_published = ci.last_published_runtime_source
        changed = ["scripts/world_interior_v4.gd", "data/levels/v3/map_coast_04.json"]
        try:
            ci.diff = lambda before, head: changed
            ci.last_published_runtime_source = lambda: "last-published"
            result = ci.make_plan("previous", "current")
            self.assertEqual(result["groups"], ["base", "map", "art", "systems"])
            self.assertTrue(result["release_needed"])
        finally:
            ci.diff = previous_diff
            ci.last_published_runtime_source = previous_published


if __name__ == "__main__":
    unittest.main()
