#!/usr/bin/env python3
"""Shared immutable hashing contract for art candidates and runtime identities."""
from __future__ import annotations
import hashlib
from pathlib import Path

def stable_seed(*parts: object) -> int:
    """Original 64-bit seed, compatible with V6, V8 and Global Factory V3."""
    return int.from_bytes(hashlib.sha256("|".join(map(str, parts)).encode()).digest()[:8], "big")

def sha256_file(path: str | Path) -> str:
    """Stream file hash without changing the historical SHA-256 digest."""
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()
