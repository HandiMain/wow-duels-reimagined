"""Approved Options source graphics with live typography for all cards.

These static tests validate the native artwork and retained WoW control owners.
They do not claim an in-game screenshot has been visually verified.
"""
from pathlib import Path
import hashlib
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
ART = ROOT / "Media" / "Skin" / "DuelOptionsBanner.png"
OPTIONS = ROOT / "UI" / "Options.lua"

class ApprovedOptionsBannersTests(unittest.TestCase):
    def test_full_resolution_rgba_atlas_with_complete_native_png_chunks(self):
        data = ART.read_bytes()
        self.assertEqual(data[:8], bytes((137,80,78,71,13,10,26,10)))
        self.assertEqual(struct.unpack(">IIBB", data[16:26]), (2048,256,8,6))
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         "1981b7fc18b5c0e77a5079470524624e2f329fec8a7093e9237279ea5a4755c9")
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

    def test_original_atlas_kept_and_all_banner_text_live(self):
        src = OPTIONS.read_text(encoding="utf-8")
        self.assertIn("DuelOptionsBanner.png",src)
        self.assertNotIn("DuelBannerAmbient.png",src)
        self.assertNotIn("local center = Slice(",src)
        self.assertNotIn("DuelOptionsCategoryArt.png",src)
        self.assertNotIn('Style.Plate(headingBand, "cardHeading"',src)
        self.assertNotIn('local heading = Style.Text(header, title',src)
        self.assertNotIn('local detail = Style.Text(header',src)
        self.assertEqual(src.count('Section('),11)
        self.assertIn('Section(resultCard,"result","Duel Result",',src)
        self.assertIn('local isAppearance = key == "appearance"',src)
        self.assertIn('DuelPaletteMarks.tga',src)
        self.assertIn('motifPalette:SetTexture(COMPLETE_PALETTE)',src)
        self.assertIn('local name = Style.Text(header, title, 20, C.pale)',src)
        self.assertIn('local sub = Style.Text(header, bannerSubtitles[key], 10, C.muted)',src)
        self.assertIn('appearance="FONT MATCHING & VISUAL IDENTITY"',src)
        self.assertNotIn(':SetFont(',src)
        self.assertIn('local BANNER_LEFT, BANNER_RIGHT = 112, 160',src)
        for key in ("appearance","motion","access","minimap","typography","notifications","widget","widgetNotifications"):
            self.assertIn("    "+key+" = ",src)
            self.assertIn('Section(',src)
        for name in ("Appearance","Window & Motion","Game Access",
                     "Minimap & Launcher","Typography","Notifications & Help"):
            self.assertIn('"'+name+'"',src)
        for needle in (
            "local function Slice(fromX, toX)",
            "local left = Slice(0, BANNER_LEFT)",
            'left:SetPoint("LEFT", header, "LEFT", 0, 0)',
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
