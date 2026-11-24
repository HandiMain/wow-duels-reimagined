"""Regression for WoW navigation init and the diamond-free centered wordmark.

The Nov 20 regression came from SetJustifyV("CENTER"), which is not a WoW
vertical alignment: only TOP, MIDDLE, BOTTOM are valid. Syntax-only CI
cannot catch such API-enum misuse. Search all addon Lua sources.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def text(path):
    return (ROOT / path).read_text(encoding="utf-8")

class SecondaryRailRecoveryTests(unittest.TestCase):
    def test_all_static_vertical_justification_arguments_are_valid(self):
        checked = 0
        for path in ROOT.rglob("*.lua"):
            body = path.read_text(encoding="utf-8")
            for match in re.finditer(
                r':SetJustifyV\s*\(\s*["\x27]([^"\x27]+)["\x27]\s*\)', body
            ):
                self.assertIn(match.group(1), {"TOP", "MIDDLE", "BOTTOM"},
                              f"{path.relative_to(ROOT)}: invalid WoW justifyV")
                checked += 1
        self.assertGreater(checked, 0, "Must exercise at least one justifyV call")

    def test_footer_navigation_reaches_all_click_handlers(self):
        nav = text("UI/Navigation.lua")
        self.assertIn('button:SetSize(112, 30)', nav)
        self.assertIn('item:SetPoint("LEFT", Window.utility, "LEFT",', nav)
        self.assertIn('for index, section in ipairs(sections) do', nav)
        for section in ("community", "patchnotes", "options"):
            self.assertIn('{ key = "' + section + '"', nav)
        self.assertIn('local primaryKeys = { hall = true, leaderboard = true, matchhistory = true, achievements = true, wargames = true }', nav)
        self.assertIn('if isPrimary then item.key=section.key;primaryButtons[#primaryButtons + 1] = item end', nav)
        self.assertIn('ns.Search.Register("page:" .. section.key', nav)

    def test_primary_hall_and_subcategories_do_not_share_a_rail(self):
        nav, window = text("UI/Navigation.lua"), text("UI/Window.lua")
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, HALL_BUTTON_HEIGHT)', nav)
        self.assertIn('button:SetSize(112, 30)', nav)
        self.assertIn('sub:SetSize(174, 35)', nav)
        self.assertIn('Window.nav:SetScript("OnSizeChanged", FitSubTabs)', nav)
        self.assertIn('nav:SetPoint("TOPLEFT", content, "TOPLEFT", 22, -83)', window)

    def test_center_diamond_removed_and_rules_are_mirrored(self):
        window = text("UI/Window.lua")
        self.assertIn('DuelBrand.png', window)
        self.assertNotIn('BrandLayer(', window)
        self.assertNotIn('BrandLayer(C.gold,       0.50, 0.75, 3)', window)
        self.assertNotIn('local underline = CreateFrame(', window)
        self.assertIn('LandingWordmark.png', text("UI/BlizzardSettings.lua"))

    def test_unchanged_button_and_theme_owners(self):
        nav = text("UI/Navigation.lua")
        window = text("UI/Window.lua")
        self.assertIn('local selected, hover = AddOverlay(button, isPrimary)',nav)
        self.assertIn('ns.Widgets.PressFeedback(button, hover, {',nav)
        self.assertIn('ns.Tooltips.Bind(button, { title = section.label,',nav)
        self.assertNotIn('Style.Fill(underline, C.gold, "ARTWORK")',window)
        self.assertIn('function Window.PlaceBrandBefore(searchBox)', window)
        self.assertIn('brandArea:SetPoint("RIGHT", searchBox, "LEFT", -12, 0)',window)
        self.assertIn('function Window.ApplyScale(value)',window)
        self.assertNotIn('SetScript("OnUpdate"',nav)

if __name__ == "__main__":
    unittest.main()
