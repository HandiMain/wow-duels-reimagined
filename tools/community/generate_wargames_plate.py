#!/usr/bin/env python3
"""Derive War Games' plaque from the approved Hall art, pixel-for-pixel.

The 256x128 Hall sprite occupies the upper-left quadrant of DuelAtlas.png.
Only its baked center artwork is replaced with interpolated background;
the copper frame and laurel artwork stay bit-for-bit unchanged.

The game's existing navigation draws a distinct live emblem and label on top.
This keeps all navigation behavior, theme, scale and motion in one UI owner.
"""
from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "addon/DuelsReimagined/Media/Skin/DuelAtlas.png"
DEST = ROOT / "addon/DuelsReimagined/Media/Skin/DuelWarGamesPlate.png"
SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _iter_chunks(data: bytes):
    if not data.startswith(SIGNATURE):
        raise ValueError("Hall source is not PNG")
    pos = 8
    while pos + 12 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        value = data[pos + 8:pos + 8 + length]
        stored = struct.unpack(">I", data[pos + 8 + length:pos + 12 + length])[0]
        if zlib.crc32(kind + value) != stored:
            raise ValueError("Hall artwork PNG checksum failed")
        yield kind, value
        pos += 12 + length
        if kind == b"IEND":
            return
    raise ValueError("Incomplete Hall artwork PNG")


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def read_rgba(data: bytes):
    chunks = list(_iter_chunks(data))
    ihdr = next(value for kind, value in chunks if kind == b"IHDR")
    width, height, depth, kind, compression, filtering, interlace = struct.unpack(">IIBBBBB", ihdr)
    if (width, height, depth, kind, compression, filtering, interlace) != (512, 256, 8, 6, 0, 0, 0):
        raise ValueError("Hall atlas format changed; review before regenerating")
    decoded = zlib.decompress(b"".join(value for name, value in chunks if name == b"IDAT"))
    stride = width * 4
    if len(decoded) != height * (stride + 1):
        raise ValueError("Hall atlas row size changed")
    image = []
    index = 0
    previous = bytearray(stride)
    for _ in range(height):
        filter_type = decoded[index]
        index += 1
        current = bytearray(decoded[index:index + stride])
        index += stride
        if filter_type not in range(5):
            raise ValueError("Unsupported PNG row filter")
        if filter_type:
            for x in range(stride):
                left = current[x - 4] if x >= 4 else 0
                up = previous[x]
                upper_left = previous[x - 4] if x >= 4 else 0
                if filter_type == 1:
                    predict = left
                elif filter_type == 2:
                    predict = up
                elif filter_type == 3:
                    predict = (left + up) // 2
                else:
                    predict = _paeth(left, up, upper_left)
                current[x] = (current[x] + predict) & 255
        image.append(current)
        previous = current
    return [bytearray(row[:256 * 4]) for row in image[:128]]


def blank_center(rows: list[bytearray]):
    # Two deliberately bounded zones: crossed swords and the 'HALL' legend.
    # Laurel branches occupy the outer sides and are never repainted.
    for y in range(14, 114):
        if y <= 73:
            left, right = 100, 162
        elif y <= 81:
            t = (y - 73) / 8
            left = round(100 - 15 * t)
            right = round(162 + 12 * t)
        else:
            left, right = 85, 174
        source = rows[y][:]
        for x in range(left, right + 1):
            edge = min(x - left, right - x, y - 14, 113 - y)
            opacity = min(1.0, max(0.0, (edge + 0.5) / 4))
            horizontal = (x - left) / (right - left)
            for channel in range(3):
                l = sum(source[(left - n) * 4 + channel] for n in range(1, 5)) / 4
                r = sum(source[(right + n) * 4 + channel] for n in range(1, 5)) / 4
                clean = l * (1 - horizontal) + r * horizontal
                at = x * 4 + channel
                rows[y][at] = round(source[at] * (1 - opacity) + clean * opacity)
    return rows


def chunk(kind: bytes, value: bytes) -> bytes:
    return struct.pack(">I", len(value)) + kind + value + struct.pack(
        ">I", zlib.crc32(kind + value))


def encode_rgba(rows: list[bytearray]) -> bytes:
    ihdr = struct.pack(">IIBBBBB", 256, 128, 8, 6, 0, 0, 0)
    # Sub filter preserves the fine copper/bronze rim while compressing well.
    data = bytearray()
    for row in rows:
        data.append(1)
        for x, value in enumerate(row):
            data.append((value - (row[x - 4] if x >= 4 else 0)) & 255)
    return SIGNATURE + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(data, 9)) + chunk(b"IEND", b"")


def derive() -> bytes:
    original = read_rgba(SOURCE.read_bytes())
    edited = blank_center([line[:] for line in original])
    # Prove nothing outside the actual logo/lettering was painted.
    for y, (before, after) in enumerate(zip(original, edited)):
        if not 14 <= y <= 113 and before != after:
            raise AssertionError("Generated frame differs from approved Hall artwork")
        if before[3::4] != after[3::4]:
            raise AssertionError("Hall alpha channel must remain pixel-perfect")
    return encode_rgba(edited)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Verify the committed plate is current")
    args = parser.parse_args()
    content = derive()
    if args.check:
        if not DEST.is_file() or DEST.read_bytes() != content:
            raise SystemExit("War Games plate not derived from current Hall art")
        print("War Games plate matches approved Hall art: PASS")
    else:
        DEST.write_bytes(content)
        print(f"Generated {DEST.relative_to(ROOT)} ({len(content)} bytes)")
