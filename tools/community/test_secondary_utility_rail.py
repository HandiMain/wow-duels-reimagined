"""Hall-only primary strip + left-side premium utility rail contracts.

Structural regression evidence only; real visuals/interaction require WoW.
"""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def read(path):
    return (BASE / path).read_text(encoding="utf-8")


class UtilityRailTests(unittest.TestCase):
    def test_distinct_primary_and_secondary_owners(self):
        w = read("UI/Window.lua")
        n = read("UI/Navigation.lua")
        self.assertIn('local primaryKeys = { hall = true }', n)
        self.assertIn('local railButtons, primaryButtons, subButtons = {}, {}, {}', n)
        self.assertIn('local parent = isPrimary and Window.rail or Window.utility', n)
        self.assertIn('button:SetSize(216, 44)', n)
        self.assertIn('button:SetSize(90, 90)', n)
        self.assertIn('Window.utility = utility', w)
        self.assertIn('utility:SetWidth(98)', w)
        self.assertIn('nav:SetWidth(210)', w)
        self.assertIn('nav:SetPoint("TOPLEFT", utility, "TOPRIGHT", 8, 0)', w)
        self.assertIn('main:SetPoint("TOPLEFT", nav, "TOPRIGHT", 9, 0)', w)
        self.assertNotIn('button:SetSize(165, 44)', n)

    def test_exact_three_utilities_not_added_as_primary(self):
        n = read("UI/Navigation.lua")
        for key in ('community', 'patchnotes', 'options'):
            self.assertIn('key = "' + key + '"', n)
        self.assertNotIn('community = true, options = true', n)
        self.assertIn('if isPrimary then primaryButtons[#primaryButtons + 1] = item end', n)
        self.assertIn('local utilityIndex = 0', n)
        self.assertIn('0, -12 - (utilityIndex - 1) * 98', n)
        self.assertIn('separator = Chrome.Divider(Window.utility, 44, 8)', n)
        self.assertIn('item.primary and C.gold or C.goldDim', n)

    def test_all_buttons_share_our_premium_theme_skin_and_motion(self):
        n, w, st = (read(p) for p in
                    ("UI/Navigation.lua", "UI/Window.lua", "UI/Style.lua"))
        self.assertIn('Style.Skin(utility, C.rail, {', w)
        self.assertIn('Style.Skin(nav, C.nav, {', w)
        self.assertIn('local selected = Style.Skin(button, C.tabActive', n)
        self.assertIn('local hover = Style.Skin(button, C.tabActive', n)
        self.assertIn('Motion.Fade(hover, 0.58, 0.17)', n)
        self.assertIn('ns.Widgets.PressFeedback(button, hover)', n)
        self.assertIn('ns.Tooltips.Bind(button, { title = section.label', n)
        self.assertIn('entry.region:SetVertexColor(unpack(value))', st)

    def test_navigation_search_patch_and_fold_still_work_through_owners(self):
        n, h = read("UI/Navigation.lua"), read("UI/Header.lua")
        for phrase in ('local function Select(sectionIndex, pageIndex,',
                       'function() Select(index, 1) end',
                       'ns.Navigation = {',
                       'SelectKey = function(sectionKey, pageKey)',
                       'ns.Search.Register("page:" .. section.key',
                       'SetPatchUnread = function(unread)',
                       'patchPulse:SetLooping("BOUNCE")',
                       'local function FitTabs(self, width)',
                       'for i, item in ipairs(primaryButtons) do'):
            self.assertIn(phrase, n)
        self.assertIn('Window.body:Hide()', h)
        self.assertIn('Window.rail:Hide()', h)
        self.assertIn('Window.body:Show()', h)
        self.assertIn('Window.rail:Show()', h)
        self.assertNotIn('SetScript("OnUpdate"', n)

    def test_unchanged_settings_and_gameplay_contracts(self):
        self.assertIn('function Window.ResetWindow()', read("UI/Window.lua"))
        self.assertIn('function Window.ApplyScale(value)', read("UI/Window.lua"))
        self.assertIn('local function WriteDB()', read("Core/Settings.lua"))
        self.assertIn('function Style.ApplyTheme(accent, panel, fontPath)',
                      read("UI/Style.lua"))
        self.assertIn('pcall(eui.RegisterSkin, "DuelsReimagined"',
                      read("UI/Theme.lua"))
        self.assertIn("Window.ResetWindow()", read("UI/Footer.lua"))
        self.assertIn('Style.Skin(surface, C.body', read("UI/BlizzardSettings.lua"))


if __name__ == "__main__":
    unittest.main()
