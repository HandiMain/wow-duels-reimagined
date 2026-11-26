"""Regression contracts for the approved four-icon navigation artwork."""
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def source(path):
    return (ROOT / path).read_text(encoding="utf-8")

class NavigationIconAtlasTests(unittest.TestCase):
    def test_atlas_is_power_of_two_transparent_png(self):
        path = ROOT / "Media" / "Icons" / "DuelsNavigationAtlas.png"
        data = path.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", data[16:24]), (128, 128))
        # Indexed-color PNG with explicit alpha; one texture shared by 4 glyphs.
        self.assertEqual(data[25], 3)
        self.assertIn(b"tRNS", data)
        self.assertIn(b"IDAT", data)
        self.assertLess(len(data), 20000)

    def test_four_fixed_uvs_and_one_media_owner(self):
        chrome = source("UI/Chrome.lua")
        nav = source("UI/Navigation.lua")
        self.assertIn("local NAV_ICON_ATLAS =", chrome)
        for name, coords in (
            ("Hall", "{ 0,   0.5, 0,   0.5 }"),
            ("Community", "{ 0.5, 1, 19/128, 0.5 }"),
            ("PatchNotes", "{ 0,   0.5, 0.5, 1 }"),
            ("Options", "{ 0.5, 1,   0.5, 1 }"),
        ):
            self.assertIn(name + " " * (11 - len(name)) + "= " + coords, chrome)
        self.assertIn("tex:SetTexCoord(unpack(uv))", chrome)
        self.assertIn("tex:SetVertexColor(1, 1, 1, 1)", chrome)
        self.assertIn('local icon = Chrome.Icon(button, section.icon)', nav)
        self.assertNotIn("Style.TintedImage(icon", nav)
        self.assertNotIn("local parchment = Style.Fill(icon", nav)

    def test_fixed_atlas_icons_fit_new_hall_and_footer_buttons(self):
        nav = source("UI/Navigation.lua")
        for token in (
            "button:SetSize(HALL_BUTTON_WIDTH, HALL_BUTTON_HEIGHT)",
            "local HALL_BUTTON_WIDTH, HALL_BUTTON_HEIGHT = 166, 68",
            "button:SetSize(112, 30)",
            "icon:SetSize(isPrimary and 48 or 20",
            'icon:SetPoint("TOP", button, "TOP", 0, -4)',
            'label:SetPoint("BOTTOM", button, "BOTTOM", 0, 6)',
            'Style.ConstrainButtonLabel(button, label, 34, 6, 9)',
            "local function FitTabs(self, width)",
            "FitSubTabs = function(self, width)",
            "FadeSelection(item, on)",
            'patchPulse:SetLooping("BOUNCE")',
            'button:SetScript("OnClick", function() Select(index, 1) end)',
            "ns.Widgets.PressFeedback(button, hover, {",
            'ns.Search.Register("page:" .. section.key',
        ):
            self.assertIn(token, nav)


if __name__ == "__main__":
    unittest.main()
