"""Approved Concept 04: source-derived art, native buttons, safe Blizzard handoff."""
from pathlib import Path
import re
import struct
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

    def test_two_native_buttons_and_navigation(self):
        s = read("UI/BlizzardSettings.lua")
        self.assertEqual(re.findall(r'PlatedButton\("([^"]+)"', s),
                         ["Open Duels Reimagined", "View Community"])
        self.assertIn('OpenDuels("community", "community")', s)
        self.assertIn("ns.Navigation.SelectKey(section, page)", s)
        self.assertIn("ns.Window.Toggle()", s)
        self.assertIn('Style.Action(layout, caption, "landing-art")', s)
        self.assertIn('button:RegisterForClicks("LeftButtonUp")', read("UI/Style.lua"))
        self.assertNotIn("DuelsReimaginedDB", s)
        self.assertNotIn("v0.9.2", s)

    def test_exact_concept_art_is_separate_from_input(self):
        s = read("UI/BlizzardSettings.lua")
        base = ADDON / "Media" / "Concept" / "Landing"
        art = [
            ("LandingBattlefield.jpg", "jpeg"),
            ("LandingCrest.png", "png"),
            ("LandingWordmark.png", "png"),
            ("LandingRule.png", "png"),
            ("LandingPrimary.png", "png"),
            ("LandingSecondary.png", "png"),
        ]
        for filename, fmt in art:
            with self.subTest(asset=filename):
                data = (base / filename).read_bytes()
                self.assertGreater(len(data), 3000)
                self.assertIn(filename, s)
                if fmt == "png":
                    self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"))
                    w, h = struct.unpack(">II", data[16:24])
                    self.assertGreater(w, 90)
                    self.assertGreater(h, 32)
                else:
                    self.assertTrue(data.startswith(b"\xff\xd8"))
        self.assertIn('media = "Interface\\\\AddOns\\\\DuelsReimagined\\\\Media\\\\Concept\\\\Landing\\\\"', s)
        self.assertIn("BASE_W, BASE_H = 547, 267", s)
        self.assertIn('SourceImage("LandingCrest.png",    215, 3,   118, 70)', s)
        self.assertIn('SourceImage("LandingWordmark.png", 139, 73,  272, 37)', s)
        self.assertIn('SourceImage("LandingRule.png",     139, 110, 273, 21)', s)
        self.assertIn('"LandingPrimary.png", 159, 157, 230, 44)', s)
        self.assertIn('"LandingSecondary.png", 175, 200, 197, 40)', s)
        self.assertIn('plate:SetAllPoints(button)', s)
        self.assertIn('button.label:SetDrawLayer("OVERLAY", 3)', s)

    def test_responsive_without_extra_engines(self):
        s = read("UI/BlizzardSettings.lua")
        self.assertIn("layout:SetScale(math.max(0.30, scale))", s)
        self.assertIn("math.min(w / BASE_W, h / BASE_H)", s)
        self.assertIn('surface:SetScript("OnSizeChanged", Fit)', s)
        self.assertNotIn('SetScript("OnUpdate"', s)
        self.assertEqual(s.count('Style.Skin(surface, LANDING_BG'), 1)
        self.assertNotIn("HeaderOption5TintAtlas.png", s)
        self.assertNotIn("LockedBrandBand", s)
        self.assertNotIn("Test Build", s)

    def test_faction_feathering_matches_dark_center(self):
        s = read("UI/BlizzardSettings.lua")
        # A continuous pair of gradients frames the fully dark center;
        # all foreground text, crest and buttons stay outside this shading.
        self.assertIn("FadeFaction(90, 145, 0, 1)", s)
        self.assertIn("FadeFaction(313, 145, 1, 0)", s)
        self.assertIn("quietCenter:SetSize(78, BASE_H)", s)
        self.assertIn('shade:SetGradient("HORIZONTAL"', s)
        self.assertIn('type(CreateColor) == "function"', s)
        self.assertIn("local steps = 24", s)
        self.assertLess(s.index("FadeFaction(313, 145, 1, 0)"),
                        s.index("local function SourceImage"))
        self.assertEqual(s.count('Style.Skin(surface, LANDING_BG'), 1)

    def test_art_silhouette_owns_hover_and_press_not_rectangular_mask(self):
        s = read("UI/BlizzardSettings.lua")
        style = read("UI/Style.lua")
        self.assertIn('Style.Action(layout, caption, "landing-art")', s)
        self.assertIn('local landingArt = variant == "landing-art"', style)
        self.assertIn('if not landingArt then\n        hover = Style.FeedbackOverlay', style)
        self.assertIn("if not landingArt and ns.Widgets and ns.Widgets.PressFeedback", style)
        self.assertIn("if not landingArt and ns.Tooltips then", style)
        self.assertIn('glow:SetTexture(media .. art)', s)
        self.assertIn('glow:SetBlendMode("ADD")', s)
        self.assertIn('glow:SetAlpha(0)', s)
        self.assertIn('Motion.Fade(glow, 0.23', s)
        self.assertIn('Motion.Stop(glow, 0.42)', s)
        self.assertIn('button:HookScript("OnHide"', s)

    def test_native_api_safe_handoff(self):
        s = read("UI/BlizzardSettings.lua")
        for token in ["RegisterCanvasLayoutCategory", "RegisterAddOnCategory",
                      "InterfaceOptions_AddCategory", 'HideUIPanel(settings)',
                      "InCombat()", "Later(function()",
                      'event:RegisterEvent("PLAYER_LOGIN")',
                      'Motion.Fade(surface, 1, Motion.Duration("gentle"))']:
            self.assertIn(token, s)
        # Landing hover stays visual-only; boxed help popups obscured the art.
        self.assertNotIn('ns.Tooltips.Bind(open', s)
        self.assertNotIn('ns.Tooltips.Bind(community', s)
        self.assertNotIn("outsideWindow = true", s)

    def test_ellesmere_remains_optional_not_second_skin(self):
        s = read("UI/BlizzardSettings.lua")
        theme = read("UI/Theme.lua")
        self.assertIn('ns.Theme.Refresh()', s)
        self.assertIn('pcall(eui.RegisterSkin, "DuelsReimagined"', theme)
        self.assertNotIn('RegisterSkin(', s)
        self.assertNotIn('S.Shell', s)
        self.assertNotIn("C.body", s)
        self.assertNotIn("C.text", s)
        self.assertNotIn("C.muted", s)


if __name__ == "__main__":
    unittest.main()
