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

    def test_retired_branding_files_not_shipped(self):
        # Git history remains the rollback source; the addon package should
        # contain only artwork actually displayed by the current UI.
        for obsolete in (
            "Media/Brand/DuelsLandingEmblem.png",
            "Media/Icons/DuelsCrestIcon.png",
        ):
            with self.subTest(asset=obsolete):
                self.assertFalse((ADDON / obsolete).exists())

    def test_only_main_header_uses_option_five(self):
        window = (ADDON / "UI" / "Window.lua").read_text()
        landing = (ADDON / "UI" / "BlizzardSettings.lua").read_text()
        self.assertIn("HeaderOption5TintAtlas.png", window)
        self.assertNotIn("Option5HeaderLogo.png", window)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", window)
        self.assertIn("HeaderOption5TintAtlas.png", landing)
        self.assertNotIn("DuelsLandingEmblem.png", landing)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", landing)
        self.assertIn("local BRAND_ASPECT = 4.65", window)
        self.assertIn("BRAND_MAX_WIDTH, BRAND_MAX_HEIGHT = 250, 55", window)
        self.assertIn("BrandLayer(C.red,        0,    0.25)", window)
        self.assertIn("BrandLayer(C.headerText, 0.25, 0.50)", window)
        self.assertNotIn("BrandLayer(C.gold,       0.50, 0.75, 3)", window)
        self.assertNotIn('local underline = CreateFrame(', window)
        self.assertIn('LockedBrandBand(LANDING_GOLD, 0, 0.25)', landing)
        self.assertIn('LockedBrandBand(LANDING_PALE, 0.25, 0.50)', landing)
        self.assertIn('Style.Skin(surface, LANDING_BG', landing)
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
