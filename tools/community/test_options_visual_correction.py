"""Approved card, icon, corner and shell correction contracts (not live WoW proof)."""
from pathlib import Path
import hashlib
import struct
import unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def source(p):return (ROOT/p).read_text(encoding="utf-8")
class OptionsVisualCorrectionTests(unittest.TestCase):
    def test_banner_inlays_keep_chrome_on_the_card_frame(self):
        b=(ROOT/"Media/Skin/DuelOptionsBannerInlays.png").read_bytes()
        self.assertEqual(b[:8],bytes([137,80,78,71,13,10,26,10]))
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(2048,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "00d03d532fb195d62cd6944e081dd87aac24122d3421e0ba3d872be980863e8b")
        o=source("UI/Options.lua")
        for s in ("BANNER_ATLAS_W, BANNER_ATLAS_H = 2048, 256",
                  "BANNER_CELL_W, BANNER_CELL_H = 640, 80",
                  "BANNER_LEFT, BANNER_RIGHT = 438, 160",
                  'headingBand:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -6)',
                  'headingBand:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -6)',
                  "function interface:Relayout(width)",
                  "function appearance:Relayout(width)"):
            self.assertIn(s,o)
    def test_legible_gold_symbols_preserve_native_tab_interaction(self):
        b=(ROOT/"Media/Skin/DuelMinimalGoldTabs.tga").read_bytes()
        self.assertEqual(struct.unpack_from("<HH",b,12),(128,64))
        self.assertEqual((b[2],b[16],b[17]),(2,32,0x28))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "6a15481f315ab81a7b20f7b5a594080dc93db4bf057ff3708761ad102e8879dd")
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
        b=(ROOT/"Media/Skin/DuelArchitecturalResizeL.png").read_bytes()
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(128,128,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "5588f4b969689382b228963991a2d91000c456556784346efe234fbc5e7cf6b4")
        w=source("UI/Window.lua")
        for s in ("resizeArt:SetSize(64, 64)","grip:SetSize(38, 38)",
                  'frame:StartSizing("BOTTOMRIGHT")',"Window.CommitResize()",
                  "Window.ResetSize()","resizeArt:SetShown(on and true or false)"):
            self.assertIn(s,w)
        self.assertNotIn("gripGlyph",w)
    def test_superseded_media_not_shipped(self):
        for name in ("DuelOptionsExactBanners.png","DuelCategoryIcons.tga",
                     "DuelForgedResizeCorner.png","DuelOptionsCompleteBanners.png",
                     "DuelPremiumCategoryIcons.tga","DuelSculptedCopperCorner.png"):
            self.assertFalse((ROOT/"Media/Skin"/name).exists())
if __name__ == "__main__":
    unittest.main()
