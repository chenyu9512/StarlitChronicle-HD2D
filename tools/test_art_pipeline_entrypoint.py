#!/usr/bin/env python3
"""Fast, non-destructive checks for the canonical art entrypoint."""
from __future__ import annotations
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class CanonicalGeneratorEntrypointTests(unittest.TestCase):
    def invoke(self, script: str):
        proc = subprocess.run(
            [sys.executable, str(ROOT / script), "--help"],
            cwd=ROOT, text=True, capture_output=True, timeout=25, check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("--verify-only", proc.stdout)
        self.assertIn("--cleanup-dry-run", proc.stdout)
        self.assertIn("--refined", proc.stdout)

    def test_public_entrypoint_help(self):
        self.invoke("tools/generate_art.py")

    def test_compatibility_shim_help(self):
        self.invoke("main2_merge_regen_replace_cleanup_v10.py")

    def test_single_canonical_pipeline_implementation(self):
        pipeline = (ROOT / "tools/art_pipeline.py").read_text(encoding="utf-8")
        shim = (ROOT / "main2_merge_regen_replace_cleanup_v10.py").read_text(encoding="utf-8")
        launcher = (ROOT / "tools/generate_art.py").read_text(encoding="utf-8")
        self.assertIn("def promote(", pipeline)
        self.assertIn("def cleanup(", pipeline)
        self.assertNotIn("def promote(", shim)
        self.assertNotIn("def cleanup(", shim)
        self.assertIn("from art_pipeline import main", launcher)

if __name__ == "__main__":
    unittest.main()
