"""Regression contracts for denser pages and centered approved branding.
Source/layout checks are not a substitute for actual in-game verification.
"""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def src(path):
    return (BASE / path).read_text(encoding="utf-8")

class CompactPageDensityTests(unittest.TestCase):
    def test_wider_wordmark_extracted_from_approved_artwork(self):
        w = src("UI/Window.lua")
        for marker in (
            "local brandDrag = CreateFrame",
            "local visualWidth = math.min(330, available)",
            'brandArea:SetPoint("LEFT", header, "LEFT", 14, 0)',
            'Drag(brandDrag)',
            'DuelBrand.png',
            '-- The approved static identity has ONE paint owner.',
            'brandArea:SetPoint("RIGHT", searchBox, "LEFT", -12, 0)',
            'exactBrand:SetTexCoord(0, 384/512, 25/128, 93/128)',
        ):
            self.assertIn(marker, w)
        landing = src("UI/BlizzardSettings.lua")
        self.assertIn("LandingWordmark.png", landing)
        self.assertIn('SourceImage("LandingCrest.png"', landing)
        self.assertIn('SourceImage("LandingRule.png"', landing)
        self.assertIn("Style.Skin(surface, LANDING_BG", landing)
        self.assertNotIn("DuelsLandingEmblem.png", landing)

    def test_footer_shortcuts_and_content_tabs_are_compact(self):
        n = src("UI/Navigation.lua")
        for marker in (
            "button:SetSize(112, 30)",
            "icon:SetSize(isPrimary and 48 or 20",
            'Style.ConstrainButtonLabel(button, label, 34, 6, 9)',
            "sub:SetSize(174, 35)",
            "item.label:SetTextColor(unpack(active and C.tabText or C.text))",
            'Window.nav:SetScript("OnSizeChanged", FitSubTabs)',
        ):
            self.assertIn(marker, n)
        self.assertIn("primaryKeys = { hall = true, leaderboard = true, matchhistory = true, achievements = true, tournaments = true, wargames = true }", n)
        self.assertIn("SetPatchUnread = function(unread)", n)

    def test_appearance_fits_compact_window_viewport(self):
        o = src("UI/Options.lua")
        self.assertIn('Window.content, "TOPLEFT", 26, -153', o)
        self.assertIn('Window.content, "BOTTOMRIGHT", -26, 17', o)
        self.assertIn("local appearance = Page(130)", o)
        self.assertIn("Card(appearance, 0, 165)", o)
        self.assertIn("{ widget = matchFontRow }", o)
        self.assertNotIn("themeChoice", o)
        visible = 650 - 12 - 72 - 50 - 14
        viewport = visible - 153 - 17
        self.assertGreaterEqual(viewport, 130)
        self.assertIn("local ROW_TOP = 90", o)
        self.assertIn("local cardHeight = y + (isAppearance and 10 or 6)", o)

    def test_pill_switch_uses_existing_rounded_assets_and_preserves_behavior(self):
        w = src("UI/Widgets.lua")
        self.assertIn("local TOGGLE_W, TOGGLE_H, TOGGLE_KNOB, TOGGLE_PAD = 40, 20, 16, 2", w)
        self.assertIn('row.track:SetTexture(texPath .. "ToggleTrack.tga")', w)
        self.assertIn('row.thumb:SetTexture(texPath .. "ToggleThumb.tga")', w)
        self.assertIn("local travel = TOGGLE_W - TOGGLE_KNOB - TOGGLE_PAD * 2", w)
        self.assertIn("TOGGLE_PAD + travel * p", w)
        self.assertIn("Motion.Value(self.slideKey, self.progress or 0, dest,", w)
        self.assertIn("if self.available and self.onToggle then self.onToggle(not self.checked) end", w)
        self.assertIn("self.resetButton:SetEnabled(self.modified and self.available)", w)
        self.assertIn("function methods:RefreshColors()", w)
        self.assertTrue((BASE / "Media/Textures/ToggleTrack.tga").is_file())
        self.assertTrue((BASE / "Media/Textures/ToggleThumb.tga").is_file())

    def test_interface_cards_do_not_overlap_and_search_scrolls(self):
        o = src("UI/Options.lua")
        self.assertIn("local interface = Page(740)", o)
        for marker in (
            "Card(interface, 0, 100)", "Card(interface, 108, 100)",
            "Card(interface, 216, 174)", "Card(interface, 398, 143)",
            "Card(interface, 549, 100)",
            "MarkPosition(fontScale, typographyCard, -131)",
            "MarkPosition(iconMode, accessCard, -64)",
            "MarkPosition(resetAccess, accessCard, -332)",
            'ns.Search.Register("setting:" .. key',
            "sf:SetVerticalScroll(",
            "tallest = math.max(tallest, cardHeight)",
            "local contentHeight = sectionY + tallest + 6",
        ):
            self.assertIn(marker, o)
        spans = [(0,100), (108,100), (216,174),
                 (398,143), (549,100)]
        for i in range(len(spans) - 1):
            self.assertLess(spans[i][0] + spans[i][1], spans[i+1][0])
        self.assertLessEqual(549 + 100, 740)
        widgets = src("UI/Widgets.lua")
        for height in (54,66,64):
            self.assertIn(f"row:SetHeight({height})", widgets)
        for compact in ("compact and 28 or 54", "compact and 32 or 66",
                        "compact and 32 or 64"):
            self.assertIn(compact, widgets)

    def test_community_cards_are_denser_but_data_still_dynamic(self):
        c = src("UI/Community.lua")
        for marker in (
            'local statsPanel = CreateFrame("Frame", nil, stage)',
            "local creditsPanel = InfoPanel(true)",
            "local helpPanel = InfoPanel(false)",
            "canvas:SetHeight(height)", "listing:SetHeight(245)",
            "local listingTop = heroHeight + 17",
            "math.max(245, 116 + #entries * 30)",
            'Action("bug", "REPORT A BUG", -133)',
            'Action("idea", "SUGGEST AN IDEA", 133)',
            "ns.CommunityCredits or {}",
            "function Community.Show(key)",
        ):
            self.assertIn(marker, c)
        self.assertLessEqual(233 + 203, 460)
        self.assertIn('local compact = width < CARD_BREAKPOINT', c)
        self.assertIn('local cardWidth = math.min(510, math.max(1, width - 24))', c)
        self.assertIn('stage:SetPoint("TOP", canvas, "TOP", 0, 0)', c)

    def test_patch_notes_reflow_keeps_version_data_and_link_targets(self):
        p = src("UI/PatchNotes.lua")
        for marker in (
            'rail:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -88)',
            'versionScroll:SetPoint("TOPLEFT", rail, "TOPLEFT", 11, -51)',
            'scroll:SetPoint("TOPLEFT", rail, "TOPRIGHT", 16, 0)',
            "banner:SetHeight(141)",
            "row:SetHeight(72)",
            "-258 - (index - 1) * 80",
            "local y = rowsY + count * rowStep + (dense and 5 or 12)",
            "canvas:SetHeight(y + (dense and 27 or 40))",
            'local dense = scroll:GetHeight() < 590',
            'local rowHeight = dense and 61 or 72',
            'local bannerHeight = compact and 153 or (dense and 120 or 141)',
            'banner:SetHeight(bannerHeight)',
            'local summaryH = compact and (dense and 81 or 84) or (dense and 54 or 64)',
            'local titleY = summaryY + summaryH + (dense and 11 or 14)',
            "Settings.MarkPatchNotesSeen(item.data.id)",
            "Search.entries[entry.target]",
        ):
            self.assertIn(marker, p)
        self.assertGreaterEqual(258 - (154 + 64), 24)
        self.assertLess(72, 80)
        self.assertIn('local compact = width < 620', p)
        self.assertIn('local versionBar = Widgets.ScrollBar(versionScroll,', p)

    def test_visual_changes_do_not_create_gameplay_or_polling_owner(self):
        for p in ("UI/Options.lua", "UI/Navigation.lua",
                  "UI/Community.lua", "UI/PatchNotes.lua"):
            self.assertNotIn('SetScript("OnUpdate"', src(p))
            self.assertNotIn("_G.DuelsReimaginedDB", src(p))
        self.assertIn('pcall(eui.RegisterSkin, "DuelsReimagined"',
                      src("UI/Theme.lua"))
        self.assertIn("function Window.ResetWindow()", src("UI/Window.lua"))

if __name__ == "__main__":
    unittest.main()
