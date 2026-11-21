"""Validate the literal, component-scoped extraction from the approved concept.

No full screenshot is shipped, and only the fixed Hall emblem/lettering is
baked into a texture. Interactive controls are still live WoW frames.
"""
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
ATLAS = ROOT / "Media" / "Skin" / "DuelExactAtlas.png"

def lua(path):
    return (ROOT / path).read_text(encoding="utf-8")

class ConceptExtractionTests(unittest.TestCase):
    def test_extracted_atlas_is_a_small_power_of_two_png(self):
        data = ATLAS.read_bytes()
        self.assertTrue(data.startswith(bytes([137,80,78,71,13,10,26,10])))
        w, h, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
        self.assertEqual((w, h), (512, 256))
        self.assertEqual(bit_depth, 8)
        self.assertEqual(color_type, 6)  # full RGBA, no palette banding
        self.assertGreater(len(data), 45000)  # no destructive 32/128-color quantization
        self.assertLess(len(data), 400000)
        self.assertNotIn(b"consept(2).webp", data)

    def test_transparent_brand_art_is_cropped_and_keeps_drag_owner(self):
        brand = ROOT / "Media" / "Skin" / "DuelExactBrand.png"
        data = brand.read_bytes()
        self.assertTrue(data.startswith(bytes([137,80,78,71,13,10,26,10])))
        w, h = struct.unpack(">II", data[16:24])
        self.assertEqual((w, h), (512, 128))
        self.assertGreater(len(data), 18000)  # original high-resolution identity
        self.assertLess(len(data), 150000)
        window = lua("UI/Window.lua")
        self.assertIn("DuelExactBrand.png", window)
        self.assertIn("exactBrand:SetTexCoord(0, 384/512, 25/128, 93/128)", window)
        self.assertIn("exactBrand:SetSize(visualWidth, visualWidth * 68 / 384)", window)
        self.assertIn("Drag(brandDrag)", window)
        self.assertIn("function Window.PlaceBrandBefore(searchBox)", window)

    def test_atlas_contains_independent_pieces_not_full_ui(self):
        style = lua("UI/Style.lua")
        for key in (
            'local CONCEPT_ATLAS = PLATE_ROOT .. "DuelExactAtlas.png"',
            'hall = { 0, 0.5, 0, 0.5 }',
            'corner = { 0.5, 0.625, 0.75, 1 }',
            'gold = { path=CONCEPT_ATLAS',
            'dark = { path=CONCEPT_ATLAS',
            'cardBody = { path=CONCEPT_ATLAS',
            'cardHeading = { path=CONCEPT_ATLAS',
            'function Style.ConceptImage(parent, region, layer, sublevel)',
            'function Style.Plate(parent, kind, opts)',
            'function group:SetStyle(newKind)',
        ):
            self.assertIn(key, style)
        self.assertIn('local aw, ah = spec.atlasW or spec.w', style)

    def test_hall_texture_has_own_interactive_button(self):
        nav = lua("UI/Navigation.lua")
        for key in (
            'if section.key == "hall" then',
            'Style.ConceptImage(button, "hall", "ARTWORK", 2)',
            'icon:Hide()',
            'label:Hide()',
            'button:SetScript("OnClick", function() Select(index, 1) end)',
            'ns.Search.Register("page:" .. section.key',
        ):
            self.assertIn(key, nav)
        self.assertNotIn('DuelHallLaurel.tga', nav)

    def test_dynamic_settings_card_and_other_buttons_not_baked(self):
        options = lua("UI/Options.lua")
        nav = lua("UI/Navigation.lua")
        chrome = lua("UI/Chrome.lua")
        self.assertIn('Style.Plate(card, "cardBody", { corner=15 })', options)
        self.assertIn('Style.Plate(headingBand, "cardHeading"', options)
        self.assertIn('item.plate:SetStyle(active and "gold" or "dark")', nav)
        self.assertIn('Style.Text(sub, page.label, 16, C.text, nil, "display")', nav)
        self.assertIn('Style.Plate(rim, "shellCopper"', chrome)
        self.assertIn('function Header.Fold(', lua("UI/Header.lua"))
        self.assertIn('function Options.Refresh()', options)

if __name__ == "__main__":
    unittest.main()
