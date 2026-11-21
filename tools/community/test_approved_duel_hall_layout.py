"""Approved Duel Hall screen: geometry, ownership and standalone compatibility.

All tests are static/model-only. WoW in-game visual tests remain mandatory.
"""
from pathlib import Path
import unittest

ADDON = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def read(name):
    return (ADDON / name).read_text(encoding="utf-8")

class ApprovedDuelHallLayoutTests(unittest.TestCase):
    def test_default_window_has_separate_nonoverlapping_regions(self):
        # Source constants from the approved composition at its 1050x650
        # minimum/default. Reflow at smaller effective screen resolutions
        # still requires visual inspection.
        width, height = 1050, 650
        inset, header, footer, rail = 6, 72, 50, 226
        self.assertLess(rail, width - 2 * inset)
        self.assertGreater(height - 2 * inset - header - footer, 450)
        content = width - 2 * inset - rail
        self.assertGreaterEqual(content, 780)
        # Footer utilities + compact secondary links + Close fit at default.
        utility_left = width - inset - 147 - 336
        close_left = width - inset - 20 - 105
        self.assertGreater(utility_left, 500)
        self.assertGreaterEqual(close_left - (utility_left + 336), 20)
        self.assertGreaterEqual(content - 44, 700)

    def test_page_tabs_have_separate_window_and_one_responsive_owner(self):
        w, n = read("UI/Window.lua"), read("UI/Navigation.lua")
        self.assertIn('nav:SetPoint("TOPLEFT", content, "TOPLEFT", 22, -83)', w)
        self.assertIn('Window.nav = nav', w)
        self.assertIn('Window.nav:SetShown(#section.pages > 1)', n)
        self.assertIn('Window.nav:SetScript("OnSizeChanged", FitSubTabs)', n)
        self.assertIn('Window.rail:SetScript("OnSizeChanged", FitTabs)', n)
        self.assertIn('sub:SetScript("OnClick", function() Select(index, pageIndex) end)', n)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)', n)
        self.assertNotIn('button:SetSize(90, 90)', n)

    def test_appearance_full_width_interface_dense_fallback(self):
        o = read("UI/Options.lua")
        for text in ('local CARD_BREAKPOINT = 760',
                     'local twoCards = #groups > 1 and',
                     'width >= (largeText and 1080 or CARD_BREAKPOINT)',
                     'scroll:SetPoint("TOPLEFT", Window.content, "TOPLEFT", 26, -153)',
                     'widget:LayoutForWidth(usable, not largeText)',
                     'page.scrollOwner:SetVerticalScroll(maxScroll)'):
            self.assertIn(text, o)
        self.assertIn('themeChoice:SetAvailable(false,', o)
        self.assertIn('function appearance:Relayout(width)', o)
        self.assertIn('function interface:Relayout(width)', o)

    def test_one_theme_and_optional_ellesmere_matching(self):
        style, theme, settings = (read(name) for name in
            ('UI/Style.lua', 'UI/Theme.lua', 'Core/Settings.lua'))
        self.assertEqual(style.count('duelhall = {'), 1)
        self.assertIn('function Style.IsTheme(key) return key == "duelhall" end', style)
        for obsolete in ('ivory = {', 'slate = {', 'verdant = {',
                         'ember = {', 'moonstone = {'):
            self.assertNotIn(obsolete, style)
        self.assertIn('if key == "uiTheme" then return "duelhall" end', settings)
        self.assertIn('db.uiTheme = Settings.Get("uiTheme")', settings)
        self.assertIn('function Theme.IsAvailable()', theme)
        self.assertIn('Style.ApplyTheme(accent, panel, font)', theme)

    def test_no_new_gameplay_data_or_menu_dependency(self):
        n = read("UI/Navigation.lua")
        gm = read("UI/GameMenu.lua")
        self.assertIn('local primaryKeys = { hall = true }', n)
        self.assertIn('ns.Search.Register("page:" .. section.key', n)
        self.assertIn('local function ManualSlot(menu, upper, addons)', gm)
        self.assertIn('local function HasManualButtons(menu)', gm)
        self.assertNotIn('HorizonSuiteGameMenuButton', gm)
        self.assertNotIn('PolestarGameMenuButton', gm)
        self.assertNotIn('SetScript("OnUpdate"', n)

if __name__ == "__main__":
    unittest.main()
