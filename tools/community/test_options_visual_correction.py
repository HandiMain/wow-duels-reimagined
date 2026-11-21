"""Approved card, icon, corner and shell correction contracts (not live WoW proof)."""
from pathlib import Path
import hashlib
import struct
import unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def source(p):return (ROOT/p).read_text(encoding="utf-8")
class OptionsVisualCorrectionTests(unittest.TestCase):
    def test_full_banners_include_complete_header_pixels(self):
        b=(ROOT/"Media/Skin/DuelOptionsCompleteBanners.png").read_bytes()
        self.assertEqual(b[:8],bytes([137,80,78,71,13,10,26,10]))
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(2048,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "d8cee77ef60dff91156e6d3766887ce1e18c75bfad42039d4fe88a6a64b034c3")
        o=source("UI/Options.lua")
        for s in ("BANNER_ATLAS_W, BANNER_ATLAS_H = 2048, 256",
                  "BANNER_CELL_W, BANNER_CELL_H = 640, 80",
                  "BANNER_LEFT, BANNER_RIGHT = 438, 160",
                  'headingBand:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)',
                  'headingBand:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)',
                  "function interface:Relayout(width)",
                  "function appearance:Relayout(width)"):
            self.assertIn(s,o)
    def test_premium_medallions_preserve_native_tab_interaction(self):
        b=(ROOT/"Media/Skin/DuelPremiumCategoryIcons.tga").read_bytes()
        self.assertEqual(struct.unpack_from("<HH",b,12),(128,64))
        self.assertEqual((b[2],b[16],b[17]),(2,32,0x28))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "78c27a28dc257c07f47c92ea08967583a7dfc17c59188932a9fa54c637ac1769")
        n=source("UI/Navigation.lua")
        self.assertIn("glyph:SetSize(28, 28)",n)
        self.assertIn('sub:SetScript("OnClick", function() Select(index, pageIndex) end)',n)
        self.assertIn('item.plate:SetStyle(active and "gold" or "dark")',n)
    def test_background_does_not_occupy_external_border_pixels(self):
        w=source("UI/Window.lua")
        self.assertIn("    inset=5,",w)
        self.assertIn("if interior.SetClipsChildren then interior:SetClipsChildren(true) end",w)
        self.assertNotIn("frame:SetClipsChildren(true)",w)
        self.assertIn('Style.Plate(rim, "shellCopper"',source("UI/Chrome.lua"))
    def test_sculpted_corner_and_original_drag_reset_owner(self):
        b=(ROOT/"Media/Skin/DuelSculptedCopperCorner.png").read_bytes()
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(128,128,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "df6a7d8d7cadf66931d4c066518291a89e426fd35a1bc672d4667c295dc8fda2")
        w=source("UI/Window.lua")
        for s in ("resizeArt:SetSize(84, 84)","grip:SetSize(38, 38)",
                  'frame:StartSizing("BOTTOMRIGHT")',"Window.CommitResize()",
                  "Window.ResetSize()","resizeArt:SetShown(on and true or false)"):
            self.assertIn(s,w)
        self.assertNotIn("gripGlyph",w)
    def test_superseded_media_not_shipped(self):
        for name in ("DuelOptionsExactBanners.png","DuelCategoryIcons.tga",
                     "DuelForgedResizeCorner.png"):
            self.assertFalse((ROOT/"Media/Skin"/name).exists())
if __name__ == "__main__":
    unittest.main()
