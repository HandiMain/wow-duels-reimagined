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

    def test_utility_section_creation_reaches_all_click_handlers(self):
        nav = text("UI/Navigation.lua")
        self.assertIn('label:SetJustifyV("MIDDLE")', nav)
        self.assertNotIn('label:SetJustifyV("CENTER")', nav)
        # Valid text alignment happens before the buttons get their OnClick.
        self.assertLess(nav.index('label:SetJustifyV("MIDDLE")'),
                        nav.index('button:SetScript("OnClick", function() Select(index, 1) end)'))
        self.assertIn('for index, section in ipairs(sections) do', nav)
        for section in ("community", "patchnotes", "options"):
            self.assertIn('{ key = "' + section + '"', nav)
        self.assertIn('local primaryKeys = { hall = true }', nav)
        self.assertIn('if isPrimary then primaryButtons[#primaryButtons + 1] = item end', nav)
        self.assertIn('ns.Search.Register("page:" .. section.key', nav)

    def test_proportions_fit_existing_90_unit_secondary_button(self):
        nav = text("UI/Navigation.lua")
        for marker in (
            'button:SetSize(90, 90)',
            'icon:SetSize(isPrimary and 29 or 43, isPrimary and 29 or 43)',
            'isPrimary and 16 or 11, C.tabMuted',
            'icon:SetPoint("TOP", button, "TOP", 0, -7)',
            'label:SetPoint("TOP", icon, "BOTTOM", 0, -2)',
            'label:SetHeight(32)',
            'label:SetJustifyH("CENTER")',
            'label:SetJustifyV("MIDDLE")',
            'label:SetText("PATCH\\nNOTES")',
        ):
            self.assertIn(marker, nav)
        # Top margin 7, glyph 43, gap 2, label box 32, bottom margin 6.
        self.assertLessEqual(7 + 43 + 2 + 32, 90)

    def test_center_diamond_removed_and_rules_are_mirrored(self):
        window = text("UI/Window.lua")
        self.assertIn('BrandLayer(C.gold,       0,    0.25, -4)', window)
        self.assertIn('BrandLayer(C.headerText, 0.25, 0.50, -4)', window)
        self.assertNotIn('BrandLayer(C.gold,       0.50, 0.75, 3)', window)
        self.assertNotIn('local underline = CreateFrame(', window)
        self.assertIn('DuelsLandingEmblem.png', text("UI/BlizzardSettings.lua"))

    def test_unchanged_button_and_theme_owners(self):
        nav = text("UI/Navigation.lua")
        window = text("UI/Window.lua")
        self.assertIn('local selected, hover = AddOverlay(button, isPrimary)',nav)
        self.assertIn('ns.Widgets.PressFeedback(button, hover)',nav)
        self.assertIn('ns.Tooltips.Bind(button, { title = section.label,',nav)
        self.assertNotIn('Style.Fill(underline, C.gold, "ARTWORK")',window)
        self.assertIn('function Window.PlaceBrandBefore(searchBox)', window)
        self.assertIn('brandArea:SetPoint("RIGHT", searchBox, "LEFT", -18, 0)',window)
        self.assertIn('function Window.ApplyScale(value)',window)
        self.assertNotIn('SetScript("OnUpdate"',nav)

if __name__ == "__main__":
    unittest.main()
