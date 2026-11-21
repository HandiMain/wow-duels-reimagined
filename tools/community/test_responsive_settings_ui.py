"""Responsive settings, branding and utility-navigation regression contracts.

Source-level tests do not certify in-game rendering. They protect the game API
contracts and layout ownership that previously regressed.
"""
from pathlib import Path
import re
import unittest

BASE = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

def read(path):
    return (BASE / path).read_text(encoding="utf-8")

class ResponsiveSettingsTests(unittest.TestCase):
    def test_whole_cards_reflow_not_individual_settings(self):
        src = read("UI/Options.lua")
        self.assertIn("local CARD_BREAKPOINT = 720", src)
        self.assertIn("width >= (largeText and 1080 or CARD_BREAKPOINT)", src)
        self.assertIn("local columns = twoCards and 2 or 1", src)
        self.assertIn("local cardX = column * (cardWidth + CARD_GAP)", src)
        self.assertIn('card:SetPoint("TOPLEFT", page, "TOPLEFT", cardX, -sectionY)', src)
        self.assertIn("card:SetWidth(cardWidth)", src)
        self.assertIn("tallest = math.max(tallest, cardHeight)", src)
        self.assertIn("widget:LayoutForWidth(usable, not largeText)", src)
        self.assertNotIn("local half =", src)
        self.assertNotIn("firstHeight", src)
        self.assertIn("if content.Relayout then content:Relayout(content:GetWidth()) end", src)
        self.assertIn("function appearance:Relayout(width)", src)
        self.assertIn("function interface:Relayout(width)", src)

    def test_card_grid_geometry_and_scroll_clamp(self):
        src = read("UI/Options.lua")
        self.assertIn("local fullWidth = math.max(1, width - 18)", src)
        self.assertIn("math.floor((fullWidth - CARD_GAP) / 2)", src)
        self.assertIn("page.scrollOwner:SetVerticalScroll(maxScroll)", src)
        for width in (500, 650, 719):
            self.assertFalse(width >= 720)
        for width in (720, 824, 1050):
            self.assertTrue(width >= 720)
            card = (width - 18 - 14) // 2
            self.assertGreaterEqual(card - 40, 304)
            self.assertLessEqual(2 * card + 14, width - 18)
        self.assertFalse(1050 >= 1080)
        self.assertTrue(1080 >= 1080)

    def test_shared_rows_remain_inline_inside_cards(self):
        src = read("UI/Widgets.lua")
        self.assertEqual(src.count("function row:LayoutForWidth(width, compact)"), 3)
        for kind in ("ToggleRow", "ChoiceRow", "SliderRow"):
            self.assertIn("function Widgets."+kind+"(", src)
        for marker in (
            "self:SetHeight(compact and 28 or 54)",
            "self:SetHeight(compact and 32 or 66)",
            "self:SetHeight(compact and 32 or 64)",
            'control:SetWidth(math.max(112, math.min(140, width - 165)))',
            'slider:SetWidth(math.max(75, math.min(112, width - 165)))',
            'Paint(slider:GetValue())',
        ):
            self.assertIn(marker, src)
        self.assertIn("self.description:SetShown(not compact)", src)
        self.assertIn("if self.compact then", src)
        self.assertIn("self.description:GetText() or detail", src)
        self.assertNotIn('SetScript("OnUpdate"', src[:src.index("function Widgets.ScrollBar(")])

    def test_card_group_layout_owns_all_existing_settings(self):
        src = read("UI/Options.lua")
        for name in ("appearanceCard", "behaviorCard", "gameAccessCard",
                     "accessCard", "typographyCard", "notificationsCard"):
            self.assertIn("{ card = "+name+", entries = {", src)
        for name in ("themeChoice", "availability", "matchColorsRow", "matchFontRow",
                     "autoPeekRow", "reduceMotionRow", "tooltipsRow", "reminderRow",
                     "gameMenuRow",
                     "fontChoice", "fontScale", "fontOutline", "iconMode", "widgetSize",
                     "widgetTransparency", "compartmentToggle"):
            self.assertIn("{ widget = "+name, src)
        self.assertIn("resetAccess.optionsY = sectionY + buttonY", src)

    def test_settings_are_categorized_without_new_pages_or_storage(self):
        o = read("UI/Options.lua")
        for heading in ("Window & motion", "Game access", "Minimap & widget",
                        "Typography", "Notifications & help"):
            self.assertIn('"' + heading + '"', o)
        for row, parent in (("autoPeekMoving", "behaviorCard"),
                            ("showGameMenuButton", "gameAccessCard"),
                            ("showTooltips", "notificationsCard")):
            self.assertIn('AddToggle(' + parent + ', "interface", "' + row + '"', o)
        self.assertIn('local iconMode = Widgets.ChoiceRow(accessCard', o)
        self.assertIn('local fontChoice = Widgets.ChoiceRow(typographyCard', o)
        self.assertIn('function interface:Relayout(width) LayoutPage(self, interfaceGroups, width) end', o)
        self.assertIn('ns.Search.Register("setting:" .. key', o)
        self.assertNotIn('local secondOptionsPage =', o)

    def test_dense_section_headers_preserve_help_and_card_boundaries(self):
        src = read("UI/Options.lua")
        self.assertIn('local header = CreateFrame("Frame", nil, card)', src)
        self.assertIn('ns.Tooltips.Bind(header, {', src)
        self.assertIn('card.optionsHeading = header', src)
        self.assertIn('card.optionsHeading:SetHeight(largeText and 34 or 24)', src)
        self.assertIn('local y = largeText and 52 or ROW_TOP', src)
        self.assertIn('local ROW_TOP = 38', src)
        self.assertIn('local CARD_GAP, SECTION_GAP, ROW_GAP = 14, 8, 1', src)
        self.assertIn('math.ceil(widget:GetStringHeight() or 18) + 8', src)
        self.assertNotIn('local behaviorInfo = Style.Text(', src)
        self.assertNotIn('local fontInfo = Style.Text(', src)
        self.assertNotIn('local accessHint = Style.Text(', src)
        self.assertIn('return buttonY + resetAccess:GetHeight()', src)
        for message in (
            'Hold the eye to Peek. Fold leaves the header visible.',
            'Font matching is controlled under Appearance.',
            'Drag either icon to move it.',
        ):
            self.assertIn(message, src)

    def test_five_clear_categories_stay_compact_and_independent(self):
        o = read("UI/Options.lua")
        for title in ("Window & motion", "Game access", "Minimap & widget",
                      "Typography", "Notifications & help"):
            self.assertIn('"' + title + '"', o)
        # The same LayoutPage measures whole cards, independent of their rows.
        compact_toggle = 28
        compact_choice = 32
        behavior = 38 + 2 * (compact_toggle + 1) + 6
        game_access = 38 + 2 * (compact_toggle + 1) + 6
        access = 38 + 3 * (compact_choice + 1) + 4 + 34 + 6
        typography = 38 + 3 * (compact_choice + 1) + 6
        notices = 38 + 2 * (compact_toggle + 1) + 6
        self.assertEqual((behavior, game_access, access, typography, notices),
                         (102, 102, 181, 143, 102))
        self.assertLess(max(behavior, game_access) +
                        max(access, typography) + notices + 3 * 8, 420)
        self.assertIn('page:SetHeight(contentHeight > viewHeight + 1 and contentHeight or', o)
        self.assertIn('local cardHeight = y + (isAppearance and 10 or 6)', o)

    def test_search_destinations_are_recalculated_after_resize(self):
        src = read("UI/Options.lua")
        self.assertIn("widget.optionsY = sectionY + y", src)
        self.assertIn("widget.optionsScroll", src)
        self.assertIn('ns.Search.Register("setting:" .. key', src)
        self.assertIn("ns.Navigation.SelectKey(\"options\", pageKey)", src)
        self.assertIn("sf:SetVerticalScroll(", src)
        self.assertIn("appearance:Relayout(appearance:GetWidth())", src)
        self.assertIn("interface:Relayout(interface:GetWidth())", src)

    def test_theme_explanations_cover_all_three_runtime_states(self):
        opts = read("UI/Options.lua")
        for phrase in (
            "if not ready then",
            "elseif matchedColors then",
            "Duel Hall is active. EllesmereUI matching is unavailable.",
            "EllesmereUI is providing colors.",
            "Duel Hall colors are active. Enable matching to use EllesmereUI colors.",
            "themeChoice:SetAvailable(false,",
            "themeChoice:SetModified(Settings.IsModified(\"uiTheme\"))",
            "availability:SetTextColor(unpack(C.muted))",
        ):
            self.assertIn(phrase, opts)
        self.assertNotIn('db.uiTheme = nil', opts)
        self.assertIn("pcall(eui.RegisterSkin", read("UI/Theme.lua"))

    def test_main_header_themed_and_landing_art_fixed_colors(self):
        win, land = read("UI/Window.lua"), read("UI/BlizzardSettings.lua")
        self.assertIn("BrandLayer(C.red,        0,    0.25)", win)
        self.assertIn("BrandLayer(C.headerText, 0.25, 0.50)", win)
        self.assertIn("HeaderOption5TintAtlas.png", land)
        self.assertIn("LockedBrandBand(LANDING_GOLD, 0, 0.25)", land)
        self.assertIn("LockedBrandBand(LANDING_PALE, 0.25, 0.50)", land)
        self.assertIn("Style.Skin(surface, LANDING_BG", land)
        self.assertNotIn("local underline = CreateFrame(", win)
        self.assertNotIn("DuelsReimagined-HeaderLogoFlat.png", land)
        self.assertNotIn("Style.TintedImage(logo, brandAtlas", land)
        self.assertNotIn("DuelsLandingEmblem.png", land)
        self.assertIn('function Window.PlaceBrandBefore(searchBox)', win)

    def test_hall_has_idle_skin_and_click_feedback(self):
        nav = read("UI/Navigation.lua")
        self.assertIn("if isPrimary then\n        Style.Skin(button, C.button", nav)
        self.assertIn("local selected, hover = AddOverlay(button, isPrimary)", nav)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)', nav)
        self.assertIn("ns.Widgets.PressFeedback(button, hover)", nav)
        self.assertIn("local primaryKeys = { hall = true }", nav)

    def test_all_nav_icons_use_fixed_artwork_not_theme_recolored_shapes(self):
        nav = read("UI/Navigation.lua")
        chrome = read("UI/Chrome.lua")
        self.assertIn('local icon = Chrome.Icon(button, section.icon)', nav)
        self.assertNotIn('Style.Fill(icon, C.goldDim', nav)
        self.assertIn("DuelsNavigationAtlas.png", chrome)
        self.assertIn("tex:SetTexCoord(unpack(uv))", chrome)
        self.assertIn("tex:SetVertexColor(1, 1, 1, 1)", chrome)
        self.assertIn('patchPulse:SetLooping("BOUNCE")', nav)
        self.assertIn('label:SetText("Patch Notes")', nav)
        self.assertIn("if item.icon.SetVertexColor then", nav)

    def test_all_wow_vertical_alignment_literal_values_valid(self):
        for file in BASE.rglob("*.lua"):
            text = file.read_text(encoding="utf-8")
            for mode in re.findall(r':SetJustifyV\s*\(\s*"([^"]+)"', text):
                self.assertIn(mode, ("TOP", "MIDDLE", "BOTTOM"), str(file))

    def test_no_gameplay_or_storage_changes_in_layout_files(self):
        for file in ("UI/Window.lua", "UI/Options.lua",
                     "UI/Navigation.lua", "UI/BlizzardSettings.lua"):
            text = read(file)
            self.assertNotIn("_G.DuelsReimaginedDB =", text)
            if file == "UI/Window.lua":
                # Only the approved drag proximity guide can update, and
                # its OnUpdate handler is removed on stop/hide.
                self.assertIn('self:SetScript("OnUpdate", function() DrawGuides() end)', text)
                self.assertIn('self:SetScript("OnUpdate", nil)', text)
                self.assertNotIn('frame:SetScript("OnUpdate"', text)
            else:
                self.assertNotIn('SetScript("OnUpdate"', text)

if __name__ == "__main__":
    unittest.main()
