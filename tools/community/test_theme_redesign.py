"""Structural regression coverage for the approved code-first Hall redesign."""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
def src(p):
    return (BASE / p).read_text(encoding="utf-8")

class ThemeRedesignTests(unittest.TestCase):
    def test_horizontal_layout_and_fold(self):
        w, n, h = src("UI/Window.lua"), src("UI/Navigation.lua"), src("UI/Header.lua")
        for fragment in ('header:SetHeight(82)', 'rail:SetHeight(57)',
                         'rail:SetPoint("TOPLEFT", header, "BOTTOMLEFT"',
                         'body:SetPoint("TOPLEFT", rail, "BOTTOMLEFT"',
                         'nav:SetWidth(250)'):
            self.assertIn(fragment, w)
        self.assertIn('button:SetSize(165, 44)', n)
        self.assertNotIn('button:SetSize(86, 68)', n)
        self.assertIn("Window.rail:Hide()", h)
        self.assertIn("Window.rail:Show()", h)

    def test_palette_default_choices_and_one_settings_owner(self):
        style, settings, opts = (src(p) for p in
            ("UI/Style.lua", "Core/Settings.lua", "UI/Options.lua"))
        for fragment in ('ivory = {', 'slate = {', 'verdant = {',
                         'Ivory & Plum (Default)', 'function Style.ApplyTheme',
                         'function Style.ThemeChoices()'):
            self.assertIn(fragment, style)
        self.assertIn('if key == "uiTheme" then return "ivory" end', settings)
        self.assertIn('db.uiTheme = Settings.Get("uiTheme")', settings)
        self.assertIn('Settings.Set("uiTheme", key)', opts)
        self.assertIn('RegisterOption("uiTheme", "Color theme"', opts)
        self.assertIn('themeChoice:SetChoices(Style.ThemeChoices()', opts)

    def test_ellesmere_recolors_all_roles(self):
        style = src("UI/Style.lua")
        for fragment in ('if panel then', 'if accent then',
                         'for _, entry in ipairs(colorTextures)',
                         'for _, entry in ipairs(fontStrings)',
                         '"header","footer","rail"', '"nav","body"',
                         '"gold","red","button","tabActive"',
                         '"selected"', '"hover"', '"buttonText"'):
            self.assertIn(fragment, style)
        self.assertIn('Style.ApplyTheme(accent, panel, font)', src("UI/Theme.lua"))

    def test_major_chrome_is_drawn_in_code(self):
        chrome, style, patch = (src(p) for p in
            ("UI/Chrome.lua", "UI/Style.lua", "UI/PatchNotes.lua"))
        self.assertIn('Style.SkinMask(rim, C.shellEdge, "rim"', chrome)
        self.assertIn('function Chrome.Divider(', chrome)
        self.assertIn('Style.Fill(f, C.goldDim, "ARTWORK")', chrome)
        self.assertIn('Style.Skin(button, C.button, {', style)
        self.assertNotIn('TrimTop', chrome)
        self.assertNotIn('PatchNotesHero.tga', patch)
        self.assertIn('Style.Fill(banner, C.red, "ARTWORK")', patch)

    def test_original_feature_owners_preserved(self):
        h, f, n, w = (src(p) for p in
            ("UI/Header.lua", "UI/Footer.lua", "UI/Navigation.lua", "UI/Window.lua"))
        for token in ('function Header.Fold(', 'function Header.RefreshAutoPeek()',
                      'function Header.CloseSearch(', 'Search.Register("header:close"'):
            self.assertIn(token, h)
        for token in ("Window.ResetWindow()", "Settings.NeedsReload()",
                      "function Footer.ShowCommunityLink(title, url)"):
            self.assertIn(token, f)
        for token in ('ns.Search.Register("page:" .. section.key',
                      'SetPatchUnread = function(unread)',
                      'Select(currentSection, currentPage, true, true)'):
            self.assertIn(token, n)
        self.assertIn("Settings.GetWindowSize()", w)
        self.assertIn("function Window.ApplyScale(value)", w)
        self.assertIn('ns.PatchNotes.Show(isPatchNotes and page.key or nil)', w)
        self.assertIn('ns.Community.Show(isCommunity and page.key or nil)', w)

    def test_no_new_polling_or_duplicate_database(self):
        for path in ("UI/Style.lua", "UI/Chrome.lua", "UI/Navigation.lua"):
            s = src(path)
            self.assertNotIn('SetScript("OnUpdate"', s)
            self.assertNotIn("_G.DuelsReimaginedDB", s)
        self.assertIn('local function WriteDB()', src("Core/Settings.lua"))

if __name__ == "__main__":
    unittest.main()
