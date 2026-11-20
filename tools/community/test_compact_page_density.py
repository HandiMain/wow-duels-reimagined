"""Regression contracts for denser pages and centered approved branding.
Source/layout checks are not a substitute for actual in-game verification.
"""
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def src(path):
    return (BASE / path).read_text(encoding="utf-8")

class CompactPageDensityTests(unittest.TestCase):
    def test_wider_wordmark_centered_without_new_texture(self):
        w = src("UI/Window.lua")
        for marker in (
            "local BRAND_ASPECT = 4.65",
            "BRAND_MAX_WIDTH, BRAND_MAX_HEIGHT = 312, 67",
            'brandLogo:SetPoint("LEFT", brandArea, "LEFT", 24, -3)',
            'BrandLayer(C.gold,       0,    0.25, -4)',
            'BrandLayer(C.headerText, 0.25, 0.50, -4)',
            '-- Text-only branding: the two alpha-masked letter layers above are the',
            'brandArea:SetPoint("RIGHT", searchBox, "LEFT", -18, 0)',
        ):
            self.assertIn(marker, w)
        self.assertIn("HeaderOption5TintAtlas.png",
                      src("UI/BlizzardSettings.lua"))

    def test_secondary_icons_labels_and_selected_text(self):
        n = src("UI/Navigation.lua")
        for marker in (
            "button:SetSize(90, 90)",
            "icon:SetSize(isPrimary and 29 or 43",
            "isPrimary and 16 or 11, C.tabMuted",
            "label:SetWidth(86)",
            "label:SetHeight(32)",
            'label:SetJustifyH("CENTER")',
            'label:SetJustifyV("MIDDLE")',
            "item.label:SetTextColor(unpack(active and C.tabText or C.text))",
            "sub:SetSize(230, 38)",
            "-(79 + (pageIndex - 1) * 41)",
        ):
            self.assertIn(marker, n)
        self.assertIn("primaryKeys = { hall = true }", n)
        self.assertIn("SetPatchUnread = function(unread)", n)

    def test_appearance_fits_compact_window_viewport(self):
        o = src("UI/Options.lua")
        self.assertIn('Window.content, "TOPLEFT", 26, -98', o)
        self.assertIn('Window.content, "BOTTOMRIGHT", -26, 17', o)
        self.assertIn("local appearance = Page(175)", o)
        self.assertIn("Card(appearance, 0, 165)", o)
        visible = 650 - 12 - 82 - 57 - 52 - 14
        viewport = visible - 98 - 17
        self.assertGreaterEqual(viewport, 175)
        self.assertIn("local ROW_TOP = 38", o)
        self.assertIn("local cardHeight = y + 6", o)

    def test_interface_cards_do_not_overlap_and_search_scrolls(self):
        o = src("UI/Options.lua")
        self.assertIn("local interface = Page(540)", o)
        for marker in (
            "Card(interface, 0, 160)", "Card(interface, 168, 143)",
            "Card(interface, 319, 210)",
            "MarkPosition(fontScale, typographyCard, -131)",
            "MarkPosition(iconMode, accessCard, -64)",
            "MarkPosition(resetAccess, accessCard, -332)",
            'ns.Search.Register("setting:" .. key',
            "sf:SetVerticalScroll(",
            "tallest = math.max(tallest, cardHeight)",
            "local contentHeight = sectionY + tallest + 6",
        ):
            self.assertIn(marker, o)
        spans = [(0,160), (168,143), (319,210)]
        for i in range(len(spans) - 1):
            self.assertLess(spans[i][0] + spans[i][1], spans[i+1][0])
        self.assertLessEqual(319 + 210, 540)
        widgets = src("UI/Widgets.lua")
        for height in (54,66,64):
            self.assertIn(f"row:SetHeight({height})", widgets)
        for compact in ("compact and 28 or 54", "compact and 32 or 66",
                        "compact and 32 or 64"):
            self.assertIn(compact, widgets)

    def test_community_cards_are_denser_but_data_still_dynamic(self):
        c = src("UI/Community.lua")
        for marker in (
            "card:SetHeight(155)", "local y = upper and -175 or -345",
            "canvas:SetHeight(523)", "listing:SetHeight(245)",
            "canvas:SetHeight(185 + h + 20)",
            "math.max(245, 116 + #entries * 30)",
            'Action("bug", "REPORT A BUG", -151)',
            'Action("idea", "SUGGEST AN IDEA", 151)',
            "ns.CommunityCredits or {}",
            "function Community.Show(key)",
        ):
            self.assertIn(marker, c)
        self.assertLessEqual(345 + 155, 523)

    def test_patch_notes_reflow_keeps_version_data_and_link_targets(self):
        p = src("UI/PatchNotes.lua")
        for marker in (
            'scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 22, -113)',
            "banner:SetHeight(118)",
            "row:SetHeight(82)",
            "-164 - (index - 1) * 90",
            "local y = 164 + count * 90 + 11",
            "canvas:SetHeight(y + 110)",
            "Settings.MarkPatchNotesSeen(item.data.id)",
            "Search.entries[entry.target]",
        ):
            self.assertIn(marker, p)
        self.assertGreaterEqual(164 - (3 + 118), 15)
        self.assertLess(82, 90)

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
