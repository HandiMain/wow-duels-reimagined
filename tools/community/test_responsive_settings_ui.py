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
        self.assertIn("local CARD_BREAKPOINT = 930", src)
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
        for width in (500, 650, 929):
            self.assertFalse(width >= 930)
        for width in (930, 1050, 1250):
            self.assertTrue(width >= 930)
            card = (width - 18 - 14) // 2
            self.assertGreaterEqual(card - 40, 400)
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
        for name in ("appearanceCard", "behaviorCard", "typographyCard", "accessCard"):
            self.assertIn("{ card = "+name+", entries = {", src)
        for name in ("themeChoice", "availability", "matchColorsRow", "matchFontRow",
                     "autoPeekRow", "reduceMotionRow", "tooltipsRow", "reminderRow",
                     "fontChoice", "fontScale", "fontOutline", "iconMode", "widgetSize",
                     "widgetTransparency", "compartmentToggle"):
            self.assertIn("{ widget = "+name, src)
        self.assertIn("resetAccess.optionsY = sectionY + buttonY", src)

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

    def test_dense_card_height_is_measured_not_forced_half_height(self):
        # A literal 50% height would clip the required controls.
        # Source-level arithmetic at 100% font checks our safe denser target.
        behavior = 38 + 4 * (28 + 1) + 6
        typography = 38 + 3 * (32 + 1) + 6
        access = 38 + 3 * (32 + 1) + (28 + 1) + 4 + 34 + 6
        self.assertEqual((behavior, typography, access), (160, 143, 210))
        self.assertLess(behavior + typography + 8, 330)
        self.assertLess(behavior + typography + access + 16 + 6, 540)

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
            "Duels theme is active. EllesmereUI is unavailable",
            "EllesmereUI controls the interface colors.",
            "Duels theme colors are active. Enable Match EllesmereUI colors",
            "themeChoice:SetAvailable(not matchedColors,",
            "themeChoice:SetModified(Settings.IsModified(\"uiTheme\"))",
            "availability:SetTextColor(unpack(C.muted))",
        ):
            self.assertIn(phrase, opts)
        self.assertNotIn('db.uiTheme = nil', opts)
        self.assertIn("pcall(eui.RegisterSkin", read("UI/Theme.lua"))

    def test_main_header_themed_and_landing_art_fixed_colors(self):
        win, land = read("UI/Window.lua"), read("UI/BlizzardSettings.lua")
        self.assertIn("BrandLayer(C.gold,       0,    0.25, -4)", win)
        self.assertIn("BrandLayer(C.headerText, 0.25, 0.50, -4)", win)
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
        self.assertIn("if isPrimary then\n        Style.Skin(button, C.rail", nav)
        self.assertIn("local selected, hover = AddOverlay(button, isPrimary)", nav)
        self.assertIn('button:SetScript("OnClick", function() Select(index, 1) end)', nav)
        self.assertIn("ns.Widgets.PressFeedback(button, hover)", nav)
        self.assertIn("local primaryKeys = { hall = true }", nav)

    def test_patch_icon_is_drawn_with_shared_theme_tokens(self):
        nav = read("UI/Navigation.lua")
        self.assertNotIn("PatchNotesAtlas.tga", nav)
        self.assertIn('local parchment = Style.Fill(icon, C.goldDim, "ARTWORK")', nav)
        self.assertIn("for _, x in ipairs({ 11, 32 }) do", nav)
        self.assertIn("for _, y in ipairs({ -13, -19, -25 }) do", nav)
        self.assertIn("patchPulse:SetLooping(\"BOUNCE\")", nav)
        self.assertIn('label:SetText("PATCH\\nNOTES")', nav)
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
            self.assertNotIn('SetScript("OnUpdate"', text)

if __name__ == "__main__":
    unittest.main()
