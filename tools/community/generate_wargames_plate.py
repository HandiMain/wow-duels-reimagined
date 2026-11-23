#!/usr/bin/env python3
"""Reproduce the owner-approved Coliseum War Games button plate.

The master 256x128 RGBA image is the approved 2026-11-23 War Games
coliseum artwork. Unlike the old shield, the coliseum and complete gold
lettering are already baked into the master (with a safe text inset).
The runtime image must match exactly; Hall artwork stays untouched.
No external imaging libraries are needed for this reproducible copy.
"""
from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/community/artwork/WarGamesColiseumPlate.png"
DEST = ROOT / "addon/DuelsReimagined/Media/Skin/DuelWarGamesPlate.png"
APPROVED_SHA256 = "79c3d68a4040f5b8cb169ebd3d41b71826b1b8e136e630118bf079c15b1bb2c2"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def approved_content() -> bytes:
    if not SOURCE.is_file():
        raise SystemExit("Missing approved Coliseum master artwork")
    content = SOURCE.read_bytes()
    if not content.startswith(PNG_SIGNATURE) or len(content) < 32:
        raise SystemExit("Approved Coliseum master must be a PNG")
    if struct.unpack_from(">IIBB", content, 16) != (256, 128, 8, 6):
        raise SystemExit("Approved Coliseum master must be 256x128 RGBA")
    if hashlib.sha256(content).hexdigest() != APPROVED_SHA256:
        raise SystemExit("Approved Coliseum master differs from selected visual")
    return content


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="Verify the shipped plate matches approved artwork")
    args = parser.parse_args()
    content = approved_content()
    if args.check:
        if not DEST.is_file() or DEST.read_bytes() != content:
            raise SystemExit("War Games plate differs from approved Coliseum art")
        print("Coliseum War Games plaque matches approved artwork: PASS")
    else:
        DEST.write_bytes(content)
        print(f"Generated {DEST.relative_to(ROOT)} ({len(content)} bytes)")
