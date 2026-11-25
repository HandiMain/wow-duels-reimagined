"""Appearance palette preservation and shared live Options font contracts.

The approved first atlas cell has damaged lettering AND truncated palette art.
Appearance uses a separate complete palette TGA; all cards use live labels.
Live WoW screenshots are still required to certify pixel alignment.
"""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
SOURCE = (BASE / "UI" / "Options.lua").read_text(encoding="utf-8")


class AppearanceHeaderRepairTests(unittest.TestCase):
    def test_appearance_palette_retained_and_all_text_uses_shared_font(self):
        self.assertIn('local isAppearance = key == "appearance"', SOURCE)
        self.assertIn('palette:SetTexture(COMPLETE_PALETTE)', SOURCE)
        self.assertIn('motifPalette:SetTexture(COMPLETE_PALETTE)', SOURCE)
        self.assertIn('palette:SetPoint("CENTER", header, "LEFT", 50, 0)', SOURCE)
        self.assertIn('motifPalette:SetPoint("CENTER", header, "RIGHT", -69, 0)', SOURCE)
        self.assertIn('card.appearancePalette, card.appearanceMotifPalette = palette, motifPalette', SOURCE)
        self.assertIn('local name = Style.Text(header, title, 20, C.pale)', SOURCE)
        self.assertIn('local sub = Style.Text(header, bannerSubtitles[key], 10, C.muted)', SOURCE)
        self.assertNotIn(':SetFont(', SOURCE)
        self.assertNotIn(':CreateFontString(', SOURCE)

    def test_visual_height_and_responsive_fit_are_safe(self):
        self.assertTrue((BASE / "Media" / "Skin" / "DuelPaletteMarks.tga").is_file())
        self.assertIn('name:SetPoint("TOPLEFT",header,"TOPLEFT",88,-10)', SOURCE)
        self.assertIn('sub:SetPoint("TOPLEFT",header,"TOPLEFT",88,-42)', SOURCE)
        self.assertIn('name:SetSize(room,30);sub:SetSize(room,19)', SOURCE)
        self.assertIn('Style.ConstrainText(name,room,30,9)', SOURCE)
        self.assertIn('Style.ConstrainText(sub,room,19,7)', SOURCE)
        self.assertIn('headingBand:SetClipsChildren(false)', SOURCE)
        self.assertIn('local BANNER_HEIGHT = 72', SOURCE)
        self.assertLess(42 + 19, 72)

    def test_complete_palette_image_is_wow_compatible(self):
        data = (BASE / "Media" / "Skin" / "DuelPaletteMarks.tga").read_bytes()
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
        self.assertEqual(SOURCE.count("Section("), 11)  # helper plus ten cards
        self.assertIn('Section(resultCard,"result","Duel Result",', SOURCE)
        self.assertIn("function appearance:Relayout(width)", SOURCE)
        self.assertIn("function interface:Relayout(width)", SOURCE)
        self.assertIn('ns.Search.Register("setting:" .. key', SOURCE)
        self.assertNotIn('SetScript("OnUpdate"', SOURCE)


if __name__ == "__main__":
    unittest.main()
