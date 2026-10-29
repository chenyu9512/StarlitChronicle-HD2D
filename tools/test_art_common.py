#!/usr/bin/env python3
"""Verify exact outputs of historical art seed and digest helpers."""
from __future__ import annotations
import hashlib
from pathlib import Path
import tempfile
import unittest
from art_common import stable_seed, sha256_file
from art_style_v6 import _seed
from hd2d_studio_v8 import seed
from global_art_factory_v3 import seeded
from hd2d_studio_v7 import sha256
from hd2d_studio_v9 import digest

class SharedArtHashingTests(unittest.TestCase):
    def test_seed_identity(self):
        cases=[(), ("coast","v8",17), ("boss_ch002","雾潮",123), ("",None,-2,3.5), (0,), ("a|b","c")]
        for case in cases:
            with self.subTest(parts=case):
                expected=int.from_bytes(hashlib.sha256("|".join(map(str,case)).encode()).digest()[:8],"big")
                for fn in (_seed,seed,seeded,stable_seed):
                    self.assertEqual(fn(*case),expected)
    def test_digest_identity(self):
        content=(b"art"+bytes(range(256)))*1300
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/"studio.png"
            for data in (b"",b"sample",content):
                with self.subTest(size=len(data)):
                    path.write_bytes(data)
                    expected=hashlib.sha256(data).hexdigest()
                    for fn in (sha256_file,sha256,digest):
                        self.assertEqual(fn(path),expected)

if __name__=="__main__":
    unittest.main()
