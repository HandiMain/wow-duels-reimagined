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
            ("Community", "{ 0.5, 1,   0,   0.5 }"),
            ("PatchNotes", "{ 0,   0.5, 0.5, 1 }"),
            ("Options", "{ 0.5, 1,   0.5, 1 }"),
        ):
            self.assertIn(name + " " * (11 - len(name)) + "= " + coords, chrome)
        self.assertIn("tex:SetTexCoord(unpack(uv))", chrome)
        self.assertIn("tex:SetVertexColor(1, 1, 1, 1)", chrome)
        self.assertIn('local icon = Chrome.Icon(button, section.icon)', nav)
        self.assertNotIn("Style.TintedImage(icon", nav)
        self.assertNotIn("local parchment = Style.Fill(icon", nav)

    def test_text_and_icons_fit_buttons_without_replacing_behavior(self):
        nav = source("UI/Navigation.lua")
        self.assertIn("button:SetSize(216, 44)", nav)
        self.assertIn("button:SetSize(90, 90)", nav)
        self.assertIn("icon:SetSize(isPrimary and 34 or 50", nav)
        self.assertIn("isPrimary and 18 or 12, C.tabMuted", nav)
        self.assertIn('icon:SetPoint("RIGHT", button, "CENTER", -11, 0)', nav)
        self.assertIn('icon:SetPoint("TOP", button, "TOP", 0, -4)', nav)
        self.assertIn("label:SetWidth(88)", nav)
        self.assertIn("label:SetHeight(30)", nav)
        self.assertLessEqual(4 + 50 + 30, 90)
        self.assertIn("FadeSelection(item, on)", nav)
        self.assertIn('patchPulse:SetLooping("BOUNCE")', nav)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)', nav)
        self.assertIn('ns.Widgets.PressFeedback(button, hover)', nav)
        self.assertIn('ns.Search.Register("page:" .. section.key', nav)

if __name__ == "__main__":
    unittest.main()
