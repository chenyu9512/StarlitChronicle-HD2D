#!/usr/bin/env python3
"""Stable Main2 art generation entrypoint. Public CLI stays version-neutral.

Existing CI uses --force for read-only Global Factory V3 candidate manifests.
That legacy contract remains supported without overwriting live runtime art.
"""
from __future__ import annotations
import sys

def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    legacy = ("--force", "--scope", "--source-root", "--no-normal-maps", "--no-legacy-ui", "--limit")
    if any(flag in args for flag in legacy):
        from global_art_factory_v3 import main as candidate_main
        return candidate_main(args)
    from art_pipeline import main as pipeline_main
    return pipeline_main(args)

if __name__ == "__main__":
    raise SystemExit(main())
