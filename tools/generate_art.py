#!/usr/bin/env python3
"""Single Main2 art generation CLI: V10 replaces the normal generator path.

Existing CI uses --force for read-only Global Factory V3 candidate manifests.
That legacy contract remains supported without overwriting live runtime art.
"""
from __future__ import annotations
import sys
from pathlib import Path

def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    legacy = ("--force", "--scope", "--source-root", "--no-normal-maps", "--no-legacy-ui", "--limit")
    if any(flag in args for flag in legacy):
        from global_art_factory_v3 import main as candidate_main
        return candidate_main(args)
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from main2_merge_regen_replace_cleanup_v10 import main as v10_main
    return v10_main(args)

if __name__ == "__main__":
    raise SystemExit(main())
