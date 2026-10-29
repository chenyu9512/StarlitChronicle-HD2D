#!/usr/bin/env python3
"""One canonical art-generation CLI for Starlit Chronicle.

The retired 44x28 demo generator has been removed. This entry point retains
the existing CI command and forwards all supported options to the current
data-driven Global Art Factory. No alternate generator or save schema exists.
"""
from global_art_factory_v3 import main

if __name__ == "__main__":
    raise SystemExit(main())
