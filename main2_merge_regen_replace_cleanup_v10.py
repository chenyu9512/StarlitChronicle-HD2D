#!/usr/bin/env python3
"""Deprecated V10 command shim. Use python tools/generate_art.py instead.

Retained temporarily so existing local invocations do not break.
No generation implementation is maintained here.
"""
from __future__ import annotations

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "tools"))
from art_pipeline import main

if __name__ == "__main__":
    raise SystemExit(main())
