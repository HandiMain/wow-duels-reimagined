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
            'utility:SetSize(336, 36)', 'Window.utility = utility',
            'nav:SetHeight(35)', 'Window.nav = nav',
            'main:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)',
            'Window.header, Window.footer, Window.body = header, footer, body',
            'local pageIcon = Chrome.Icon(content, "Options")',
        ):
            self.assertIn(token, w)
        self.assertIn('local HALL_BUTTON_WIDTH = 195', n)
        self.assertIn('button:SetSize(HALL_BUTTON_WIDTH, 84)', n)
        self.assertIn('button:SetSize(104, 30)', n)
        self.assertIn('sub:SetSize(174, 35)', n)
        self.assertIn('local function FitSubTabs(self, width)', n)
        self.assertIn('Window.nav:SetShown(#section.pages > 1)', n)
        self.assertIn('Window.rail:Hide()', h)
        self.assertIn('Window.rail:Show()', h)

    def test_one_house_theme_and_safe_saved_variable_migration(self):
        st, settings, opts = (src(p) for p in
            ("UI/Style.lua", "Core/Settings.lua", "UI/Options.lua"))
        self.assertIn('duelhall = {', st)
        self.assertIn('key = "duelhall", label = "Duel Hall (Default)"', st)
        for old in ('ivory = {', 'slate = {', 'verdant = {',
                    'ember = {', 'moonstone = {'):
            self.assertNotIn(old, st)
        self.assertIn('function Style.IsTheme(key) return key == "duelhall" end', st)
        self.assertIn('if key == "uiTheme" then return "duelhall" end', settings)
        self.assertIn('db.uiTheme = Settings.Get("uiTheme")', settings)
        self.assertIn('themeChoice:SetChoices(Style.ThemeChoices()', opts)
        self.assertIn('themeChoice:SetAvailable(false,', opts)
        self.assertIn('Settings.Set("uiTheme", key)', opts)

    def test_ellesmere_recolors_all_roles(self):
        style = src("UI/Style.lua")
        for token in ('if panel then', 'if accent then',
                      'for _, entry in ipairs(colorTextures)',
                      'for _, entry in ipairs(fontStrings)',
                      '"header","footer","rail"', '"nav","body"',
                      '"gold","red","button","tabActive"',
                      '"selected"', '"hover"', '"buttonText"'):
            self.assertIn(token, style)
        self.assertIn('Style.ApplyTheme(accent, panel, font)', src("UI/Theme.lua"))

    def test_approved_brand_and_shared_code_drawn_chrome(self):
        w, chrome, style = (src(p) for p in
            ("UI/Window.lua", "UI/Chrome.lua", "UI/Style.lua"))
        for token in ('Chrome.Icon(brandArea, "Hall")',
                      'BrandLayer(C.red,        0,    0.25)',
                      'BrandLayer(C.headerText, 0.25, 0.50)',
                      '"YOUR DUELING HUB"', 'HeaderOption5TintAtlas.png'):
            self.assertIn(token, w)
        self.assertIn('Style.SkinMask(rim, C.shellEdge, "rim"', chrome)
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
