"""Protect the approved Option 5 header branding and landing-page logo."""
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"
ART = ADDON / "Media" / "Skin" / "HeaderOption5TintAtlas.png"

class OptionFiveBrandingTests(unittest.TestCase):
    def test_power_of_two_png_with_alpha(self):
        data = ART.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", data[16:24]), (256, 256))
        # Palette PNG with tRNS transparency. The texture must not leave an
        # opaque rectangle over our customizable Duels header.
        self.assertIn(b"tRNS", data)

    def test_separate_approved_rgba_brand_art_is_power_of_two(self):
        for path, expected in (
            ("Media/Brand/DuelsLandingEmblem.png", (512, 256)),
            ("Media/Icons/DuelsCrestIcon.png", (128, 128)),
        ):
            with self.subTest(path=path):
                data = (ADDON / path).read_bytes()
                self.assertEqual(data[:8], b"\\x89PNG\\r\\n\\x1a\\n")
                w, h, depth, color_type = struct.unpack(">IIBB", data[16:26])
                self.assertEqual((w, h, depth, color_type), (*expected, 8, 6))
                self.assertTrue(w & (w - 1) == 0)
                self.assertTrue(h & (h - 1) == 0)
                self.assertIn(b"IDAT", data)

    def test_only_main_header_uses_option_five(self):
        window = (ADDON / "UI" / "Window.lua").read_text()
        landing = (ADDON / "UI" / "BlizzardSettings.lua").read_text()
        self.assertIn("HeaderOption5TintAtlas.png", window)
        self.assertNotIn("Option5HeaderLogo.png", window)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", window)
        self.assertNotIn("HeaderOption5TintAtlas.png", landing)
        self.assertIn("DuelsLandingEmblem.png", landing)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", landing)
        self.assertIn("local BRAND_ASPECT = 4.65", window)
        self.assertIn("BRAND_MAX_WIDTH, BRAND_MAX_HEIGHT = 312, 67", window)
        self.assertIn("BrandLayer(C.gold,       0,    0.25, -4)", window)
        self.assertIn("BrandLayer(C.headerText, 0.25, 0.50, -4)", window)
        self.assertNotIn("BrandLayer(C.gold,       0.50, 0.75, 3)", window)
        self.assertNotIn('local underline = CreateFrame(', window)
        self.assertNotIn('LogoBand(', landing)
        self.assertNotIn('Style.TintedImage(logo', landing)

    def test_existing_responsive_header_contracts_unchanged(self):
        window = (ADDON / "UI" / "Window.lua").read_text()
        header = (ADDON / "UI" / "Header.lua").read_text()
        for token in ('Window.PlaceBrandBefore(searchBox)', 'brandArea:SetPoint("RIGHT", searchBox',
                      'brandArea:SetScript("OnSizeChanged", FitBrand)'):
            self.assertIn(token, window)
        self.assertIn("Window.PlaceBrandBefore(searchBox)", header)
        self.assertIn("Window.RefreshTheme()", window)
        self.assertIn("function Window.Toggle()", window)

if __name__ == "__main__":
    unittest.main()
