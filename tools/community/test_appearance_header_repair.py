"""Appearance-only raster text repair; static WoW layout contracts.

The approved first atlas cell has damaged lettering. Keep its icon and right
motif, and replace ONLY the faulty title/subtitle with native, fixed-size text.
Live WoW screenshots are still required to certify pixel alignment.
"""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
SOURCE = (BASE / "UI" / "Options.lua").read_text(encoding="utf-8")


class AppearanceHeaderRepairTests(unittest.TestCase):
    def test_only_appearance_uses_native_text_repair(self):
        self.assertIn('local appearanceIconWidth = key == "appearance" and 104 or nil', SOURCE)
        self.assertIn("if appearanceIconWidth then", SOURCE)
        self.assertIn("left:SetTexCoord(spriteX / BANNER_ATLAS_W,", SOURCE)
        self.assertIn("(spriteX + appearanceIconWidth) / BANNER_ATLAS_W", SOURCE)
        self.assertIn("left:SetWidth(math.max(1, appearanceIconWidth * scale))", SOURCE)
        self.assertIn('local name = header:CreateFontString(nil, "ARTWORK", nil, 5)', SOURCE)
        self.assertIn('name:SetText(title)', SOURCE)
        self.assertIn('sub:SetText("FONT MATCHING & VISUAL IDENTITY")', SOURCE)
        self.assertIn('card.appearanceHeading, card.appearanceSubtitle = name, sub', SOURCE)
        self.assertEqual(SOURCE.count("header:CreateFontString(nil, \"ARTWORK\", nil, 5)"), 2)

    def test_visual_height_and_fallback_are_safe(self):
        self.assertLess(104, 112)  # The damaged raster title begins after its icon
        self.assertIn('name:SetPoint("TOPLEFT", header, "TOPLEFT", 96, -9)', SOURCE)
        self.assertIn('name:SetSize(290, 35)', SOURCE)
        self.assertIn('sub:SetPoint("TOPLEFT", header, "TOPLEFT", 96, -44)', SOURCE)
        self.assertIn('sub:SetSize(340, 16)', SOURCE)
        self.assertIn('if not name:SetFont("Fonts\\\\MORPHEUS.TTF", 26, "OUTLINE") then', SOURCE)
        self.assertIn('if not sub:SetFont("Fonts\\\\FRIZQT__.TTF", 10, "") then', SOURCE)
        self.assertIn('headingBand:SetClipsChildren(false)', SOURCE)
        self.assertIn('local BANNER_HEIGHT = 72', SOURCE)
        self.assertLess(44 + 16, 72)

    def test_other_banners_and_options_controls_unchanged(self):
        self.assertIn("local left = Slice(0, BANNER_LEFT)", SOURCE)
        self.assertIn(
            "local right = Slice(BANNER_CELL_W - BANNER_RIGHT, BANNER_CELL_W)",
            SOURCE)
        self.assertEqual(SOURCE.count("Section("), 7)  # helper plus six cards
        self.assertIn("function appearance:Relayout(width)", SOURCE)
        self.assertIn("function interface:Relayout(width)", SOURCE)
        self.assertIn('ns.Search.Register("setting:" .. key', SOURCE)
        self.assertNotIn('SetScript("OnUpdate"', SOURCE)


if __name__ == "__main__":
    unittest.main()
