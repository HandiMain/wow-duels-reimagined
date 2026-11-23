"""Protect the approved Option 5 header branding and landing-page logo."""
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"
ART = ADDON / "Media" / "Artwork" / "Landing" / "LandingWordmark.png"

class OptionFiveBrandingTests(unittest.TestCase):
    def test_artwork_wordmark_png_with_alpha(self):
        data = ART.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", data[16:24]), (544, 74))
        # RGBA wordmark (PNG color type 6) has real transparent pixels.
        # The main-window DuelBrand asset remains separately protected.
        self.assertEqual(data[25], 6)

    def test_retired_branding_files_not_shipped(self):
        # Git history remains the rollback source; the addon package should
        # contain only artwork actually displayed by the current UI.
        for obsolete in (
            "Media/Brand/DuelsLandingEmblem.png",
            "Media/Icons/DuelsCrestIcon.png",
        ):
            with self.subTest(asset=obsolete):
                self.assertFalse((ADDON / obsolete).exists())

    def test_native_landing_brand_and_exact_main_header_are_separate(self):
        window = (ADDON / "UI" / "Window.lua").read_text()
        landing = (ADDON / "UI" / "BlizzardSettings.lua").read_text()
        self.assertIn("DuelBrand.png", window)
        self.assertNotIn("Option5HeaderLogo.png", window)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", window)
        self.assertIn("LandingWordmark.png", landing)
        self.assertNotIn("DuelsLandingEmblem.png", landing)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", landing)
        self.assertIn("local visualWidth = math.min(330, available)", window)
        self.assertIn("Drag(brandDrag)", window)
        self.assertNotIn("BrandLayer(", window)
        self.assertIn("exactBrand:SetTexCoord(0, 384/512, 25/128, 93/128)", window)
        self.assertNotIn("BrandLayer(C.gold,       0.50, 0.75, 3)", window)
        self.assertNotIn('local underline = CreateFrame(', window)
        self.assertIn('SourceImage("LandingCrest.png"', landing)
        self.assertIn('SourceImage("LandingRule.png"', landing)
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
