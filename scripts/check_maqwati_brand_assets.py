#!/usr/bin/env python3
"""Verify Maqwati branding assets against the owner's approved originals.

Modes:
 preview: check assets are present and non-empty, report if tiny thumbnails.
 release: BLOCK production unless both full-resolution originals exactly match
          the uploaded owner's archive by SHA-256.

This script has no network, package dependencies or write side effects.
"""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "assets/images/maqwati_login_background.jpg": {
        "sha256": "5164ee3d142c7b62bdab6312faf290ceff75852ec8f6260cba82fe434084c748",
        "minimum_bytes": 50_000,
        "resolution": "864x1536",
    },
    "assets/images/maqwati_horizontal_logo.jpg": {
        "sha256": "2765b0d88d3f352f589dac789f1c8dd847293dbfed08fcda9eb665140bf5c12b",
        "minimum_bytes": 50_000,
        "resolution": "1536x512",
    },
}

def verify(mode: str) -> int:
    failures: list[str] = []
    for relative, spec in ASSETS.items():
        path = ROOT / relative
        if not path.is_file():
            failures.append(f"MISSING {relative}")
            continue
        content = path.read_bytes()
        digest = hashlib.sha256(content).hexdigest()
        exact = digest == spec["sha256"]
        if len(content) < 1000:
            failures.append(f"EMPTY/INVALID {relative} ({len(content)} B)")
            continue
        if not content.startswith(bytes.fromhex("ffd8ff")):
            failures.append(f"NOT JPEG {relative}")
            continue
        label = "ORIGINAL" if exact else "PREVIEW ONLY"
        print(f"{label}: {relative} size={len(content)} sha256={digest}")
        if mode == "release" and (
            not exact or len(content) < int(spec["minimum_bytes"])
        ):
            failures.append(
                f"RELEASE BLOCKED {relative}: expected owner-approved "
                f"{spec['resolution']} original SHA-256 {spec['sha256']}"
            )
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}")
        return 1
    print(f"PASS: {mode} branding asset check")
    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["preview", "release"], required=True)
    args = parser.parse_args()
    raise SystemExit(verify(args.mode))
