"""Regression contracts for the approved Duel Hall design (structural, not live WoW)."""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def src(p):
    return (BASE / p).read_text(encoding="utf-8")

class ThemeRedesignTests(unittest.TestCase):
    def test_gameplay_rail_content_tabs_footer_and_fold(self):
        w, n, h = src("UI/Window.lua"), src("UI/Navigation.lua"), src("UI/Header.lua")
        for token in (
            'header:SetHeight(72)', 'footer:SetHeight(50)',
            'rail:SetWidth(226)', 'Window.rail = rail',
            'utility:SetSize(360, 36)', 'Window.utility = utility',
            'nav:SetHeight(35)', 'Window.nav = nav',
            'main:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)',
            'Window.header, Window.footer, Window.body = header, footer, body',
            'local pageIcon = Chrome.Icon(content, "Options")',
        ):
            self.assertIn(token, w)
        self.assertIn('local HALL_BUTTON_WIDTH = 205', n)
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, 84)', n)
        self.assertIn('button:SetSize(112, 30)', n)
        self.assertIn('sub:SetSize(174, 35)', n)
        self.assertIn('local function FitSubTabs(self, width)', n)
        self.assertIn('Window.nav:SetShown(#section.pages > 1 and section.key ~= "patchnotes" and not page.competitive)', n)
        self.assertIn('Window.rail:Hide()', h)
        self.assertIn('Window.rail:Show()', h)

    def test_one_fixed_house_palette_and_safe_saved_variable_retirement(self):
        st, settings, opts = (src(p) for p in
            ("UI/Style.lua", "Core/Settings.lua", "UI/Options.lua"))
        self.assertIn('local duelHall = {', st)
        for old in ('ivory = {', 'slate = {', 'verdant = {',
                    'ember = {', 'moonstone = {'):
            self.assertNotIn(old, st)
        self.assertNotIn('Style.ThemeChoices', st)
        self.assertIn('db.uiTheme = nil', settings)
        self.assertIn('db.matchColors = nil', settings)
        self.assertNotIn('if key == "uiTheme"', settings)
        self.assertNotIn('themeChoice', opts)
        self.assertNotIn('matchColorsRow', opts)
        self.assertIn('{ widget = matchFontRow }', opts)

    def test_ellesmere_can_update_fonts_but_not_project_colors(self):
        style, theme = src("UI/Style.lua"), src("UI/Theme.lua")
        for token in ('for _, entry in ipairs(colorTextures)',
                      'for _, entry in ipairs(fontStrings)',
                      'for name, hex in pairs(duelHall)',
                      'local opacity = entry.region:GetAlpha()'):
            self.assertIn(token, style)
        for retired in ('if panel then', 'if accent then',
                        'GetAccentColor', 'GetPanelColor'):
            self.assertNotIn(retired, style + theme)
        self.assertIn('Style.ApplyTheme(font)', theme)

    def test_approved_brand_and_shared_code_drawn_chrome(self):
        w, chrome, style = (src(p) for p in
            ("UI/Window.lua", "UI/Chrome.lua", "UI/Style.lua"))
        for token in ('local brandDrag = CreateFrame', 'Drag(brandDrag)',
                      'DuelBrand.png',
                      'exactBrand:SetTexCoord(0, 384/512, 25/128, 93/128)'):
            self.assertIn(token, w)
        self.assertIn('Style.Plate(rim, "shellCopper"', chrome)
        self.assertIn('function Chrome.Divider(', chrome)
        self.assertIn('Style.Skin(button, C.button, {', style)

    def test_existing_feature_owners_preserved(self):
        h, f, n, w = (src(p) for p in
            ("UI/Header.lua", "UI/Footer.lua", "UI/Navigation.lua", "UI/Window.lua"))
        for token in ('function Header.Fold(', 'function Header.RefreshAutoPeek()',
                      'function Header.CloseSearch(', 'Search.Register("header:close"'):
            self.assertIn(token, h)
        for token in ('Window.ResetWindow()', 'Settings.NeedsReload()',
                      'function Footer.ShowCommunityLink(title, url)'):
            self.assertIn(token, f)
        for token in ('ns.Search.Register("page:" .. section.key',
                      'SetPatchUnread = function(unread)',
                      'Select(currentSection, currentPage, true, true)'):
            self.assertIn(token, n)
        for token in ('Settings.GetWindowSize()', 'function Window.ApplyScale(value)',
                      'ns.PatchNotes.Show(isPatchNotes and page.key or nil)',
                      'ns.Community.Show(isCommunity and page.key or nil)'):
            self.assertIn(token, w)

    def test_no_idle_polling_or_duplicate_storage(self):
        for path in ("UI/Style.lua", "UI/Chrome.lua", "UI/Navigation.lua"):
            s = src(path)
            self.assertNotIn('SetScript("OnUpdate"', s)
            self.assertNotIn('_G.DuelsReimaginedDB', s)
        self.assertIn('local function WriteDB()', src("Core/Settings.lua"))

if __name__ == "__main__":
    unittest.main()
