"""Exact approved Options category graphics: six complete source-derived banners.

These static tests validate the native artwork and retained WoW control owners.
They do not claim an in-game screenshot has been visually verified.
"""
from pathlib import Path
import hashlib
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
ART = ROOT / "Media" / "Skin" / "DuelOptionsExactBanners.png"
OPTIONS = ROOT / "UI" / "Options.lua"

class ApprovedOptionsBannersTests(unittest.TestCase):
    def test_full_resolution_rgba_atlas_with_complete_native_png_chunks(self):
        data = ART.read_bytes()
        self.assertEqual(data[:8], bytes((137,80,78,71,13,10,26,10)))
        self.assertEqual(struct.unpack(">IIBB", data[16:26]), (1024,256,8,6))
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         "af61e7723e65efc34d16659076c8b8841e99a9d476b3f93fab5a36aa4278b399")
        p = 8
        seen = []
        while p < len(data):
            n = struct.unpack(">I",data[p:p+4])[0]
            tag = data[p+4:p+8]
            content = data[p+8:p+8+n]
            crc = struct.unpack(">I",data[p+8+n:p+12+n])[0]
            self.assertEqual(zlib.crc32(tag+content)&0xffffffff,crc)
            seen.append(tag)
            p += n+12
            if tag==b"IEND": break
        self.assertEqual(p,len(data))
        self.assertIn(b"IDAT",seen)

    def test_both_tabs_use_exact_graphics_without_reconstructed_icons_or_titles(self):
        src = OPTIONS.read_text(encoding="utf-8")
        self.assertIn("DuelOptionsExactBanners.png",src)
        self.assertNotIn("DuelOptionsCategoryArt.png",src)
        self.assertNotIn('Style.Plate(headingBand, "cardHeading"',src)
        self.assertNotIn('local heading = Style.Text(header, title',src)
        self.assertNotIn('local detail = Style.Text(header',src)
        self.assertEqual(src.count('Section('),7)
        for key in ("appearance","motion","access","minimap","typography","notifications"):
            self.assertIn("    "+key+" = ",src)
            self.assertIn('Section(',src)
        for name in ("Appearance","Window & Motion","Game Access",
                     "Minimap & Widget","Typography","Notifications & Help"):
            self.assertIn('"'+name+'"',src)
        for needle in (
            "local function Slice(fromX, toX)",
            "local left = Slice(0, BANNER_LEFT)",
            "local center = Slice(BANNER_LEFT, BANNER_CELL_W - BANNER_RIGHT)",
            "local right = Slice(BANNER_CELL_W - BANNER_RIGHT, BANNER_CELL_W)",
            'header:SetScript("OnSizeChanged", FitSlices)',
            "ns.Tooltips.Bind(header, {",
            "function appearance:Relayout(width)",
            "function interface:Relayout(width)",
            'ns.Search.Register("setting:" .. key',
            "widget.optionsY = sectionY + y",
            'if widget.LayoutForWidth then',
        ):
            self.assertIn(needle,src)

if __name__ == "__main__":
    unittest.main()
