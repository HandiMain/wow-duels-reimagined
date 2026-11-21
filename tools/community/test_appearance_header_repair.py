"""Appearance-only raster text repair; static WoW layout contracts.

The approved first atlas cell has damaged lettering AND truncated palette art.
Only Appearance uses a separate complete palette TGA and native header labels.
Live WoW screenshots are still required to certify pixel alignment.
"""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
SOURCE = (BASE / "UI" / "Options.lua").read_text(encoding="utf-8")


class AppearanceHeaderRepairTests(unittest.TestCase):
    def test_only_appearance_uses_native_text_repair(self):
        self.assertIn('local isAppearance = key == "appearance"', SOURCE)
        self.assertIn('left:Hide() -- remove the damaged left icon and baked lettering', SOURCE)
        self.assertIn('palette:SetTexture(COMPLETE_PALETTE)', SOURCE)
        self.assertIn('motifPalette:SetTexture(COMPLETE_PALETTE)', SOURCE)
        self.assertIn('palette:SetPoint("CENTER", header, "LEFT", 50, 0)', SOURCE)
        self.assertIn('motifPalette:SetPoint("CENTER", header, "RIGHT", -69, 0)', SOURCE)
        self.assertIn('card.appearancePalette, card.appearanceMotifPalette = palette, motifPalette', SOURCE)
        self.assertIn('local name = header:CreateFontString(nil, "ARTWORK", nil, 5)', SOURCE)
        self.assertIn('name:SetText(title)', SOURCE)
        self.assertIn('sub:SetText("FONT MATCHING & VISUAL IDENTITY")', SOURCE)
        self.assertIn('card.appearanceHeading, card.appearanceSubtitle = name, sub', SOURCE)
        self.assertEqual(SOURCE.count("header:CreateFontString(nil, \"ARTWORK\", nil, 5)"), 2)

    def test_visual_height_and_fallback_are_safe(self):
        self.assertTrue((BASE / "Media" / "Skin" / "DuelPaletteComplete.tga").is_file())
        self.assertIn('name:SetPoint("TOPLEFT", header, "TOPLEFT", 96, -9)', SOURCE)
        self.assertIn('name:SetSize(290, 35)', SOURCE)
        self.assertIn('sub:SetPoint("TOPLEFT", header, "TOPLEFT", 96, -44)', SOURCE)
        self.assertIn('sub:SetSize(340, 16)', SOURCE)
        self.assertIn('if not name:SetFont("Fonts\\\\MORPHEUS.TTF", 26, "OUTLINE") then', SOURCE)
        self.assertIn('if not sub:SetFont("Fonts\\\\FRIZQT__.TTF", 10, "") then', SOURCE)
        self.assertIn('headingBand:SetClipsChildren(false)', SOURCE)
        self.assertIn('local BANNER_HEIGHT = 72', SOURCE)
        self.assertLess(44 + 16, 72)

    def test_complete_palette_image_is_wow_compatible(self):
        data = (BASE / "Media" / "Skin" / "DuelPaletteComplete.tga").read_bytes()
        self.assertEqual(data[2], 2)  # uncompressed true-color TGA
        self.assertEqual(data[12:16], bytes((64, 0, 64, 0)))
        self.assertEqual(data[16:18], bytes((32, 0x28)))  # BGRA + top-left
        self.assertEqual(len(data), 18 + 64 * 64 * 4)
        alpha = data[21::4]
        self.assertGreater(sum(1 for p in alpha if p > 0), 750)
        self.assertLess(sum(1 for p in alpha if p == 255), 2500)
        self.assertGreater(len(set(alpha)), 3)

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
