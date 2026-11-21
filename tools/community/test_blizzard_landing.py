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
    def test_landing_actions_share_fixed_brand_gold_with_original_wordmark(self):
        landing = read("UI/BlizzardSettings.lua")
        style = read("UI/Style.lua")
        self.assertIn("fill = LANDING_GOLD, edge = LANDING_PALE", landing)
        self.assertIn("text = LANDING_BG", landing)
        self.assertIn("LockedBrandBand(LANDING_GOLD, 0, 0.25)", landing)
        self.assertEqual(landing.count("    LANDING_BUTTONS)"), 2)
        self.assertIn("function Style.Action(parent, caption, variant, palette)", style)
        self.assertIn("if palette then", style)
        self.assertIn("Style.Skin(button, palette.fill, {", style)
        self.assertIn("edge=palette.edge, light=palette.light", style)
        self.assertIn("dark=palette.dark, shine=0.28", style)
        self.assertIn("hover = Style.FeedbackOverlay(button, {", style)
        self.assertIn("palette and palette.text or C.buttonText", style)
        # The default shared action stays theme-aware for all other pages.
        self.assertIn("Style.Skin(button, C.button, {", style)
        self.assertIn("fill=palette and palette.hover or C.gold", style)
        self.assertIn('ns.Motion.Fade(hover, 0.20, 0.16)', style)
        self.assertIn('ns.Widgets.PressFeedback(button, hover)', style)

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
        for token in ["Style.Skin(surface, LANDING_BG",
                      "Style.Text(layout,", "Style.Action(layout,", "ns.Theme.Refresh()",
                      "HeaderOption5TintAtlas.png", "ns.Tooltips.Bind(open",
                      "ns.Tooltips.Bind(community"]:
            self.assertIn(token, s)
        self.assertIn('LockedBrandBand(LANDING_GOLD, 0, 0.25)', s)
        self.assertIn('LockedBrandBand(LANDING_PALE, 0.25, 0.50)', s)
        self.assertIn('logo:SetSize(380, 380 / 4.65)', s)
        self.assertIn('Style.Skin(surface, LANDING_BG', s)
        self.assertIn('shine=0, shade=0', s)
        self.assertNotIn('DuelsLandingEmblem.png', s)
        self.assertNotIn('Style.TintedImage(logo', s)
        self.assertNotIn('C.body', s)
        self.assertNotIn('C.text', s)
        self.assertNotIn('C.muted', s)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", s)
        self.assertNotIn("Style.TintedImage(logo", s)
        self.assertEqual(s.count("outsideWindow = true"), 2)
        self.assertIn('pcall(eui.RegisterSkin, "DuelsReimagined"', theme)
        self.assertNotIn("RegisterSkin(", s)
        self.assertNotIn("S.Shell", s)
