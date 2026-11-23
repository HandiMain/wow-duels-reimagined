"""Approved card, icon, corner and shell correction contracts (not live WoW proof)."""
from pathlib import Path
import hashlib
import struct
import unittest
ROOT=Path(__file__).resolve().parents[2]/"addon"/"DuelsReimagined"
def source(p):return (ROOT/p).read_text(encoding="utf-8")
class OptionsVisualCorrectionTests(unittest.TestCase):
    def test_banner_inlays_keep_chrome_on_the_card_frame(self):
        b=(ROOT/"Media/Skin/DuelOptionsBanner.png").read_bytes()
        self.assertEqual(b[:8],bytes([137,80,78,71,13,10,26,10]))
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(2048,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "1981b7fc18b5c0e77a5079470524624e2f329fec8a7093e9237279ea5a4755c9")
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
        b=(ROOT/"Media/Skin/DuelTabIcons.tga").read_bytes()
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
        b=(ROOT/"Media/Skin/DuelResizeCopper.png").read_bytes()
        self.assertEqual(struct.unpack_from(">IIBB",b,16),(256,256,8,6))
        self.assertEqual(hashlib.sha256(b).hexdigest(),
            "e88b09be81d49eb4046bf9aa41936be2568a8ed5a329255c818c9a22bc939bcc")
        w=source("UI/Window.lua")
        for s in ("resizeArt:SetSize(96, 96)","grip:SetSize(54, 54)",
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
