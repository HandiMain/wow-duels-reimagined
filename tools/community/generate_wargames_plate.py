#!/usr/bin/env python3
"""Derive War Games' plaque from the approved Hall art, pixel-for-pixel.

The 256x128 Hall sprite occupies the upper-left quadrant of DuelAtlas.png.
Only its baked center artwork is replaced with interpolated background;
the copper frame and laurel artwork stay bit-for-bit unchanged.

The finished plaque bakes original Hall swords and a gold-serif WAR GAMES
raster into one sprite. No live font or icon is needed in Navigation.
"""
from __future__ import annotations

import argparse
import base64
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "addon/DuelsReimagined/Media/Skin/DuelAtlas.png"
DEST = ROOT / "addon/DuelsReimagined/Media/Skin/DuelWarGamesPlate.png"
SIGNATURE = b"\x89PNG\r\n\x1a\n"
# Locally rendered original title raster, 132x30 in 4-bit alpha. No fonts
# ship with this addon; this deterministic mask cannot change with WoW fonts.
TITLE_W, TITLE_H = 132, 30
TITLE_MASK_B64 = "eNp1lc+LG2UYx5+ZTHazyUaCB0Gl2S2Cl1azIB60QoJXlQQPRVBIqJDr5A+QZit4KjaLVw+7f4A6e6nVprBL6aG3RFQsWHzZrV4K7tD8TmYyj9/nfWe2bqEDCe+83/f9vM+v95nr3Vv0bfcm0QfdH2ntFhFd6na7PxUoed5Vf+iXWNsisro/YwuemyL/xRzZzAuiXV5SMcRcm/H8mgBWfObfZbBhtB1MMZ+XNRzo8df8wPpB1nzoP6ByhOPe4/COv0yMaPNtxQ0MyjJ1iftEOX5c8PihYt6kOt9eATXLLdim38VIv08XeNsAHP6HXuEhRi50In9EVORDbKm9eJUblj+jFF5XeQ9rl0QdrhHZIFj+kSGsy/m9KcWa7MA5+0Igx99Ps1nriG2riIUnR9v+LxiNDaEu3pfl5UAb6i9llSFQ+0hb3xthfkCUxUE9MUZsoM7MEHoTcUVcUqJZPm/hFxPO7ayL27tTTaG8kMQYTXDnGpDi2BvMwl1ZsZ3mhGBRXoLjivWglI4ptVTHZwmrWGweaEea0M+eEnAsV+BkaCjVQ0oHu6OY0DaEnPhp6mLhDYWghi8s/VPCurhWjJBFxKe9Q5mZO0kiOSVzRi0mZGbtiRBuTKszQ7C+RPB4IsdUUDab5DUQzOo8yeZI7ytJpIw1kyqCa6lPA+8344WDzYhJizL4eaCoCq2PNgIh/F24ICGVPOoy0tYMRbPUZeZvnhKQvQCYPWSqZaOgi4GHf0T9X479r0ZCeO2tTSotvKUQPmZ+XxP+vCOEN5mRsD6u1p4TyolS6iAwh+ZeVMWGFPMxRqJZqtGLUprAEgJKKcbkwGHur86l9BmR04S79JQAeai1ihDaC+d/BNwglOt4NVCDLN4796/Dett/yPcoIUgk3ahGu1oDoTw2hK8+0QS6KgWcnXijPLLtbTsIiu3fl/KLIynZLEY4pyUBAyH/xHhRcQwhhcuzyA870w1UnKrJTbX9ezyICUUd0RLiazQQ0i1DqKXGSRcqLUtP6vOqbN2Sm4qKUtMkh9KThGCz1kCQyJqaTEqF8pHbL4edHXJwVG8oFdUJYy2r/QEh1s4QTp8c9/aKUa9BK9jnTYRQTvQV7Q8IWhs/h5BB+eQYQc8sdF+AF+tJKG2eGsLaXGtnCVbtZemgUtuVDMPKHFbXAyGkOYnSQWgIornBM4S1UX1gzokKacbK/Fg6sr6bKunVdVkJwjlo1eUzhPLENa1MhaDAytJA0rcpvdqVe28aAHrORlTQmk5qQqigogf684AIYbdCebiP0Pq44fAjbJwX4jYXblm7c629wY2U3xK379KrfOVtjw9zOtskreNgiIieNCzFsypHW7aftDeXg+95f41PatCmVbG1zdF5xRGzv22r4DspfhR050guy7bFPHflCn0UNwj91Zsj47j/Wgvl+xh/9ZC/i7jdRBevEX3WILvZ3KTLzSsvNZtoEs1KnI131GO4fKp9TvR6s4mxPJC/OPkPUdHp4w=="



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
            # Above the motif use the actual row colour. Below it, the
            # original edges include sword shadows and the word HALL;
            # extend the clean red from row 64 as a smooth vertical fade.
            source_y = min(y, 64)
            reference = rows[source_y]
            fade = 1.0 if y <= 64 else max(0.42, 1 - (y - 64) * 0.012)
            for channel in range(3):
                l = sum(reference[(left - n) * 4 + channel] for n in range(1, 5)) / 4
                r = sum(reference[(right + n) * 4 + channel] for n in range(1, 5)) / 4
                clean = (l * (1 - horizontal) + r * horizontal) * fade
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


def bake_logo(rows, original):
    # Native metallic Hall swords, fully visible. Fade only the boundary
    # of their central crop; keep the approved copper rim and laurels.
    for y in range(15, 78):
        for x in range(95, 165):
            opacity = min(1., max(0.,
                          (min(x-95, 164-x, y-15, 77-y)+.5)/5))
            for k in range(3):
                i=x*4+k
                rows[y][i]=round(rows[y][i]*(1-opacity) +
                                 original[y][i]*opacity)


def bake_title(rows):
    packed=zlib.decompress(base64.b64decode(TITLE_MASK_B64))
    if len(packed)!=TITLE_W*TITLE_H//2:
        raise AssertionError("Invalid baked title raster")
    alpha=[]
    for b in packed:
        alpha.append((b>>4)*17)
        alpha.append((b&15)*17)
    x0,y0=(256-TITLE_W)//2,80
    mask=[[0]*256 for _ in range(128)]
    for y in range(TITLE_H):
        for x in range(TITLE_W):
            mask[y0+y][x0+x]=alpha[y*TITLE_W+x]
    for y in range(y0-2,y0+TITLE_H+2):
        for x in range(x0-2,x0+TITLE_W+2):
            v=mask[y][x]/255.
            halo=max(mask[yy][xx] for yy in range(max(y0,y-2),min(y0+TITLE_H,y+3))
                     for xx in range(max(x0,x-2),min(x0+TITLE_W,x+3)))/255.
            if not halo: continue
            i=x*4
            shadow=max(0.,halo-v)*.90
            for k in range(3):
                rows[y][i+k]=round(rows[y][i+k]*(1-shadow))
            if v:
                color=(252,246,202) if y<90 else (
                    (250,212,102) if y<100 else (200,119,26))
                for k in range(3):
                    rows[y][i+k]=round(rows[y][i+k]*(1-v)+color[k]*v)


def derive() -> bytes:
    original = read_rgba(SOURCE.read_bytes())
    edited = blank_center([line[:] for line in original])
    bake_logo(edited, original)
    bake_title(edited)
    # Outside the central motif, Hall artwork must remain exact.
    for y, (before, after) in enumerate(zip(original, edited)):
        if y < 14 or y > 114:
            if before != after:
                raise AssertionError("Approved Hall outer rim changed")
        for x in list(range(48))+list(range(208,256)):
            if before[x*4:x*4+4] != after[x*4:x*4+4]:
                raise AssertionError("Approved Hall laurels changed")
        if before[3::4] != after[3::4]:
            raise AssertionError("Hall alpha must remain unchanged")
    return encode_rgba(edited)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Verify the committed plate is current")
    args = parser.parse_args()
    content = derive()
    if args.check:
        if not DEST.is_file() or DEST.read_bytes() != content:
            raise SystemExit("War Games plate not derived from current Hall art")
        print("War Games finished plaque matches approved Hall art: PASS")
    else:
        DEST.write_bytes(content)
        print(f"Generated {DEST.relative_to(ROOT)} ({len(content)} bytes)")
