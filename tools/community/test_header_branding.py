"""Protect the approved Option 5 header branding and landing-page logo."""
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"
ART = ADDON / "Media" / "Concept" / "Option5HeaderLogo.png"

class OptionFiveBrandingTests(unittest.TestCase):
    def test_power_of_two_png_with_alpha(self):
        data = ART.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", data[16:24]), (512, 128))
        # Palette PNG with tRNS transparency. The texture must not leave an
        # opaque rectangle over our customizable Duels header.
        self.assertIn(b"tRNS", data)

    def test_only_main_header_uses_option_five(self):
        window = (ADDON / "UI" / "Window.lua").read_text()
        landing = (ADDON / "UI" / "BlizzardSettings.lua").read_text()
        self.assertIn("Option5HeaderLogo.png", window)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", window)
        self.assertNotIn("Option5HeaderLogo.png", landing)
        self.assertIn("DuelsReimagined-HeaderLogoFlat.png", landing)
        self.assertIn("local BRAND_ASPECT = 420 / 102", window)
        self.assertIn("brandLogo:SetTexCoord(46 / 512, 466 / 512, 13 / 128, 115 / 128)", window)

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
