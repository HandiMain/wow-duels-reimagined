#!/usr/bin/env python3
"""Verify the retired 2026-11-23 Coliseum War Games plaque master.

The current UI uses separate emblems and live labels on DRMenuPlates.
Do not restore the retired baked plate to the runtime addon.
"""
from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/community/artwork/WarGamesColiseumPlate.png"
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
                        help="Verify archived original artwork")
    parser.parse_args()
    approved_content()
    print("Archived Coliseum War Games artwork: PASS")
