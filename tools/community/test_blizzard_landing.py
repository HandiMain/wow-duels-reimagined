"""Static checks for the minimal Blizzard Settings launcher."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addon" / "DuelsReimagined"
def read(path):
    return (ADDON / path).read_text(encoding="utf-8")
class BlizzardLandingTests(unittest.TestCase):
    def test_load_order_and_version(self):
        toc = read("DuelsReimagined.toc")
        self.assertEqual(toc.count(r"UI\BlizzardSettings.lua"), 1)
        self.assertLess(toc.index(r"UI\AccessIcons.lua"), toc.index(r"UI\BlizzardSettings.lua"))
        self.assertIn("## Interface: 120105, 16001", toc)
    def test_two_buttons_and_navigation(self):
        s = read("UI/BlizzardSettings.lua")
        self.assertEqual(re.findall(r'Style.Action\(layout, "([^"]+)"', s),
                         ["Open Duels Reimagined", "View Community"])
        self.assertIn('OpenDuels("community", "community")', s)
        self.assertIn("ns.Navigation.SelectKey(section, page)", s)
        self.assertIn("ns.Window.Toggle()", s)
        self.assertNotIn("DuelsReimaginedDB", s)
        self.assertNotIn("v0.9.2", s)
    def test_native_api_and_safe_handoff(self):
        s = read("UI/BlizzardSettings.lua")
        for token in ["RegisterCanvasLayoutCategory", "RegisterAddOnCategory",
                      "InterfaceOptions_AddCategory", 'HideUIPanel(settings)',
                      "InCombat()", "Later(function()",
                      'event:RegisterEvent("PLAYER_LOGIN")']:
            self.assertIn(token, s)
        self.assertNotIn('SetScript("OnUpdate"', s)
    def test_ellesmere_integration_and_duels_identity(self):
        s = read("UI/BlizzardSettings.lua")
        theme = read("UI/Theme.lua")
        for token in ["Style.Skin(surface, C.body",
                      "Style.Text(layout,", "Style.Action(layout,", "ns.Theme.Refresh()",
                      "DuelsLandingEmblem.png", "ns.Tooltips.Bind(open",
                      "ns.Tooltips.Bind(community"]:
            self.assertIn(token, s)
        self.assertNotIn("LogoBand(", s)
        self.assertIn('logo:SetTexCoord(0, 1, 0.10, 0.90)', s)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", s)
        self.assertNotIn("Style.TintedImage(logo", s)
        self.assertEqual(s.count("outsideWindow = true"), 2)
        self.assertIn('pcall(eui.RegisterSkin, "DuelsReimagined"', theme)
        self.assertNotIn("RegisterSkin(", s)
        self.assertNotIn("S.Shell", s)
